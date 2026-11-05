import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/room/controller/room_open_timing.dart';

/// A clock that moves a fixed step per reading, so the numbers say which stage
/// came in which order rather than how fast this machine is.
RoomOpenTiming _timing({required String site, required String roomId}) {
  var tick = 0;
  return RoomOpenTiming(
    site: site,
    roomId: roomId,
    now: () => DateTime(2026, 11, 5, 12).add(Duration(milliseconds: 100 * tick++)),
  );
}

void main() {
  test('every stage is measured from the one before it', () {
    final timing = _timing(site: 'bilibili', roomId: '123')
      ..markDetail()
      ..markQualities()
      ..markLines()
      ..markRequested()
      ..markFirstFrame()
      ..markPlaying()
      ..markChat();

    final line = timing.line();
    expect(line, contains('site=bilibili'));
    expect(line, contains('room=123'));
    expect(line, contains('result=playing'));
    expect(line, contains('detail=100'));
    expect(line, contains('qualities=100'));
    expect(line, contains('lines=100'));
    expect(line, contains('request=100'));
    expect(line, contains('firstFrame=100'));
    expect(line, contains('playing=100'));
    // The chat runs beside the picture, so it is counted from T0.
    expect(line, contains('chat=700'));
    expect(line, contains('total=600'));
  });

  test('a stage the entry never reached says so instead of claiming zero', () {
    final timing = _timing(site: 'huya', roomId: '9')
      ..markDetail()
      ..markQualities();

    final line = timing.line();
    expect(line, contains('detail=100'));
    expect(line, contains('qualities=100'));
    expect(line, contains('lines=-'));
    expect(line, contains('firstFrame=-'));
    expect(line, contains('playing=-'));
    expect(line, contains('chat=-'));
    expect(line, contains('result=incomplete'));
  });

  test('a failed entry keeps the sentence out of the line', () {
    final timing = _timing(site: 'douyu', roomId: '7')..markDetail();

    // The platform's own diagnostic may carry an address or a cookie; the
    // timing line is a measurement, and the error is logged where it belongs.
    expect(timing.line(failed: true), contains('result=error'));
    expect(timing.line(failed: true), isNot(contains('http')));
  });

  test('a walk-away names itself, and a fast one is not one', () {
    final timing = _timing(site: 'douyu', roomId: '9')..markDetail();

    // The room never failed and never showed a picture: whoever left it did so
    // because of how long it took, and that has to be readable in the line.
    expect(timing.line(abandoned: true), contains('result=abandoned'));
    expect(timing.line(abandoned: true), isNot(contains('result=incomplete')));

    // The other half of the rule: a tap through a list is browsing, not a slow
    // room, and the budget is what keeps it out of the log. The clock here
    // moves 100 ms a reading, so no stage sequence reaches the budget.
    expect(kSlowEntryBudget, const Duration(seconds: 3));
    expect(timing.total < kSlowEntryBudget, isTrue);
  });

  test('the line names which way the requests left the machine', () {
    expect(_timing(site: 'youtube', roomId: '3').line(), contains('proxy=direct'));

    final throughProxy = RoomOpenTiming(site: 'youtube', roomId: '3', proxy: RoomOpenProxy.manual);
    expect(throughProxy.line(), contains('proxy=manual'));
  });

  test('only the first playing report counts, so the line is written once', () {
    final timing = _timing(site: 'bilibili', roomId: '1')..markDetail();

    expect(timing.markPlaying(), isTrue);
    expect(timing.markPlaying(), isFalse);
  });

  test('the log splits the CDN time from the decoder time', () {
    final timing = _timing(site: 'bilibili', roomId: '5')
      ..markDetail()
      ..markQualities()
      ..markLines()
      ..markRequested()
      ..markOpened()
      ..markFirstFrame()
      ..markPlaying();

    // `opened` is measured from the hand-off to the engine, so the wait for a
    // signed URL to answer is not charged to decoding.
    expect(timing.line(), contains('opened=100'));
    expect(timing.line(), contains('firstFrame=100'));
  });

  test('a stage marked twice keeps its first mark', () {
    final timing = _timing(site: 'bilibili', roomId: '1')
      ..markDetail()
      ..markDetail();

    // T0 to the first detail reading is one step, not two.
    expect(timing.line(), contains('detail=100'));
  });
}
