import 'dart:async' show Completer, Future, TimeoutException, unawaited;
import 'dart:convert' show jsonEncode, utf8;

import 'package:fjs/fjs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/lx_script_prelude.dart' show lxScriptPrelude;
import 'package:pure_live/modules/music/controller/music_sources.dart' show MusicCustomSource, musicSourcesProvider;

/// A source a script declared in its `inited` event.
final class LxScriptSource {
  /// Creates a source capability.
  const LxScriptSource({required this.id, required this.actions, required this.qualitys});

  /// The platform key (`kw`, `kg`, `tx`, `wy`, `mg`, `local`).
  final String id;

  /// Actions the script handles; only `musicUrl` is used here.
  final List<String> actions;

  /// Quality names the script advertises.
  final List<String> qualitys;

  /// Whether this source can resolve a playable URL.
  bool get canResolve => actions.contains('musicUrl');
}

/// One loaded lx-music script and its declared sources.
final class LxScriptInstance {
  LxScriptInstance({required this.source, required this.engine});

  /// The imported script.
  final MusicCustomSource source;

  /// Its engine; one engine per script, so a broken script cannot take the
  /// others down with it.
  final JsEngine engine;

  /// The sources declared by `lx.send('inited', …)`.
  Map<String, LxScriptSource> sources = const {};

  /// Why the script failed, when it did.
  String? error;

  /// Whether the script finished its handshake.
  bool inited = false;

  final Completer<void> ready = Completer<void>();

  /// Whether [id] is declared and can resolve URLs.
  bool supports(String id) => sources[id]?.canResolve ?? false;

  /// The tiers the script advertises for [id].
  List<String> qualitysFor(String id) => sources[id]?.qualitys ?? const [];

  /// Releases the engine.
  Future<void> dispose() async {
    try {
      await engine.close();
    } on Object {
      // A closed engine is already gone.
    }
  }
}

/// Runs imported lx-music scripts in fjs (QuickJS).
///
/// The desktop and mobile clients expose exactly this contract to a source
/// script: `lx.on('request', handler)`, `lx.send('inited', …)`,
/// `lx.request(url, options, callback)` and `lx.utils`. The bridge below
/// implements that contract on the app side — HTTP across the bridge and the
/// buffer/crypto/zlib helpers in the prelude — and calls the script's
/// `request` handler for a song URL.
final class LxScriptRuntime {
  LxScriptRuntime();

  final http.Client _client = http.Client();
  final Set<String> _cancelled = <String>{};
  List<LxScriptInstance> _instances = const [];
  List<MusicCustomSource> _sources = const [];
  List<String> _errors = const [];
  Future<void>? _loading;
  int _generation = 0;
  bool _loaded = false;

  /// Problems the last load reported, one per script that failed.
  List<String> get errors => _errors;

  /// Loaded scripts, in import order.
  List<LxScriptInstance> get instances => _instances;

  /// Whether at least one script can resolve a URL for [sourceId].
  bool supports(String sourceId) => _instances.any((instance) => instance.supports(sourceId));

  /// The tiers declared for [sourceId], in the order the scripts declared.
  List<String> qualitysFor(String sourceId) {
    final seen = <String>{};
    return [
      for (final instance in _instances)
        for (final quality in instance.qualitysFor(sourceId))
          if (seen.add(quality)) quality,
    ];
  }

  /// Loads [sources], replacing every engine from the previous run.
  Future<void> load(List<MusicCustomSource> sources) {
    _sources = List<MusicCustomSource>.unmodifiable(sources);
    final generation = ++_generation;
    final future = _load(sources, generation);
    _loading = future;
    return future;
  }

  /// Makes sure the current imported scripts are loaded.
  Future<void> ensureLoaded() async {
    final pending = _loading;
    if (pending != null) await pending;
    if (!_loaded) await load(_sources);
  }

  /// Asks the newest script that supports [track]'s platform for a URL.
  ///
  /// Returns null when no script answers; the source then uses its own
  /// fallback URL. A script that throws is skipped so one broken source does
  /// not lose the song.
  Future<String?> resolveMusicUrl(audio.MusicTrack track, String quality) async {
    await ensureLoaded();
    for (final instance in _instances.reversed) {
      if (!instance.supports(track.sourceId)) continue;
      try {
        final payload = jsonEncode({
          'source': track.sourceId,
          'action': 'musicUrl',
          'info': {'type': quality, 'musicInfo': lxMusicInfo(track, qualitys: instance.qualitysFor(track.sourceId))},
        });
        final result = await instance.engine.eval(
          source: JsCode.code('await globalThis.__lxInvoke($payload)'),
          options: JsEvalOptions.withPromise(),
        );
        final value = result.value;
        if (value is String && _isUrl(value)) return value;
      } on Object {
        // Try the next script.
      }
    }
    return null;
  }

  Future<void> _load(List<MusicCustomSource> sources, int generation) async {
    final active = [
      for (final source in sources)
        if (source.enabled) source,
    ];
    if (active.isEmpty) {
      final old = _instances;
      _instances = const [];
      for (final instance in old) {
        unawaited(instance.dispose());
      }
      if (generation == _generation) {
        _errors = const [];
        _loaded = true;
      }
      return;
    }
    try {
      await _ensureLib();
    } on Object catch (failure) {
      _errors = ['fjs: $failure'];
      _loaded = true;
      return;
    }
    final old = _instances;
    _instances = const [];
    for (final instance in old) {
      unawaited(instance.dispose());
    }
    final loaded = <LxScriptInstance>[];
    final errors = <String>[];
    for (final source in active) {
      if (generation != _generation) {
        for (final instance in loaded) {
          unawaited(instance.dispose());
        }
        return;
      }
      try {
        final instance = await _create(source);
        loaded.add(instance);
        if (instance.error != null) errors.add('${source.name}: ${instance.error}');
      } on Object catch (failure) {
        errors.add('${source.name}: $failure');
      }
    }
    if (generation != _generation) {
      for (final instance in loaded) {
        unawaited(instance.dispose());
      }
      return;
    }
    _instances = loaded;
    _errors = errors;
    _loaded = true;
  }

  static Future<void>? _lib;
  static Future<void> _ensureLib() => _lib ??= LibFjs.init();

  Future<LxScriptInstance> _create(MusicCustomSource source) async {
    final engine = await JsEngine.create(
      builtins: const JsBuiltinOptions(
        console: true,
        timers: true,
        buffer: true,
        crypto: true,
        zlib: true,
        url: true,
        exceptions: true,
      ),
    );
    final instance = LxScriptInstance(source: source, engine: engine);
    try {
      await engine.init(bridge: (value) => _bridge(value, instance));
      await engine.eval(
        source: const JsCode.code(lxScriptPrelude),
        options: JsEvalOptions(global: true, strict: false),
      );
      await engine.eval(
        source: JsCode.code(
          'globalThis.lx.currentScriptInfo = ${jsonEncode({'name': source.name, 'description': source.description, 'version': source.version, 'author': source.author, 'homepage': source.homepage, 'rawScript': source.script})};',
        ),
        options: JsEvalOptions(global: true, strict: false),
      );
      await engine.eval(source: JsCode.code(source.script), options: JsEvalOptions(global: true, strict: false));
      try {
        await instance.ready.future.timeout(const Duration(seconds: 8));
      } on TimeoutException {
        instance.error ??= 'inited event was not sent';
        if (!instance.ready.isCompleted) instance.ready.complete();
      }
    } on Object catch (failure) {
      instance.error ??= '$failure';
      if (!instance.ready.isCompleted) instance.ready.complete();
    }
    return instance;
  }

  Future<JsResult> _bridge(JsValue value, LxScriptInstance instance) async {
    final raw = value.value;
    if (raw is! Map) return const JsResult.ok(JsValue.none());
    final payload = <String, Object?>{};
    for (final entry in raw.entries) {
      payload['${entry.key}'] = entry.value;
    }
    switch (payload['kind']) {
      case 'send':
        _onSend(payload, instance);
        return const JsResult.ok(JsValue.none());
      case 'http':
        final id = payload['id'] as String? ?? '';
        final result = await _request(id, payload);
        _cancelled.remove(id);
        return JsResult.ok(JsValue.from(result));
      case 'cancel':
        final id = payload['id'] as String?;
        if (id != null) _cancelled.add(id);
        return const JsResult.ok(JsValue.none());
      default:
        return const JsResult.ok(JsValue.none());
    }
  }

  void _onSend(Map<String, Object?> payload, LxScriptInstance instance) {
    if (payload['event'] != 'inited') return;
    final data = payload['data'];
    // Since lx-music 2.5 `inited` no longer carries `status`; a script that
    // fails initialization throws before sending it instead.
    if (data is Map && data['status'] != false && data['sources'] is Map) {
      final sources = data['sources'] as Map;
      final declared = <String, LxScriptSource>{};
      for (final entry in sources.entries) {
        final id = '${entry.key}';
        final info = entry.value;
        if (info is! Map) continue;
        declared[id] = LxScriptSource(
          id: id,
          actions: [for (final action in _list(info['actions'])) '$action'],
          qualitys: [for (final quality in _list(info['qualitys'])) '$quality'],
        );
      }
      instance
        ..sources = declared
        ..inited = true
        ..error = null;
    } else {
      final message = data is Map ? data['message'] : null;
      instance.error = message is String && message.isNotEmpty
          ? message
          : data is Map
          ? 'inited event has no sources'
          : 'inited event has no payload';
    }
    if (!instance.ready.isCompleted) instance.ready.complete();
  }

  Future<Map<String, Object?>> _request(String id, Map<String, Object?> payload) async {
    if (_cancelled.remove(id)) return const {'cancelled': true};
    final url = payload['url'];
    final options = payload['options'];
    if (url is! String) return const {'error': 'missing url'};
    final settings = options is Map ? options.cast<String, Object?>() : const <String, Object?>{};
    final method = '${settings['method'] ?? 'get'}'.toUpperCase();
    final headers = <String, String>{};
    final rawHeaders = settings['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers['${entry.key}'] = '${entry.value}';
      }
    }
    try {
      final request = http.Request(method, Uri.parse(url));
      request.headers.addAll(headers);
      final form = settings['form'];
      final formData = settings['formData'];
      final body = settings['body'];
      if (form is Map) {
        request.body = form.entries
            .map((entry) => '${Uri.encodeQueryComponent('${entry.key}')}=${Uri.encodeQueryComponent('${entry.value}')}')
            .join('&');
        request.headers.putIfAbsent('content-type', () => 'application/x-www-form-urlencoded');
      } else if (formData is Map) {
        request.body = formData.entries
            .map((entry) => '${Uri.encodeQueryComponent('${entry.key}')}=${Uri.encodeQueryComponent('${entry.value}')}')
            .join('&');
        request.headers.putIfAbsent('content-type', () => 'application/x-www-form-urlencoded');
      } else if (body is Map || body is List) {
        request.body = jsonEncode(body);
        request.headers.putIfAbsent('content-type', () => 'application/json');
      } else if (body is String) {
        request.body = body;
      }
      final requested = (settings['timeout'] as num?)?.toInt();
      final timeoutMs = requested != null && requested > 0 ? requested.clamp(1000, 60000) : 60000;
      final response = await _client.send(request).timeout(Duration(milliseconds: timeoutMs));
      final bytes = await response.stream.toBytes();
      final binary = settings['binary'] == true;
      final responseBody = binary ? bytes : utf8.decode(bytes, allowMalformed: true);
      final responseMap = <String, Object?>{
        'statusCode': response.statusCode,
        'statusMessage': response.reasonPhrase ?? '',
        'headers': response.headers,
        'body': responseBody,
      };
      return {'response': responseMap, 'body': responseBody};
    } on Object catch (failure) {
      return {'error': '$failure'};
    }
  }

  /// Stops the client and every engine.
  Future<void> dispose() async {
    _generation++;
    final old = _instances;
    _instances = const [];
    _client.close();
    for (final instance in old) {
      await instance.dispose();
    }
  }

  static bool _isUrl(String value) => value.startsWith('http://') || value.startsWith('https://');
}

List<Object?> _list(Object? value) => value is List ? value : const [];

/// The metadata a script's `musicInfo` carries.
Map<String, Object?> lxMusicInfo(audio.MusicTrack track, {Iterable<String> qualitys = const []}) {
  final hash = '${track.metadata['hash'] ?? ''}';
  final hashes = track.metadata['hashes'];
  return {
    'songmid': track.id,
    'songId': track.id,
    'name': track.title,
    'singer': track.artist,
    'albumName': track.album,
    'source': track.sourceId,
    if (track.albumId != null && track.albumId!.isNotEmpty) 'albumId': track.albumId,
    if (hash.isNotEmpty) 'hash': hash,
    if (hashes is Map) 'hashes': hashes,
    if (track.duration != null) 'interval': track.duration!.inSeconds,
    'types': [
      for (final quality in qualitys)
        {'type': quality, if (hashes is Map && hashes[quality] != null) 'hash': '${hashes[quality]}'},
    ],
  };
}

/// The lx runtime over the imported scripts.
final lxScriptRuntimeProvider = Provider<LxScriptRuntime>((ref) {
  final runtime = LxScriptRuntime();
  ref.onDispose(runtime.dispose);
  unawaited(runtime.load(ref.read(musicSourcesProvider)));
  ref.listen(musicSourcesProvider, (_, next) => unawaited(runtime.load(next)));
  return runtime;
});
