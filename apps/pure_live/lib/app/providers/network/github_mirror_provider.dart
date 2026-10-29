import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveRequest;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;

/// The official host a mirror rewrites.
const String kGithubRawOrigin = 'https://raw.githubusercontent.com';

/// The list this project's weekly workflow publishes.
const String githubMirrorFeedUrl =
    'https://raw.githubusercontent.com/liuchuancong/pure_live/master/config/github_mirrors/github_mirrors.json';

/// How a mirror turns an original address into its own.
enum GithubMirrorStrategy {
  /// The endpoint is a prefix proxy: the original address is appended whole.
  prefix,

  /// The endpoint replaces [kGithubRawOrigin] in the address.
  replaceRawPrefix,

  /// The endpoint is jsDelivr's GitHub root; the address becomes
  /// `…/gh/owner/repo@branch/path`.
  jsdelivrGh,
}

/// Where a mirror came from.
enum GithubMirrorSource {
  /// Shipped with the app (the gh-proxy presets).
  builtin,

  /// Fetched from [githubMirrorFeedUrl].
  remote,

  /// Typed by the viewer.
  custom,
}

/// One acceleration endpoint.
@immutable
final class GithubMirror {
  /// Creates a mirror.
  const GithubMirror({required this.url, required this.strategy, required this.source});

  /// The endpoint.
  final String url;

  /// How the endpoint rewrites an address.
  final GithubMirrorStrategy strategy;

  /// Where the entry came from.
  final GithubMirrorSource source;

  /// The endpoint with exactly one trailing slash, for prefixing.
  String get prefixed => url.endsWith('/') ? url : '$url/';

  /// The endpoint without trailing slashes, for path joins.
  String get unbracketed => url.replaceFirst(RegExp(r'/+$'), '');

  Map<String, Object?> toJson() => {'url': url, 'strategy': strategy.name};
}

/// The presets the app carries, matching the reference's default list.
const List<GithubMirror> kBuiltinGithubMirrors = [
  GithubMirror(url: 'https://gh-proxy.org/', strategy: GithubMirrorStrategy.prefix, source: GithubMirrorSource.builtin),
  GithubMirror(
    url: 'https://v4.gh-proxy.org/',
    strategy: GithubMirrorStrategy.prefix,
    source: GithubMirrorSource.builtin,
  ),
  GithubMirror(
    url: 'https://cdn.gh-proxy.org/',
    strategy: GithubMirrorStrategy.prefix,
    source: GithubMirrorSource.builtin,
  ),
];

/// What the acceleration setting is set to.
enum GithubMirrorMode {
  /// Direct: the original address, nothing in front.
  direct,

  /// One of the listed mirrors.
  mirror,

  /// The viewer's own endpoint ([GithubMirrorState.customUrl]).
  custom,
}

/// The saved choices and the remote list.
@immutable
final class GithubMirrorState {
  /// Creates a reading.
  const GithubMirrorState({
    this.mode = GithubMirrorMode.direct,
    this.mirrorUrl = '',
    this.customUrl = '',
    this.remote = const [],
    this.added = const [],
    this.hidden = const {},
    this.loading = false,
    this.error,
    this.updatedAt,
  });

  /// The mode in force.
  final GithubMirrorMode mode;

  /// The chosen listed mirror, when [mode] is [GithubMirrorMode.mirror].
  final String mirrorUrl;

  /// The viewer's endpoint, when [mode] is [GithubMirrorMode.custom].
  final String customUrl;

  /// The list fetched from [githubMirrorFeedUrl].
  final List<GithubMirror> remote;

  /// Endpoints the viewer added.
  final List<GithubMirror> added;

  /// Endpoints the viewer removed, whatever their source.
  final Set<String> hidden;

  /// Whether a remote refresh is running.
  final bool loading;

  /// The last refresh's failure, in the transport's words.
  final String? error;

  /// When the remote list last landed.
  final DateTime? updatedAt;

  /// Every endpoint the manager lists, built-ins first.
  List<GithubMirror> get mirrors {
    final seen = <String>{};
    return [
      for (final mirror in [...kBuiltinGithubMirrors, ...remote, ...added])
        if (!hidden.contains(mirror.url) && seen.add(mirror.url)) mirror,
    ];
  }

  /// The endpoint in force, or null for direct and for a mirror that has
  /// been removed since it was chosen.
  GithubMirror? get chosen {
    final url = switch (mode) {
      GithubMirrorMode.direct => '',
      GithubMirrorMode.mirror => mirrorUrl,
      GithubMirrorMode.custom => customUrl.trim(),
    };
    if (url.isEmpty || !url.startsWith('https://')) return null;
    for (final mirror in mirrors) {
      if (mirror.url == url) return mirror;
    }
    return mode == GithubMirrorMode.custom
        ? GithubMirror(url: url, strategy: GithubMirrorStrategy.prefix, source: GithubMirrorSource.custom)
        : null;
  }

  /// The address with the chosen mirror applied, or null for direct.
  String? accelerated(String original) {
    final mirror = chosen;
    if (mirror == null) return null;
    return accelerateGithubUrl(mirror, original);
  }

  /// The addresses a download tries, in order: the accelerated one first,
  /// then the original as the fallback the hint promises.
  List<String> candidates(String original) {
    final accelerated = this.accelerated(original);
    return [if (accelerated != null && accelerated != original) accelerated, original];
  }

  GithubMirrorState copyWith({
    GithubMirrorMode? mode,
    String? mirrorUrl,
    String? customUrl,
    List<GithubMirror>? remote,
    List<GithubMirror>? added,
    Set<String>? hidden,
    bool? loading,
    String? error,
    bool clearError = false,
    DateTime? updatedAt,
  }) => GithubMirrorState(
    mode: mode ?? this.mode,
    mirrorUrl: mirrorUrl ?? this.mirrorUrl,
    customUrl: customUrl ?? this.customUrl,
    remote: remote ?? this.remote,
    added: added ?? this.added,
    hidden: hidden ?? this.hidden,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Applies [mirror] to [original]; null when the strategies do not fit.
String? accelerateGithubUrl(GithubMirror mirror, String original) => switch (mirror.strategy) {
  GithubMirrorStrategy.prefix => '${mirror.prefixed}$original',
  GithubMirrorStrategy.replaceRawPrefix =>
    original.startsWith('$kGithubRawOrigin/') ? mirror.unbracketed + original.substring(kGithubRawOrigin.length) : null,
  GithubMirrorStrategy.jsdelivrGh => _jsdelivrPath(mirror.unbracketed, original),
};

/// `https://raw.githubusercontent.com/o/r/b/p…` becomes
/// `https://fastly.jsdelivr.net/gh/o/r@b/p…`.
String? _jsdelivrPath(String base, String original) {
  if (!original.startsWith('$kGithubRawOrigin/')) return null;
  final parts = original.substring(kGithubRawOrigin.length + 1).split('/');
  if (parts.length < 4) return null;
  final repository = '${parts[0]}/${parts[1]}@${parts[2]}';
  return '$base/$repository/${parts.skip(3).join('/')}';
}

/// The acceleration setting, its remote list and the viewer's own entries.
final class GithubMirrorController extends Notifier<GithubMirrorState> {
  static const String _modeKey = 'proxy.githubMirror.mode';
  static const String _urlKey = 'proxy.githubMirror.url';
  static const String _customKey = 'proxy.githubMirror.custom';
  static const String _remoteKey = 'proxy.githubMirror.remote';
  static const String _addedKey = 'proxy.githubMirror.added';
  static const String _hiddenKey = 'proxy.githubMirror.hidden';
  static const String _updatedKey = 'proxy.githubMirror.updatedAt';

  @override
  GithubMirrorState build() => GithubMirrorState(
    mode: _readMode(),
    mirrorUrl: _readString(_urlKey),
    customUrl: _readString(_customKey),
    remote: _readMirrors(_remoteKey, GithubMirrorSource.remote),
    added: _readMirrors(_addedKey, GithubMirrorSource.custom),
    hidden: _readStrings(_hiddenKey).toSet(),
    updatedAt: _readUpdated(),
  );

  /// Uses no acceleration.
  void useDirect() => _persist(state.copyWith(mode: GithubMirrorMode.direct));

  /// Uses the listed [url].
  void useMirror(String url) => _persist(state.copyWith(mode: GithubMirrorMode.mirror, mirrorUrl: url));

  /// Uses the viewer's own endpoint.
  void useCustom() => _persist(state.copyWith(mode: GithubMirrorMode.custom));

  /// Stores the viewer's endpoint; an empty value drops back to direct the
  /// next time the mode is read from the field.
  void setCustomUrl(String url) => _persist(state.copyWith(customUrl: url.trim()));

  /// Adds [url] if it is a usable HTTPS endpoint and uses it.
  bool addMirror(String url) {
    final value = url.trim();
    final parsed = Uri.tryParse(value);
    if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) return false;
    final existed = state.mirrors.where((mirror) => mirror.url == value).firstOrNull;
    if (existed != null) {
      final hidden = {...state.hidden}..remove(value);
      _persist(state.copyWith(hidden: hidden, mode: GithubMirrorMode.mirror, mirrorUrl: value));
      return true;
    }
    final added = [
      ...state.added,
      GithubMirror(url: value, strategy: GithubMirrorStrategy.prefix, source: GithubMirrorSource.custom),
    ];
    _persist(state.copyWith(added: added, mode: GithubMirrorMode.mirror, mirrorUrl: value));
    return true;
  }

  /// Hides [url] from the list; a hidden mirror in use hands back to direct.
  void removeMirror(String url) {
    final hidden = {...state.hidden, url};
    final added = [
      for (final mirror in state.added)
        if (mirror.url != url) mirror,
    ];
    final inUse = state.mode == GithubMirrorMode.mirror && state.mirrorUrl == url;
    _persist(state.copyWith(hidden: hidden, added: added, mode: inUse ? GithubMirrorMode.direct : state.mode));
  }

  /// Brings the built-in presets back after they were hidden.
  void restoreBuiltins() {
    final hidden = {
      for (final url in state.hidden)
        if (!kBuiltinGithubMirrors.any((mirror) => mirror.url == url)) url,
    };
    _persist(state.copyWith(hidden: hidden));
  }

  /// Fetches the published mirror list.
  ///
  /// The feed lives on the same host the mirrors exist to reach, so the
  /// chosen route is tried first and the original address second — a viewer
  /// who needs acceleration can still read the list.
  Future<void> refresh() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    Object? failure;
    for (final candidate in state.candidates(githubMirrorFeedUrl)) {
      try {
        final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.api);
        final response = await http.send(LiveRequest.get(Uri.parse(candidate), timeout: const Duration(seconds: 30)));
        if (!response.isOk) throw StateError('HTTP ${response.statusCode}');
        final remote = _parseFeed(jsonDecode(response.text));
        if (remote.isEmpty) throw StateError('No usable mirrors in the feed');
        if (!ref.mounted) return;
        _persist(state.copyWith(remote: remote, loading: false, updatedAt: DateTime.now()));
        return;
      } on Object catch (error) {
        failure = error;
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(loading: false, error: '$failure');
  }

  /// The feed's raw mirror presets this app can apply.
  static List<GithubMirror> _parseFeed(Object? json) {
    if (json is! Map) return const [];
    final sources = json['sources'];
    if (sources is! Map) return const [];
    final raw = sources['raw'];
    if (raw is! Map) return const [];
    final presets = raw['presets'];
    if (presets is! List) return const [];
    final found = <String, GithubMirror>{};
    for (final preset in presets) {
      if (preset is! Map) continue;
      final url = preset['url']?.toString().trim() ?? '';
      if (!url.startsWith('https://')) continue;
      final strategy = switch (preset['strategy']?.toString()) {
        'replaceUrlPrefix' => GithubMirrorStrategy.replaceRawPrefix,
        'jsdelivrGh' => GithubMirrorStrategy.jsdelivrGh,
        _ => null,
      };
      if (strategy == null) continue;
      found[url] = GithubMirror(url: url, strategy: strategy, source: GithubMirrorSource.remote);
    }
    return found.values.toList(growable: false);
  }

  void _persist(GithubMirrorState next) {
    state = next;
    unawaited(_write(next));
  }

  Future<void> _write(GithubMirrorState value) async {
    try {
      await StoragePrefs.setPrefs({
        _modeKey: value.mode.name,
        _urlKey: value.mirrorUrl,
        _customKey: value.customUrl,
        _remoteKey: jsonEncode([for (final mirror in value.remote) mirror.toJson()]),
        _addedKey: jsonEncode([for (final mirror in value.added) mirror.toJson()]),
        _hiddenKey: jsonEncode(value.hidden.toList()),
        _updatedKey: '${value.updatedAt?.millisecondsSinceEpoch ?? 0}',
      });
    } on Object {
      // The choices are preferences; a closed store loses this write.
    }
  }

  static String _readString(String key) {
    try {
      return StoragePrefs.getString(key) ?? '';
    } on Object {
      return '';
    }
  }

  static List<String> _readStrings(String key) {
    try {
      final decoded = jsonDecode(StoragePrefs.getString(key) ?? '[]');
      return [
        if (decoded is List)
          for (final value in decoded)
            if (value is String && value.isNotEmpty) value,
      ];
    } on Object {
      return const [];
    }
  }

  static GithubMirrorMode _readMode() {
    try {
      return switch (StoragePrefs.getString(_modeKey)) {
        'mirror' => GithubMirrorMode.mirror,
        'custom' => GithubMirrorMode.custom,
        _ => GithubMirrorMode.direct,
      };
    } on Object {
      return GithubMirrorMode.direct;
    }
  }

  static List<GithubMirror> _readMirrors(String key, GithubMirrorSource source) {
    try {
      final decoded = jsonDecode(StoragePrefs.getString(key) ?? '[]');
      if (decoded is! List) return const [];
      return [
        for (final value in decoded)
          if (value is Map && value['url'] is String)
            GithubMirror(
              url: value['url'] as String,
              strategy: switch (value['strategy']) {
                'replaceRawPrefix' => GithubMirrorStrategy.replaceRawPrefix,
                'jsdelivrGh' => GithubMirrorStrategy.jsdelivrGh,
                _ => GithubMirrorStrategy.prefix,
              },
              source: source,
            ),
      ];
    } on Object {
      return const [];
    }
  }

  static DateTime? _readUpdated() {
    try {
      final millis = int.tryParse(StoragePrefs.getString(_updatedKey) ?? '') ?? 0;
      return millis <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    } on Object {
      return null;
    }
  }
}

/// The GitHub acceleration setting.
final githubMirrorProvider = NotifierProvider<GithubMirrorController, GithubMirrorState>(GithubMirrorController.new);
