import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:io' show ContentType, HttpRequest, HttpServer, InternetAddress;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_playback.dart';

/// The preference the open-API switch is kept under.
const String kMusicOpenApiEnabledKey = 'music.openapi.enabled';

/// The preference the open-API port is kept under.
const String kMusicOpenApiPortKey = 'music.openapi.port';

/// The port lx-music's open API answers on by default.
const int kMusicOpenApiDefaultPort = 23331;

/// lx-music's local open API: a loopback HTTP endpoint other devices and
/// scripts use to drive and read the player. The routes are the reference's
/// (`/status`, `/toggle`, `/play`, `/pause`, `/skip`, `/back`, `/seek`,
/// `/volume`, `/mute`), and every answer is `{code: 0}` JSON.
final class MusicOpenApi {
  /// An open API over the player controller and its current state.
  MusicOpenApi(this._player, this._readState);

  final MusicPlayerController _player;
  final audio.AudioPlaybackState Function() _readState;
  HttpServer? _server;

  /// Whether the endpoint is answering.
  bool get running => _server != null;

  /// Binds the loopback endpoint on [port], replacing any running one.
  Future<void> start(int port) async {
    await stop();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((request) async {
      try {
        await _serve(request);
      } on Object {
        // A bad request still gets an answer below.
      }
    });
  }

  /// Stops answering.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    final answer = await _route(request);
    request.response.statusCode = 200;
    request.response.headers.contentType = _jsonType;
    request.response.write(jsonEncode(answer));
    await request.response.close();
  }

  static final ContentType _jsonType = ContentType('application', 'json', charset: 'utf-8');

  Future<Map<String, Object?>> _route(HttpRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;
    switch (path) {
      case '/status':
        return _status();
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
        final seconds = double.tryParse(query['t'] ?? query['time'] ?? '');
        if (seconds != null) await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
      case '/volume':
        final value = double.tryParse(query['v'] ?? query['value'] ?? '');
        if (value != null) await _player.setVolume(value.clamp(0, 1).toDouble());
        return {'code': 0, 'volume': state.volume};
      case '/mute':
        final value = query['v'] ?? query['value'];
        if (value != null) await _player.setMuted(muted: value == '1' || value == 'true');
        return {'code': 0, 'muted': state.muted};
      default:
        return {'code': -1, 'msg': 'unknown action'};
    }
    return {'code': 0};
  }

  audio.AudioPlaybackState get state => _readState();

  Map<String, Object?> _status() {
    final track = state.track;
    final queue = _player.queue;
    return {
      'code': 0,
      'player': {
        'playing': state.playing,
        'title': track?.title ?? '',
        'singer': track?.artist ?? '',
        'album': track?.album ?? '',
        'source': track?.sourceId ?? '',
        'duration': state.duration.inMilliseconds / 1000,
        'currentTime': state.position.inMilliseconds / 1000,
        'volume': state.volume,
        'muted': state.muted,
        'rate': state.rate,
        'playMode': state.mode.name,
      },
      'listName': '',
      'playlist': [
        for (final entry in queue) {'title': entry.title, 'singer': entry.artist},
      ],
    };
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

  /// Sets the listening port.
  Future<void> set(int port) async {
    state = port;
    await StoragePrefs.setInt(kMusicOpenApiPortKey, port);
  }
}

/// The module's open API, started and stopped by the gate and port.
final musicOpenApiProvider = Provider<MusicOpenApi>((ref) {
  final api = MusicOpenApi(ref.read(musicPlayerProvider.notifier), () => ref.read(musicPlayerProvider));
  Future<void> sync() async {
    if (ref.watch(musicOpenApiGateProvider)) {
      await api.start(ref.watch(musicOpenApiPortProvider));
    } else {
      await api.stop();
    }
  }

  unawaited(sync());
  Timer(const Duration(seconds: 2), () => unawaited(sync()));
  ref.onDispose(api.stop);
  return api;
});

final musicOpenApiGateProvider = NotifierProvider<MusicOpenApiGate, bool>(MusicOpenApiGate.new);
final musicOpenApiPortProvider = NotifierProvider<MusicOpenApiPort, int>(MusicOpenApiPort.new);
