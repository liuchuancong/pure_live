import 'package:flutter_test/flutter_test.dart';
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

void main() {
  group('WindowArguments', () {
    test('a role and route come back as they went', () {
      const arguments = WindowArguments(role: WindowRole.videoFloat, route: '/room/42');

      final read = WindowArguments.fromRaw(arguments.encode());

      expect(read.role, WindowRole.videoFloat);
      expect(read.route, '/room/42');
      expect(read.entryPoint, 'main');
    });

    test('no route stays absent rather than becoming an empty string', () {
      // An empty route would make the new window navigate to "" and land on a
      // blank page, which looks like a broken window rather than a default one.
      const arguments = WindowArguments(role: WindowRole.panel);

      final encoded = arguments.encode();
      final read = WindowArguments.fromRaw(encoded);

      expect(encoded, isNot(contains('route')));
      expect(read.route, isNull);
    });

    test('the entry point is carried, so one main() can serve several window kinds', () {
      const arguments = WindowArguments(role: WindowRole.popup, entryPoint: 'toast');

      expect(WindowArguments.fromRaw(arguments.encode()).entryPoint, 'toast');
    });

    test('unparseable arguments fall back to the main window', () {
      for (final raw in ['', 'not json', '{"role":', '[]', '{}']) {
        expect(
          WindowArguments.fromRaw(raw).role,
          WindowRole.main,
          reason: 'a window started by an older build must come up, not crash on a missing key: $raw',
        );
      }
    });

    test('an unknown role name falls back instead of throwing', () {
      // Roles are appended, never renamed, but a downgrade install (new build
      // data, old binary) hits exactly this path.
      final read = WindowArguments.fromRaw('{"role":"sidebar","entry":"main"}');

      expect(read.role, WindowRole.main);
      expect(read.entryPoint, 'main');
    });

    test('a wrong entry type is ignored rather than cast', () {
      final read = WindowArguments.fromRaw('{"role":"panel","entry":7}');

      expect(read.role, WindowRole.panel);
      expect(read.entryPoint, 'main');
    });
  });

  group('round trip', () {
    test('every role round-trips', () {
      for (final role in WindowRole.values) {
        final read = WindowArguments.fromRaw(WindowArguments(role: role).encode());

        expect(read.role, role, reason: role.name);
      }
    });
  });
}
