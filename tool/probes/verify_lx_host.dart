// Probe: run the lx-music host against a tiny in-repo lx source script.
// Opt-in; requires the fjs native library on the host machine.
import 'package:pure_live_music/pure_live_music.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

const String script = '''
lx.on(lx.EVENT_NAMES.request, function (data, callback) {
  if (data.action === 'musicUrl') {
    callback(null, 'https://example.com/stream/' + data.source + '/' + data.info.musicId + '.m3u8');
    return;
  }
  callback(new Error('unsupported action ' + data.action));
});
lx.send(lx.EVENT_NAMES.inited, {
  name: 'Probe Source',
  version: '1.0.0',
  sources: {
    wy: { name: '网易云', type: 'music', actions: ['musicUrl'], qualitys: ['128k', '320k'] },
  },
}).then(function () {
  if (globalThis.__probe_ready === undefined) globalThis.__probe_ready = true;
});
''';

Future<void> main() async {
  final host = await MusicSourceScriptHost.spawn(
    scriptId: 'probe.lx',
    name: 'Probe',
    source: script,
    bridge: _ProbeBridge(),
  );
  final info = await host.awaitInited();
  print('inited: ${info.name}, sources: ${info.sources.keys.toList()}');
  final url = await host.musicUrl('wy', '186001', '320k');
  print('musicUrl: $url');
  await host.dispose();
  print('OK');
}

final class _ProbeKv implements PluginKvStore {
  final _values = <String, Object?>{};
  @override
  Future<Object?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, Object? value) async => _values[key] = value;
  @override
  Future<void> remove(String key) async => _values.remove(key);
  @override
  Future<List<String>> keys() async => _values.keys.toList(growable: false);
}

final class _ProbeEventSink implements PluginEventSink {
  @override
  void publish(String name, {Map<String, Object?> payload = const <String, Object?>{}}) =>
      print('[event] \$name \$payload');
}

final class _ProbeBridge implements HostBridge {
  final _kv = _ProbeKv();
  @override
  PluginKvStore get kv => _kv;
  @override
  PluginEventSink get events => _ProbeEventSink();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('probe bridge: \${invocation.memberName}');
}
