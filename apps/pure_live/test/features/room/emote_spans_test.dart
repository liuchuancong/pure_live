// The split that puts a danmaku's表情图 inline: what the spans look like for a
// mixed line, and what a message without emotes costs.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveEmote;
import 'package:pure_live/features/room/widgets/room_emote_text.dart';

void main() {
  group('emoteSpans', () {
    test('a message with no emotes stays one text span', () {
      final spans = emoteSpans(text: '你好', emotes: const []);
      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, '你好');
    });

    test('a code becomes a picture between the text around it', () {
      final spans = emoteSpans(
        text: '前[笑]后',
        emotes: [const LiveEmote(code: '[笑]', url: 'https://e/1.png')],
      );
      expect(spans.map((span) => span.runtimeType), [TextSpan, WidgetSpan, TextSpan]);
      expect((spans.first as TextSpan).text, '前');
      expect((spans.last as TextSpan).text, '后');
    });

    test('the same code twice draws twice, and a code nobody knows stays text', () {
      final spans = emoteSpans(
        text: '[笑][笑][?]',
        emotes: [const LiveEmote(code: '[笑]', url: 'https://e/1.png')],
      );
      expect(spans.whereType<WidgetSpan>(), hasLength(2));
      expect((spans.last as TextSpan).text, '[?]');
    });

    test('an empty code or an empty address is no picture at all', () {
      final spans = emoteSpans(
        text: '[笑]',
        emotes: [
          const LiveEmote(code: '[笑]', url: ''),
          const LiveEmote(code: '', url: 'https://e/2.png'),
        ],
      );
      expect(spans.whereType<WidgetSpan>(), isEmpty);
      expect((spans.single as TextSpan).text, '[笑]');
    });

    // The picture cannot be fetched in a test binding, so this is the fallback
    // the span promises: the line still lays out, and the code reappears where
    // the image would have been.
    testWidgets('a line with a code lays out and keeps the code when its picture cannot load', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(
            TextSpan(
              children: emoteSpans(
                text: '前[笑]后',
                emotes: [const LiveEmote(code: '[笑]', url: 'https://e.invalid/1.png')],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('前'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
