// The danmaku file formats: a recording and a download hand their files to
// other players, so a writer that escapes wrong or a reader that drops the
// timeline produces files that will not play — each format here is pinned
// by a round trip and by the details only its format carries.

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuColor, DanmakuPlacement;
import 'package:pure_live/shared/danmaku/danmaku_entry.dart';
import 'package:pure_live/shared/danmaku/formats/formats.dart';

List<DanmakuEntry> _entries() => const [
  DanmakuEntry(time: Duration(seconds: 1, milliseconds: 500), text: '前方高能 & <注意>', color: DanmakuColor(255, 0, 0)),
  DanmakuEntry(time: Duration(seconds: 30), text: '置顶一条', placement: DanmakuPlacement.top),
  DanmakuEntry(time: Duration(minutes: 2, seconds: 3), text: '底部"引号"与\n换行', placement: DanmakuPlacement.bottom),
];

void main() {
  group('BilibiliDanmakuXml', () {
    test('decode → encode → decode round-trips the lines', () {
      final first = BilibiliDanmakuXml.decode(BilibiliDanmakuXml.encode(_entries()));
      expect(first.map((entry) => entry.text), _entries().map((entry) => entry.text));
      expect(first.map((entry) => entry.time), _entries().map((entry) => entry.time));
    });

    test('the escaped entities come back as their characters', () {
      final round = BilibiliDanmakuXml.decode(BilibiliDanmakuXml.encode([_entries().first]));
      expect(round.single.text, '前方高能 & <注意>');
    });
  });

  group('BilibiliDanmakuJson', () {
    test('decode → encode → decode round-trips the lines', () {
      final first = BilibiliDanmakuJson.decode(BilibiliDanmakuJson.encode(_entries()));
      expect(first.map((entry) => entry.text), _entries().map((entry) => entry.text));
      expect(first.map((entry) => entry.time), _entries().map((entry) => entry.time));
      expect(first.map((entry) => entry.placement), _entries().map((entry) => entry.placement));
    });
  });

  group('AssDanmaku', () {
    test('one dialogue line per entry, lines in timeline order', () {
      final script = AssDanmaku.encode(_entries());
      expect(script, contains('[Script Info]'));
      final dialogues = RegExp('^Dialogue:', multiLine: true).allMatches(script);
      expect(dialogues.length, _entries().length);
      final positions = dialogues.map((match) => script.indexOf(match.group(0)!));
      expect(positions, _isSorted());
    });

    test('a brace in the text cannot break the dialogue line', () {
      final script = AssDanmaku.encode(const [DanmakuEntry(time: Duration(seconds: 5), text: r'{\alpha&50}诡异括号')]);
      // The ASCII braces become full-width ones, so the text cannot open a
      // dialogue tag of its own.
      expect(script, contains(r'｛\alpha&50｝诡异括号'));
      expect(RegExp(r'{\x5Calpha&50').allMatches(script), isEmpty);
    });
  });

  group('SrtDanmaku', () {
    test('one cue per line, four seconds long, numbered in order', () {
      final srt = SrtDanmaku.encode(_entries());
      expect(srt, startsWith('1\n'));
      expect(RegExp(r'^\d+$', multiLine: true).allMatches(srt).length, _entries().length);
      expect(srt, contains('00:00:01,500 --> 00:00:05,500'));
      expect(srt, contains('00:02:03,000 --> 00:02:07,000'));
    });

    test('a newline in the text reads as one cue line, not two', () {
      final cue = SrtDanmaku.cue(_entries().last, 7);
      expect(cue, contains('底部"引号"与 换行'));
      expect(cue.indexOf('7\n'), 0);
    });
  });
}

/// A matcher over an iterable of numbers that expects each to be at least the
/// one before it.
Matcher _isSorted() => predicate<Iterable<int>>((values) {
  final list = values.toList();
  for (var i = 1; i < list.length; i++) {
    if (list[i] < list[i - 1]) return false;
  }
  return true;
}, 'sorted ascending');
