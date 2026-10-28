import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Where an imported script came from, kept so the list can say it and so a
/// re-import can be traced back to the page it was copied from.
@immutable
final class MusicCustomSource {
  /// Creates one imported source.
  const MusicCustomSource({
    required this.id,
    required this.name,
    required this.script,
    required this.importedAt,
    this.description = '',
    this.author = '',
    this.version = '',
    this.homepage = '',
    this.enabled = true,
  });

  /// Reads a stored entry; null when the entry is damaged.
  static MusicCustomSource? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final script = json['script'];
    final importedAt = (json['importedAt'] as num?)?.toInt();
    if (id is! String || name is! String || script is! String || importedAt == null) return null;
    return MusicCustomSource(
      id: id,
      name: name,
      script: script,
      description: json['description'] is String ? json['description'] as String : '',
      author: json['author'] is String ? json['author'] as String : '',
      version: json['version'] is String ? json['version'] as String : '',
      homepage: json['homepage'] is String ? json['homepage'] as String : '',
      enabled: json['enabled'] != false,
      importedAt: DateTime.fromMillisecondsSinceEpoch(importedAt),
    );
  }

  /// The source's own id, minted at import.
  final String id;

  /// The script's `@name`.
  final String name;

  /// The script itself, kept verbatim.
  final String script;

  /// The script's `@description`.
  final String description;

  /// The script's `@author`.
  final String author;

  /// The script's `@version`.
  final String version;

  /// The script's `@homepage`.
  final String homepage;

  /// Whether the module may ask this source for a song; disabling keeps the
  /// script without offering it.
  final bool enabled;

  /// When it was imported.
  final DateTime importedAt;

  /// A copy with the identity or the enabled flag replaced.
  MusicCustomSource copyWith({String? id, bool? enabled, DateTime? importedAt}) => MusicCustomSource(
    id: id ?? this.id,
    name: name,
    script: script,
    description: description,
    author: author,
    version: version,
    homepage: homepage,
    enabled: enabled ?? this.enabled,
    importedAt: importedAt ?? this.importedAt,
  );

  /// The stored shape.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'script': script,
    'description': description,
    'author': author,
    'version': version,
    'homepage': homepage,
    'enabled': enabled,
    'importedAt': importedAt.millisecondsSinceEpoch,
  };

  /// Reads the header comment a lx-music script opens with — the block
  /// comment's `@key value` lines. Missing fields stay empty; a script
  /// without an `@name` or without the `lx.on('request', …)` contract is not
  /// a source.
  static MusicCustomSource? parse(String script, {required String id, DateTime? importedAt}) {
    final meta = _header(script);
    final name = meta['name']?.trim() ?? '';
    if (name.isEmpty || !script.contains('lx.on(')) return null;
    return MusicCustomSource(
      id: id,
      name: name,
      script: script,
      description: meta['description']?.trim() ?? '',
      author: meta['author']?.trim() ?? '',
      version: meta['version']?.trim() ?? '',
      homepage: meta['homepage']?.trim() ?? '',
      importedAt: importedAt ?? DateTime.now(),
    );
  }

  static final RegExp _comment = RegExp(r'^\s*/\*\*?([\s\S]*?)\*/');
  static final RegExp _field = RegExp(r'^\s*\*?\s*@(\w+)\s+(.+?)\s*$', multiLine: true);

  static Map<String, String> _header(String script) {
    final comment = _comment.firstMatch(script);
    if (comment == null) return const {};
    final fields = <String, String>{};
    for (final match in _field.allMatches(comment.group(1)!)) {
      fields[match.group(1)!.toLowerCase()] = match.group(2)!;
    }
    return fields;
  }
}

/// Why a script was rejected.
enum MusicSourceFailureReason {
  /// Nothing was pasted, or the address answered an empty body.
  empty,

  /// No header comment with a name, or no `lx.on('request', …)`.
  notASource,
}

/// A rejected import, carrying the reason the panes word.
final class MusicSourceFailure implements Exception {
  /// The reason.
  const MusicSourceFailure(this.reason);

  /// Why the script was rejected.
  final MusicSourceFailureReason reason;

  @override
  String toString() => 'MusicSourceFailure.${reason.name}';
}

/// What an import did.
enum MusicSourceImportOutcome {
  /// A new source joined the list.
  added,

  /// A source with the same name was replaced by this script.
  updated,
}

/// An import's result: the stored source and whether it was new.
typedef MusicSourceImport = ({MusicCustomSource source, MusicSourceImportOutcome outcome});

/// The imported scripts, kept as one JSON preference.
///
/// Importing validates a script the way lx-music does — a header comment with
/// a name plus the request contract — and keeps it verbatim. A script whose
/// name already exists is replaced in place, so re-importing an updated
/// version does not leave two.
final class MusicSourcesController extends Notifier<List<MusicCustomSource>> {
  @override
  List<MusicCustomSource> build() {
    final raw = _read();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final entry in json) ?MusicCustomSource.fromJson(entry)];
    } on Object {
      return const [];
    }
  }

  /// Adds [script], or replaces the source it names.
  Future<MusicSourceImport> importScript(String script) async {
    if (script.trim().isEmpty) throw const MusicSourceFailure(MusicSourceFailureReason.empty);
    final parsed = MusicCustomSource.parse(script, id: '');
    if (parsed == null) throw const MusicSourceFailure(MusicSourceFailureReason.notASource);
    MusicCustomSource? existing;
    for (final source in state) {
      if (source.name == parsed.name) {
        existing = source;
        break;
      }
    }
    final source = parsed.copyWith(
      id: existing?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
      importedAt: existing?.importedAt,
      enabled: existing?.enabled ?? parsed.enabled,
    );
    state = existing == null
        ? [...state, source]
        : [
            for (final item in state)
              if (item.id == source.id) source else item,
          ];
    await _save();
    return (
      source: source,
      outcome: existing == null ? MusicSourceImportOutcome.added : MusicSourceImportOutcome.updated,
    );
  }

  /// Offers or withholds the source named by `id` from the module.
  Future<void> setEnabled(String id, {required bool enabled}) async {
    state = [
      for (final source in state)
        if (source.id == id) source.copyWith(enabled: enabled) else source,
    ];
    await _save();
  }

  /// Removes the source and its script.
  Future<void> remove(String id) async {
    state = [
      for (final source in state)
        if (source.id != id) source,
    ];
    await _save();
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(_sourcesKey, jsonEncode([for (final source in state) source.toJson()]));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static String? _read() {
    try {
      return StoragePrefs.getString(_sourcesKey);
    } on Object {
      return null;
    }
  }
}

/// The preference the imported scripts are kept under.
const String _sourcesKey = 'music.customSources';

/// The imported custom sources.
final musicSourcesProvider = NotifierProvider<MusicSourcesController, List<MusicCustomSource>>(
  MusicSourcesController.new,
);
