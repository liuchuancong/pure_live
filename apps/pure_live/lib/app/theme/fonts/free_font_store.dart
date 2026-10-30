import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File;
import 'dart:typed_data' show ByteData;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest, LiveStreamedResponse;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/app/providers/network/github_mirror_provider.dart' show githubMirrorProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/app/theme/fonts/font_defaults.dart' show isFreeFontId;
import 'package:pure_live/app/theme/fonts/font_entry.dart';

/// A downloaded free-font file kept on this device.
@immutable
final class CachedFreeFont {
  /// Creates a cache record.
  const CachedFreeFont({required this.name, required this.file, required this.bytes});

  /// The catalogue name, so the manager can label a stored family without
  /// loading the whole catalogue.
  final String name;

  /// The file's name inside the font folder.
  final String file;

  /// The file size.
  final int bytes;

  Map<String, Object?> toJson() => {'name': name, 'file': file, 'bytes': bytes};

  static CachedFreeFont? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final file = value['file'];
    if (name is! String || file is! String) return null;
    final bytes = value['bytes'];
    return CachedFreeFont(name: name, file: file, bytes: bytes is num ? bytes.toInt() : 0);
  }
}

/// How far one download got.
@immutable
final class FreeFontTransfer {
  /// Creates a progress reading.
  const FreeFontTransfer({required this.received, required this.total});

  /// Bytes written so far.
  final int received;

  /// The expected size; 0 while the host has not said.
  final int total;

  /// How much is done, 0–1; null while the size is unknown.
  double? get fraction => total > 0 ? (received / total).clamp(0, 1) : null;
}

/// The store's reading: what is on disk, what is moving, and what failed.
@immutable
final class FreeFontStoreState {
  /// Creates a reading.
  const FreeFontStoreState({this.cached = const {}, this.transfers = const {}, this.failed = const {}});

  /// Downloaded faces by family id.
  final Map<String, CachedFreeFont> cached;

  /// Running downloads by family id.
  final Map<String, FreeFontTransfer> transfers;

  /// Families whose last download failed.
  final Set<String> failed;

  /// Whether [id] has a file on this device.
  bool isCached(String id) => cached.containsKey(id);

  /// Whether [id] is downloading.
  bool isDownloading(String id) => transfers.containsKey(id);

  /// The shown name of [id], when a file is stored for it.
  String? nameOf(String? id) => id == null ? null : cached[id]?.name;

  FreeFontStoreState copyWith({
    Map<String, CachedFreeFont>? cached,
    Map<String, FreeFontTransfer>? transfers,
    Set<String>? failed,
  }) => FreeFontStoreState(
    cached: cached ?? this.cached,
    transfers: transfers ?? this.transfers,
    failed: failed ?? this.failed,
  );
}

/// Downloads free-font files into the app's own folder, registers them with
/// the engine and remembers what is stored.
///
/// The files never go to the shared download folder: they are the app's
/// assets on this device, not the viewer's downloads.
final class FreeFontStore extends Notifier<FreeFontStoreState> {
  static const String _indexFile = 'index.json';

  final Set<String> _registered = {};
  final Map<String, LiveStreamedResponse> _responses = {};
  final Map<String, DateTime> _lastPaint = {};
  String _directory = '';

  @override
  FreeFontStoreState build() {
    final paths = ref.watch(appPathsProvider);
    _directory = paths.fonts.path;
    ref.onDispose(() {
      for (final response in _responses.values) {
        unawaited(response.close());
      }
    });
    return FreeFontStoreState(cached: _readIndex());
  }

  /// Registers a downloaded family with the engine; false when no file is
  /// stored for it or it cannot be read.
  Future<bool> register(String id) async {
    if (!isFreeFontId(id)) return false;
    if (_registered.contains(id)) return true;
    final cached = state.cached[id];
    if (cached == null) return false;
    try {
      await _registerFile(id, p.join(_directory, cached.file));
      return true;
    } on Object {
      return false;
    }
  }

  /// Fetches [entry], registers it and records it; false when both hosts
  /// fail.
  Future<bool> download(FontEntry entry) async {
    if (state.isDownloading(entry.id)) return false;
    final url = entry.url;
    if (url == null) return false;
    _fail(entry.id, false);
    _transfer(entry.id, FreeFontTransfer(received: 0, total: entry.bytes));
    // The chosen GitHub accelerator goes first, the original address is the
    // fallback that keeps a broken mirror from blocking a download, and the
    // jsDelivr copy is the last resort.
    final candidates = <String>{
      ...ref.read(githubMirrorProvider).candidates(url),
      if (entry.fallbackUrl != null) entry.fallbackUrl!,
    };
    var ok = false;
    for (final candidate in candidates) {
      ok = await _fetch(entry, candidate);
      if (ok) break;
    }
    _dropTransfer(entry.id);
    if (!ok) _fail(entry.id, true);
    return ok;
  }

  /// Deletes the stored file; a family the theme still names is the caller's
  /// business to switch away from first.
  Future<void> remove(String id) async {
    final cached = state.cached[id];
    if (cached == null) return;
    try {
      final file = File(p.join(_directory, cached.file));
      if (file.existsSync()) await file.delete();
    } on Object {
      // The index is the truth; a file already gone is the goal.
    }
    _registered.remove(id);
    final next = {...state.cached}..remove(id);
    state = state.copyWith(cached: next);
    await _writeIndex(next);
  }

  Future<bool> _fetch(FontEntry entry, String url) async {
    LiveStreamedResponse? response;
    final target = File(p.join(_directory, '${_fileStem(entry.id)}.ttf'));
    final part = File('${target.path}.part');
    var received = 0;
    var total = entry.bytes;
    try {
      await Directory(_directory).create(recursive: true);
      final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
      response = await http.open(LiveRequest.get(Uri.parse(url), timeout: const Duration(minutes: 10)));
      _responses[entry.id] = response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.close();
        return false;
      }
      final announced = int.tryParse(response.headers['content-length'] ?? '') ?? 0;
      if (announced > 0) total = announced;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          _paint(entry.id, received, total);
        }
      } finally {
        await sink.close();
      }
      if (target.existsSync()) await target.delete();
      await part.rename(target.path);
      try {
        await _registerFile(entry.id, target.path);
      } on Object {
        // A file the engine cannot read (a malformed collection, say) is no
        // use kept on disk: the row goes back to "not downloaded".
        try {
          if (target.existsSync()) await target.delete();
        } on Object {
          // Nothing more to clean.
        }
        return false;
      }
      final size = target.lengthSync();
      final next = {
        ...state.cached,
        entry.id: CachedFreeFont(name: entry.name, file: p.basename(target.path), bytes: size),
      };
      state = state.copyWith(cached: next);
      await _writeIndex(next);
      return true;
    } on Object {
      try {
        if (part.existsSync()) await part.delete();
      } on Object {
        // A leftover `.part` is invisible to the manager and harmless.
      }
      return false;
    } finally {
      _responses.remove(entry.id);
    }
  }

  Future<void> _registerFile(String id, String path) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(id)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _registered.add(id);
  }

  Map<String, CachedFreeFont> _readIndex() {
    try {
      final file = File(p.join(_directory, _indexFile));
      if (!file.existsSync()) return const {};
      final map = jsonDecode(file.readAsStringSync());
      if (map is! Map) return const {};
      final out = <String, CachedFreeFont>{};
      map.forEach((id, value) {
        final cached = CachedFreeFont.fromJson(value);
        if (cached == null || id is! String) return;
        if (File(p.join(_directory, cached.file)).existsSync()) out[id] = cached;
      });
      return out;
    } on Object {
      return const {};
    }
  }

  Future<void> _writeIndex(Map<String, CachedFreeFont> cached) async {
    try {
      await Directory(_directory).create(recursive: true);
      await File(p.join(_directory, _indexFile))
          .writeAsString(jsonEncode({for (final entry in cached.entries) entry.key: entry.value.toJson()}));
    } on Object {
      // The cache is a convenience; the next download rewrites it.
    }
  }

  /// The file name: the id's hash is already filesystem-safe.
  static String _fileStem(String id) => id.replaceFirst('freefont:', 'font-');

  void _transfer(String id, FreeFontTransfer transfer) {
    if (!ref.mounted) return;
    state = state.copyWith(transfers: {...state.transfers, id: transfer});
  }

  void _dropTransfer(String id) {
    if (!ref.mounted) return;
    state = state.copyWith(transfers: {...state.transfers}..remove(id));
  }

  void _paint(String id, int received, int total) {
    final now = DateTime.now();
    final last = _lastPaint[id];
    if (last != null && now.difference(last) < const Duration(milliseconds: 150)) return;
    _lastPaint[id] = now;
    _transfer(id, FreeFontTransfer(received: received, total: total));
  }

  void _fail(String id, bool failed) {
    if (!ref.mounted) return;
    state = state.copyWith(failed: failed ? {...state.failed, id} : ({...state.failed}..remove(id)));
  }
}

/// The downloaded free fonts on this device.
final freeFontStoreProvider = NotifierProvider<FreeFontStore, FreeFontStoreState>(FreeFontStore.new);
