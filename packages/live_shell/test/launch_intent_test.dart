import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

void main() {
  group('launch intent round trip', () {
    test('a room link survives the handoff', () {
      final intent = OpenRoomLink(Uri.parse('https://live.example.com/room/12345?x=1'));

      final back = LaunchIntent.fromArguments(intent.toArguments());

      expect(back, isA<OpenRoomLink>());
      expect((back! as OpenRoomLink).link, intent.link);
    });

    test('a file path with spaces and quotes survives', () {
      const intent = OpenFile(r'C:\Users\A B\我的 直播 [v2].m3u');

      final back = LaunchIntent.fromArguments(intent.toArguments());

      expect((back! as OpenFile).path, intent.path);
    });

    test('show with and without a route are distinct', () {
      expect(LaunchIntent.fromArguments(const ShowMainWindow().toArguments()), const ShowMainWindow());
      expect(
        LaunchIntent.fromArguments(const ShowMainWindow(route: '/recordings').toArguments()),
        const ShowMainWindow(route: '/recordings'),
      );
      expect(const ShowMainWindow(route: '/a'), isNot(const ShowMainWindow(route: '/b')));
    });

    test('a new window and the recorder come back as themselves', () {
      final args = [...const NewWindow(route: '/live').toArguments()];

      expect(LaunchIntent.fromArguments(args), const NewWindow(route: '/live'));
      expect(LaunchIntent.fromArguments(const ShowRecorder().toArguments()), const ShowRecorder());
    });

    test('an unrelated argument carries nothing', () {
      expect(LaunchIntent.fromArguments(['file.m3u', '--flag']), isNull);
      expect(LaunchIntent.carriesIntent(['--hidden']), isFalse);
      expect(LaunchIntent.carriesIntent(const ShowMainWindow().toArguments()), isTrue);
    });

    test('a damaged payload is ignored rather than thrown', () {
      expect(LaunchIntent.fromArguments(['${LaunchIntent.argumentFlag}not json']), isNull);
      expect(LaunchIntent.fromArguments(['${LaunchIntent.argumentFlag}{"kind":"file"}']), isNull);
      expect(LaunchIntent.fromArguments(['${LaunchIntent.argumentFlag}{"kind":"nonsense","value":"x"}']), isNull);
      expect(LaunchIntent.fromArguments(['${LaunchIntent.argumentFlag}[]']), isNull);
    });
  });

  group('start shape', () {
    test('a headless start is recognised before anything is opened', () {
      expect(isHeadlessStart(['--version']), isTrue);
      expect(isHeadlessStart(['-V']), isTrue);
      expect(isHeadlessStart(['--cli', 'export']), isTrue);
      expect(isHeadlessStart(['--hidden']), isFalse, reason: 'hidden still wants a tray, not a print');
      expect(isHeadlessStart(const ShowMainWindow().toArguments()), isFalse);
    });

    test('hidden start comes either from our own flag or from the OS', () {
      expect(wasRequestedHidden(arguments: const ['--hidden']), isTrue);
      expect(wasRequestedHidden(arguments: const [], openedAsHiddenBySystem: true), isTrue);
      expect(wasRequestedHidden(arguments: const ['--no-sandbox']), isFalse);
    });
  });

  group('what a hand-off carries', () {
    test('an explicit intent is forwarded as written', () {
      final handed = intentForHandoff(const OpenFile('/playlists/live.m3u').toArguments());

      expect(handed, isA<OpenFile>());
      expect((handed! as OpenFile).path, '/playlists/live.m3u');
    });

    test('launching a running app with no arguments is itself the request to show it', () {
      // Without this the second process hands over "nothing", the running app
      // stays hidden in the tray, and the viewer's double-click produced no
      // window and no error anywhere — the report nobody can reproduce.
      expect(intentForHandoff(const []), isA<ShowMainWindow>());
      expect(intentForHandoff(const ['--no-sandbox']), isA<ShowMainWindow>());
    });

    test('a relaunch that asked to stay hidden is not allowed to raise a window', () {
      expect(intentForHandoff(const ['--hidden']), isNull);
    });
  });
}
