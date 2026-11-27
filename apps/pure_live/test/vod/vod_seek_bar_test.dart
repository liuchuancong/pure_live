import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart';

void main() {
  testWidgets('the seek bar takes focus and answers the keyboard', (tester) async {
    final seeks = <double>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: SizedBox(
            width: 300,
            child: VodSeekBar(
              position: const Duration(seconds: 30),
              duration: const Duration(minutes: 2),
              onSeek: seeks.add,
              showPreview: false,
            ),
          ),
        ),
      ),
    );

    final focus = tester.widget<Focus>(
      find.byWidgetPredicate((widget) => widget is Focus && widget.focusNode?.debugLabel == 'vod-seek-bar'),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);

    expect(seeks, [35.0, 25.0, 0.0, 120.0]);
  });
}
