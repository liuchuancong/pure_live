import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/keyboard/video_keyboard.dart';

void main() {
  test('Escape pops a normal live room route', () {
    expect(
      resolveEscapePresentationAction(pip: false, fullscreen: false, widescreen: false),
      EscapePresentationAction.popRoute,
    );
  });

  test('Escape exits the active fullscreen presentation', () {
    expect(
      resolveEscapePresentationAction(pip: false, fullscreen: true, widescreen: false),
      EscapePresentationAction.exitFullscreen,
    );
  });

  test('Escape exits widescreen instead of entering fullscreen', () {
    expect(
      resolveEscapePresentationAction(pip: false, fullscreen: false, widescreen: true),
      EscapePresentationAction.exitWidescreen,
    );
  });

  test('PiP owns Escape even if stale presentation flags remain set', () {
    expect(
      resolveEscapePresentationAction(pip: true, fullscreen: true, widescreen: true),
      EscapePresentationAction.none,
    );
  });

  testWidgets('Escape pops an offline room before a VideoController exists', (tester) async {
    Get.testMode = true;
    Get.put(GlobalPlayerState());
    addTearDown(() {
      Get.reset();
      Get.testMode = false;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const VideoKeyboardShortcuts(controller: null, child: Text('offline-room')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('offline-room'), findsOneWidget);

    // A failed room may inherit stale presentation flags from an interrupted
    // source load. With no VideoController those flags must not swallow Escape.
    GlobalPlayerState.to.isFullscreen.value = true;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('offline-room'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
