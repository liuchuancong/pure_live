import 'package:flutter_test/flutter_test.dart';
import 'package:live_log/live_log.dart' show LogLevel, LogRecord;
import 'package:live_net/live_net.dart' show ConnectFailure, HttpStatusFailure;
import 'package:pure_live/app/logging/app_log.dart' show appLogMemory;
import 'package:pure_live/modules/music/controller/sources/comment_emojis.dart';
import 'package:pure_live/modules/music/controller/sources/music_source_failure.dart';

/// The music module's quiet corners: the note a silenced call leaves (its
/// kind naming the side that failed, the repeat dropped), and the emoji
/// tables the comment sheets read — every code shaped for its bracket form
/// and every face a character.
void main() {
  List<LogRecord> notesOf(String where) => [
    for (final record in appLogMemory.query(categoryPrefix: 'music.source'))
      if (record.fields['where'] == where) record,
  ];

  test('a platform failure is noted as one, with the error and its stack', () {
    final failure = HttpStatusFailure(statusCode: 403, url: Uri(path: 'x'));
    final stack = StackTrace.current;
    noteMusicSourceSilence('probe-platform', failure, stack);

    final noted = notesOf('probe-platform');
    expect(noted, hasLength(1));
    expect(noted.single.fields['kind'], 'platform');
    expect(noted.single.error, same(failure));
    expect(noted.single.stackTrace, same(stack));
    expect(noted.single.level, LogLevel.error);
  });

  test('a transport failure reads as the platform, an unknown one as our reader', () {
    noteMusicSourceSilence('probe-transport', const ConnectFailure('down'), StackTrace.current);
    noteMusicSourceSilence('probe-reader', StateError('shapeless'), StackTrace.current);

    expect(notesOf('probe-transport').single.fields['kind'], 'platform');
    expect(notesOf('probe-reader').single.fields['kind'], 'reader');
  });

  test('the same site, kind and failure type note once, and a different site notes again', () {
    noteMusicSourceSilence('probe-repeat', StateError('first'), StackTrace.current);
    noteMusicSourceSilence('probe-repeat', StateError('second'), StackTrace.current);
    noteMusicSourceSilence('probe-repeat', HttpStatusFailure(statusCode: 500, url: Uri(path: 'x')), StackTrace.current);
    noteMusicSourceSilence('probe-other', StateError('first'), StackTrace.current);

    expect(notesOf('probe-repeat'), hasLength(2)); // the reader note once, the platform note once
    expect(notesOf('probe-other'), hasLength(1)); // a different site is a different note
  });

  test('the QQ and Netease emoji tables are shaped for their bracket forms', () {
    expect(kTxCommentEmojis, isNotEmpty);
    expect(kWyCommentEmojis, isNotEmpty);
    for (final entry in kTxCommentEmojis.entries) {
      expect(RegExp(r'^e\d+$').hasMatch(entry.key), isTrue, reason: entry.key); // [em]e…[/em]'s half
      expect(entry.value, isNotEmpty);
      expect(entry.value.codeUnits.length, lessThan(4), reason: '${entry.key}: ${entry.value}'); // a face, not a word
    }
    for (final entry in kWyCommentEmojis.entries) {
      expect(entry.key, isNotEmpty);
      expect(entry.value, isNotEmpty);
    }
    // No two codes share a face inside a table: the sheet would show the
    // same smile for different words.
    expect(kTxCommentEmojis.values.toSet().length, kTxCommentEmojis.length);
  });
}
