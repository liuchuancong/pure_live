/// How long one entry into a room took, stage by stage.
///
/// "The room opens slowly" is four different faults wearing one coat: the
/// detail request, the quality list, the line list, and the engine's own road
/// to a first frame. Each has its own fix — a shorter budget, a cached answer,
/// another line — and none of them can be chosen without the numbers.
///
/// The marks follow the reference's `StartupMarks` and `PlaybackTiming`
/// (`live_player/lib/src/timing.dart`): a stage is marked once and the first
/// call wins, every segment runs from the last mark reached before it, and an
/// entry the viewer left before its picture arrived reports nothing — the
/// timing of an abandoned open would blame a stage that was never waiting for
/// anyone. The line names no address and no header.
final class RoomOpenTiming {
  /// Starts the clock for an entry into [roomId] on [site]; [now] is the time
  /// source, replaced only by a test that wants fixed numbers.
  RoomOpenTiming({required this.site, required this.roomId, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      // T0 is taken here rather than on first read: a lazily started clock
      // would begin at the first mark and report an entry as instant.
      started = (now ?? DateTime.now)();

  /// The platform id.
  final String site;

  /// The room's own id, enough to group the lines of one room together.
  final String roomId;

  final DateTime Function() _now;

  /// T0: the room was entered.
  final DateTime started;

  DateTime? _detail;
  DateTime? _qualities;
  DateTime? _lines;
  DateTime? _requested;
  DateTime? _firstFrame;
  DateTime? _playing;
  DateTime? _chat;

  /// T1: the room detail came back.
  void markDetail() => _detail ??= _now();

  /// T2: the quality list came back.
  void markQualities() => _qualities ??= _now();

  /// T3: the play lines came back.
  void markLines() => _lines ??= _now();

  /// T4: the source reached the engine (`play` returned).
  void markRequested() => _requested ??= _now();

  /// T5: the engine reported a picture with a size in it.
  void markFirstFrame() => _firstFrame ??= _now();

  /// T6: the room says it is playing. Returns whether this was the first
  /// playing report of the entry, so the caller can hand the line over once.
  bool markPlaying() {
    if (_playing != null) return false;
    _playing = _now();
    return true;
  }

  /// When the chat's own handshake got in, from T0. It runs beside the
  /// picture, so it is not a segment of the road to the first frame — but it
  /// is the stage a viewer most often mistakes for one.
  void markChat() => _chat ??= _now();

  /// The fixed-field log line, [failed] when the entry ended in an error
  /// rather than a picture.
  String line({bool failed = false}) {
    final end = _playing ?? _firstFrame ?? _requested ?? _lines ?? _qualities ?? _detail ?? started;
    return [
      'room-open',
      'site=$site',
      'room=$roomId',
      'result=${failed
          ? 'error'
          : _playing != null
          ? 'playing'
          : 'incomplete'}',
      _field('detail', _detail),
      _field('qualities', _qualities),
      _field('lines', _lines),
      _field('request', _requested),
      _field('firstFrame', _firstFrame),
      _field('playing', _playing),
      'chat=${_chat == null ? '-' : _chat!.difference(started).inMilliseconds}',
      'total=${end.difference(started).inMilliseconds}',
    ].join(' ');
  }

  /// Every mark, so a segment can start at the last one before it.
  List<DateTime?> get _marks => [_detail, _qualities, _lines, _requested, _firstFrame, _playing];

  String _field(String name, DateTime? at) {
    if (at == null) return '$name=-';
    var from = started;
    for (final mark in _marks) {
      if (mark == null || mark == at) continue;
      if (mark.isBefore(at) && mark.isAfter(from)) from = mark;
    }
    return '$name=${at.difference(from).inMilliseconds}';
  }
}
