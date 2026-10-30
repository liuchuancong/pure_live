import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:io' show ContentType, HttpRequest, HttpResponse, HttpServer, InternetAddress;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart'
    show MusicFavouritesController, musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart';

/// The preference the open-API switch is kept under.
const String kMusicOpenApiEnabledKey = 'music.openapi.enabled';

/// The preference the open-API port is kept under.
const String kMusicOpenApiPortKey = 'music.openapi.port';

/// The preference the LAN switch is kept under, the reference's
/// `openAPI.bindLan`.
const String kMusicOpenApiLanKey = 'music.openapi.lan';

/// The port lx-music's open API answers on by default.
const int kMusicOpenApiDefaultPort = 23331;

/// The status keys the flat answers speak, the reference's
/// LX.Player.Status in its own order.
const List<String> kMusicOpenApiStatusKeys = [
  'status',
  'name',
  'singer',
  'albumName',
  'picUrl',
  'progress',
  'duration',
  'playbackRate',
  'lyricLineText',
  'lyricLineAllText',
  'lyric',
  'tlyric',
  'rlyric',
  'lxlyric',
  'collect',
  'volume',
  'mute',
];

/// The keys a subscription without `?filter=` follows, the reference's
/// defaultFilter.
const List<String> kMusicOpenApiDefaultFilter = [
  'status',
  'name',
  'singer',
  'albumName',
  'lyricLineText',
  'duration',
  'progress',
  'playbackRate',
];

/// Reads a subscription's `?filter=`: a comma list kept in status-key order,
/// falling back to the default when it names nothing known — the reference's
/// parseFilter.
List<String> musicOpenApiParseFilter(String? raw) {
  if (raw == null || raw.isEmpty) return kMusicOpenApiDefaultFilter;
  final requested = raw.split(',');
  final keys = [
    for (final key in kMusicOpenApiStatusKeys)
      if (requested.contains(key)) key,
  ];
  return keys.isEmpty ? kMusicOpenApiDefaultFilter : keys;
}

/// The reference's status verb for a playback state: an error wins, then
/// playing, then a loaded track sits paused, and with nothing loaded the
/// player is `stoped` (the reference's spelling).
String musicOpenApiStatusName(audio.AudioPlaybackState state) {
  if (state.error != null) return 'error';
  if (state.playing) return 'playing';
  return state.hasTrack ? 'paused' : 'stoped';
}

/// The reference's lxlyric track. v2 keeps word timing inside the parsed
/// lines, so the enhanced-LRC rendering stands in: each line with word tags
/// reads `[mm:ss.xx]<mm:ss.xx>word…`, a lyric with none contributes ''.
String musicOpenApiLxLyricOf(audio.LyricDocument? document) {
  if (document == null) return '';
  final buffer = StringBuffer();
  for (final line in document.lines) {
    if (line.words.isEmpty) continue;
    buffer
      ..write('[')
      ..write(_lrcTimestamp(line.start))
      ..write(']');
    for (final word in line.words) {
      buffer
        ..write('<')
        ..write(_lrcTimestamp(word.start))
        ..write('>')
        ..write(word.text);
    }
    buffer.write('\n');
  }
  return buffer.toString().trimRight();
}

String _lrcTimestamp(Duration time) {
  final minutes = time.inMinutes.toString().padLeft(2, '0');
  final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  final centis = ((time.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$minutes:$seconds.$centis';
}

/// What a route answers with: a JSON body by default, or a plain string for
/// the routes that speak text and the failures.
final class _ApiAnswer {
  const _ApiAnswer(this.status, this.body);

  final int status;
  final Object? body;
}

/// lx-music's local open API: an HTTP endpoint other devices and scripts use
/// to drive and read the player. The routes are the reference's (`/status`,
/// `/lyric`, `/lyric-all`, `/toggle`, `/play`, `/pause`, `/skip`, `/back`,
/// `/seek`, `/volume`, `/mute`, `/collect`, `/uncollect` and the
/// `/subscribe-player-status` stream), with `/subscribe-player-status`
/// pushing one `event:` per changed status key.
final class MusicOpenApi {
  /// An open API over the player controller, its current state, the lyric
  /// loader and the favourites.
  MusicOpenApi(
    this._player,
    this._readState, {
    required this._loadLyric,
    required this._favourites,
    required this._isFavourite,
  });

  final MusicPlayerController _player;
  final audio.AudioPlaybackState Function() _readState;
  final Future<audio.LyricDocument> Function({bool force}) _loadLyric;
  final MusicFavouritesController _favourites;
  final bool Function(audio.MusicTrack track) _isFavourite;
  HttpServer? _server;
  final Map<HttpResponse, List<String>> _subscribers = {};
  Map<String, Object?> _lastStatus = const {};
  audio.LyricDocument? _lyric;
  String? _lyricKey;
  bool _pushing = false;
  bool _pushPending = false;

  /// Whether the endpoint is answering.
  bool get running => _server != null;

  /// The address the endpoint answers on, the reference's status line.
  String address(int port) {
    if (!running) return '';
    final host = _server?.address.address ?? '127.0.0.1';
    return 'http://$host:$port';
  }

  /// Binds the endpoint on [port] — the loopback alone, or every interface
  /// when [lan] is on, the reference's bindLan — replacing any running one.
  Future<void> start(int port, {required bool lan}) async {
    await stop();
    _server = await HttpServer.bind(lan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4, port);
    _server!.listen((request) async {
      try {
        await _serve(request);
      } on Object {
        // A bad request still gets an answer below.
      }
    });
  }

  /// Stops answering and drops every subscription.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _subscribers.clear();
    await server?.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    if (request.uri.path == '/subscribe-player-status') {
      await _serveSubscription(request);
      return;
    }
    _ApiAnswer answer;
    try {
      answer = await _route(request);
    } on Object {
      answer = const _ApiAnswer(500, 'Error');
    }
    final response = request.response;
    final body = answer.body is String ? answer.body! as String : jsonEncode(answer.body);
    response
      ..statusCode = answer.status
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..headers.contentType = answer.body is String
          ? ContentType('text', 'plain', charset: 'utf-8')
          : _jsonType
      ..write(body);
    await response.close();
  }

  static final ContentType _jsonType = ContentType('application', 'json', charset: 'utf-8');

  Future<_ApiAnswer> _route(HttpRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;
    switch (path) {
      case '/status':
        final status = await _playerStatus();
        return _ApiAnswer(200, {for (final key in musicOpenApiParseFilter(query['filter'])) key: status[key]});
      case '/lyric':
        final status = await _playerStatus();
        return _ApiAnswer(200, status['lyric']! as String);
      case '/lyric-all':
        final status = await _playerStatus();
        return _ApiAnswer(200, {
          'lyric': status['lyric'],
          'tlyric': status['tlyric'],
          'rlyric': status['rlyric'],
          'lxlyric': status['lxlyric'],
        });
      case '/toggle':
        await _player.toggle();
      case '/play':
        await _player.toggle();
      case '/pause':
        if (state.playing) await _player.toggle();
      case '/skip':
        await _player.next();
      case '/back':
        await _player.previous();
      case '/seek':
        final seconds = double.tryParse(query['offset'] ?? query['t'] ?? query['time'] ?? '');
        if (seconds == null || seconds < 0 || seconds > state.duration.inMilliseconds / 1000) {
          return const _ApiAnswer(400, 'Invalid offset');
        }
        await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
      case '/volume':
        return await _setVolume(query);
      case '/mute':
        return await _setMute(query);
      case '/collect':
        await _setCollected(true);
      case '/uncollect':
        await _setCollected(false);
      default:
        return const _ApiAnswer(401, 'Forbidden');
    }
    return const _ApiAnswer(200, {'code': 0});
  }

  /// The reference takes `?volume=` as 0–100; the module's earlier
  /// `?v=`/`?value=` spelling read a 0–1 fraction and still does.
  Future<_ApiAnswer> _setVolume(Map<String, String> query) async {
    final reference = query['volume'];
    if (reference != null) {
      final value = int.tryParse(reference);
      if (value == null || value < 0 || value > 100) return const _ApiAnswer(400, 'Invalid volume');
      await _player.setVolume(value / 100);
    } else {
      final legacy = query['v'] ?? query['value'];
      final value = legacy == null ? null : double.tryParse(legacy);
      if (value != null) await _player.setVolume(value.clamp(0, 1).toDouble());
    }
    return _ApiAnswer(200, {'code': 0, 'volume': (state.volume.clamp(0, 1) * 100).round()});
  }

  /// The reference takes `?mute=true|false` strictly; the module's earlier
  /// `?v=`/`?value=` spelling still answers `1`/`true`.
  Future<_ApiAnswer> _setMute(Map<String, String> query) async {
    final reference = query['mute'];
    if (reference != null) {
      if (reference != 'true' && reference != 'false') return const _ApiAnswer(400, 'Invalid mute value');
      await _player.setMuted(muted: reference == 'true');
    } else {
      final legacy = query['v'] ?? query['value'];
      if (legacy != null) await _player.setMuted(muted: legacy == '1' || legacy == 'true');
    }
    return _ApiAnswer(200, {'code': 0, 'mute': state.muted});
  }

  /// Collect is the reference's love: only added when absent, uncollect
  /// only removed when present.
  Future<void> _setCollected(bool love) async {
    final track = state.track;
    if (track == null || _isFavourite(track) == love) return;
    await _favourites.toggle(track);
  }

  /// Answers a subscription: the event-stream headers, an initial event per
  /// filtered key, and the socket joins the push set until it hangs up.
  Future<void> _serveSubscription(HttpRequest request) async {
    final response = request.response;
    final keys = musicOpenApiParseFilter(request.uri.queryParameters['filter']);
    response.statusCode = 200;
    response.headers
      ..contentType = ContentType('text', 'event-stream')
      ..add('Connection', 'keep-alive')
      ..add('Cache-Control', 'no-cache')
      ..add('Access-Control-Allow-Origin', '*');
    _subscribers[response] = keys;
    unawaited(response.done.then((_) => _subscribers.remove(response)));
    final status = await _playerStatus();
    _lastStatus = status;
    response.write(_eventsText(keys, status));
    await response.flush();
  }

  /// Pushes what changed since the last write to every subscriber; the
  /// player and the favourites both call in. Coalesces a change arriving
  /// while a push is still writing — position ticks outpace the lyric read.
  void pushPlayerStatus() {
    if (_subscribers.isEmpty) return;
    unawaited(_pushStatus());
  }

  Future<void> _pushStatus() async {
    if (_pushing) {
      _pushPending = true;
      return;
    }
    _pushing = true;
    try {
      while (true) {
        _pushPending = false;
        final status = await _playerStatus();
        final changed = <String, Object?>{
          for (final entry in status.entries)
            if (_lastStatus[entry.key] != entry.value) entry.key: entry.value,
        };
        _lastStatus = status;
        if (changed.isNotEmpty && _subscribers.isNotEmpty) {
          for (final subscriber in _subscribers.keys.toList(growable: false)) {
            final text = _eventsText(_subscribers[subscriber]!, changed);
            if (text.isEmpty) continue;
            try {
              subscriber.write(text);
              unawaited(subscriber.flush().then((_) {}, onError: (_) => _subscribers.remove(subscriber)));
            } on Object {
              _subscribers.remove(subscriber);
            }
          }
        }
        if (!_pushPending) return;
      }
    } finally {
      _pushing = false;
    }
  }

  /// The events for [values] — the full status for a snapshot, the changed
  /// keys for a push (an absent key writes nothing).
  String _eventsText(List<String> keys, Map<String, Object?> values) {
    final buffer = StringBuffer();
    for (final key in keys) {
      final value = values[key];
      if (value == null) continue;
      buffer
        ..write('event: $key\n')
        ..write('data: ${jsonEncode(value)}\n\n');
    }
    return buffer.toString();
  }

  audio.AudioPlaybackState get state => _readState();

  /// The player in the reference's status shape: the track's names, the
  /// clock and the rate, the lyric document's four tracks and the current
  /// line, the collect flag, the volume in the reference's 0–100.
  Future<Map<String, Object?>> _playerStatus() async {
    final state = this.state;
    final track = state.track;
    final document = await _lyricFor(state);
    final line = document != null && document.isSynchronized ? document.lineAt(state.position) : null;
    final lineText = line?.text ?? '';
    final extended = line?.secondaryTexts().join('\n') ?? '';
    return {
      'status': musicOpenApiStatusName(state),
      'name': track?.title ?? '',
      'singer': track?.artist ?? '',
      'albumName': track?.album ?? '',
      'picUrl': track?.coverUri?.toString() ?? '',
      'progress': state.position.inMilliseconds / 1000,
      'duration': state.duration.inMilliseconds / 1000,
      'playbackRate': state.rate,
      'lyricLineText': lineText,
      'lyricLineAllText': extended.isEmpty ? lineText : '$lineText\n$extended',
      'lyric': document?.raw ?? '',
      'tlyric': document?.rawTranslation ?? '',
      'rlyric': document?.rawRomanization ?? '',
      'lxlyric': musicOpenApiLxLyricOf(document),
      'collect': track != null && _isFavourite(track),
      'volume': (state.volume.clamp(0, 1) * 100).round(),
      'mute': state.muted,
    };
  }

  /// The current track's lyric, reloaded when the track, the viewer offset
  /// or the revision changes — the player page's own reload condition. The
  /// loader caches per track, so concurrent reads share one fetch.
  Future<audio.LyricDocument?> _lyricFor(audio.AudioPlaybackState state) async {
    final track = state.track;
    if (track == null) {
      _lyricKey = null;
      _lyric = null;
      return null;
    }
    final key = '${track.id}|${state.lyricOffset.inMilliseconds}|${state.lyricRevision}';
    if (key == _lyricKey) return _lyric;
    _lyricKey = key;
    try {
      _lyric = await _loadLyric();
    } on Object {
      _lyric = null;
    }
    return _lyric;
  }
}

/// The open API's on/off switch, persisted like the rest of the module's
/// settings. Changing it restarts the endpoint.
final class MusicOpenApiGate extends Notifier<bool> {
  @override
  bool build() => StoragePrefs.getBool(kMusicOpenApiEnabledKey) ?? false;

  /// Turns the endpoint on or off.
  Future<void> set({required bool enabled}) async {
    state = enabled;
    await StoragePrefs.setBool(kMusicOpenApiEnabledKey, enabled);
  }
}

/// The open API's port, persisted; a change restarts the endpoint.
final class MusicOpenApiPort extends Notifier<int> {
  @override
  int build() => StoragePrefs.getInt(kMusicOpenApiPortKey) ?? kMusicOpenApiDefaultPort;

  /// Sets the listening port; a value outside the unprivileged range keeps
  /// the previous one.
  Future<void> set(int port) async {
    if (port < 1 || port > 65535) return;
    state = port;
    await StoragePrefs.setInt(kMusicOpenApiPortKey, port);
  }
}

/// The open API's LAN switch, the reference's `openAPI.bindLan`; a change
/// rebinds the endpoint through the running gate.
final class MusicOpenApiLan extends Notifier<bool> {
  @override
  bool build() => StoragePrefs.getBool(kMusicOpenApiLanKey) ?? false;

  /// Turns LAN access on or off.
  Future<void> set({required bool lan}) async {
    state = lan;
    await StoragePrefs.setBool(kMusicOpenApiLanKey, lan);
  }
}

/// The module's open API, started and stopped by the gate, port and LAN
/// switch; the player and favourites feed the status stream.
final musicOpenApiProvider = Provider<MusicOpenApi>((ref) {
  final api = MusicOpenApi(
    ref.read(musicPlayerProvider.notifier),
    () => ref.read(musicPlayerProvider),
    loadLyric: ({force = false}) => ref.read(musicPlayerProvider.notifier).loadLyric(force: force),
    favourites: ref.read(musicFavouritesProvider.notifier),
    isFavourite: (track) => ref.read(musicFavouritesProvider).contains(track),
  );
  Future<void> sync() async {
    if (ref.watch(musicOpenApiGateProvider)) {
      await api.start(ref.watch(musicOpenApiPortProvider), lan: ref.watch(musicOpenApiLanProvider));
    } else {
      await api.stop();
    }
  }

  unawaited(sync());
  Timer(const Duration(seconds: 2), () => unawaited(sync()));
  ref
    ..listen(musicPlayerProvider, (_, _) => api.pushPlayerStatus())
    ..listen(musicFavouritesProvider, (_, _) => api.pushPlayerStatus())
    ..onDispose(api.stop);
  return api;
});

final musicOpenApiGateProvider = NotifierProvider<MusicOpenApiGate, bool>(MusicOpenApiGate.new);
final musicOpenApiPortProvider = NotifierProvider<MusicOpenApiPort, int>(MusicOpenApiPort.new);
final musicOpenApiLanProvider = NotifierProvider<MusicOpenApiLan, bool>(MusicOpenApiLan.new);
