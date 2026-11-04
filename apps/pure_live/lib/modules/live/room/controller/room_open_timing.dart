/// How the entry's requests left the machine.
///
/// A room that takes ten seconds on a platform whose edge is unreachable
/// without a proxy is not a slow adapter, and a room that is slow *through*
/// a proxy is not a slow site either; the two look identical in the stage
/// numbers unless the line says which way the traffic went.
enum RoomOpenProxy {
  /// Straight to the platform.
  direct('direct'),

  /// The operating system's own configured proxy.
  system('system'),

  /// The endpoint on the network page.
  manual('manual');

  RoomOpenProxy(this.token);

  /// The word in the log line.
  final String token;
}

/// One stage of a room entry: the segment's name — a key a page translates —
/// and how long it took, null when the entry never reached it.
typedef RoomOpenStage = ({String name, Duration? took});

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
/// anyone. Neither the log line nor the page names an address or a header.
final class RoomOpenTiming {
  /// Starts the clock for an entry into [roomId] on [site]; [now] is the time
  /// source, replaced only by a test that wants fixed numbers.
  RoomOpenTiming({
    required this.site,
    required this.roomId,
    this.proxy = RoomOpenProxy.direct,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       // T0 is taken here rather than on first read: a lazily started clock
       // would begin at the first mark and report an entry as instant.
       started = (now ?? DateTime.now)();

  /// The platform id.
  final String site;

  /// The room's own id, enough to group the lines of one room together.
  final String roomId;

  /// Which way the entry's requests left the machine.
  final RoomOpenProxy proxy;

  final DateTime Function() _now;

  /// T0: the room was entered.
  final DateTime started;

  DateTime? _detail;
  DateTime? _qualities;
  DateTime? _lines;
  DateTime? _requested;
  DateTime? _opened;
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

  /// T4b: the engine says it holds an opened input.
  ///
  /// This one is in the log and not on the panel, because the two numbers it
  /// separates are different faults: time between the ask and this mark is the
  /// CDN, the DNS and the probe, and time between it and the first frame is
  /// decoding. A viewer reading the panel does not need that split, the next
  /// fix does.
  void markOpened() => _opened ??= _now();

  /// T5: the engine reported a picture with a size in it.
  void markFirstFrame() => _firstFrame ??= _now();

  /// T6: the room says it is playing. Returns whether this was the first
  /// playing report of the entry, so the caller hands its numbers over once.
  bool markPlaying() {
    if (_playing != null) return false;
    _playing = _now();
    return true;
  }

  /// When the chat's own handshake got in, from T0. It runs beside the
  /// picture, so it is not a step on the road to the first frame — but it is
  /// the stage a viewer most often mistakes for one.
  void markChat() => _chat ??= _now();

  /// The stages in the order the entry walks them. `chat` counts from T0
  /// rather than from the stage before it, because it never waits on those.
  List<RoomOpenStage> get stages => [
    (name: 'detail', took: _took(_detail)),
    (name: 'qualities', took: _took(_qualities)),
    (name: 'lines', took: _took(_lines)),
    (name: 'request', took: _took(_requested)),
    (name: 'firstFrame', took: _took(_firstFrame)),
    (name: 'playing', took: _took(_playing)),
    (name: 'chat', took: _chat?.difference(started)),
  ];

  /// T0 to wherever the entry ended.
  Duration get total =>
      (_playing ?? _firstFrame ?? _requested ?? _lines ?? _qualities ?? _detail ?? started).difference(started);

  /// The fixed-field log line, [failed] when the entry ended in an error
  /// rather than a picture.
  String line({bool failed = false}) => [
    'room-open',
    'site=$site',
    'room=$roomId',
    'proxy=${proxy.token}',
    'result=${failed
        ? 'error'
        : _playing != null
        ? 'playing'
        : 'incomplete'}',
    for (final stage in stages) '${stage.name}=${stage.took?.inMilliseconds ?? '-'}',
    'opened=${_opened == null || _requested == null ? '-' : _opened!.difference(_requested!).inMilliseconds}',
    'total=${total.inMilliseconds}',
  ].join(' ');

  /// Every mark, so a stage can start at the last one reached before it.
  /// `opened` counts even though it is not its own stage on the panel: the
  /// first frame should be measured from the engine holding the input, not
  /// from the moment the ask was made.
  List<DateTime?> get _marks => [_detail, _qualities, _lines, _requested, _opened, _firstFrame, _playing];

  Duration? _took(DateTime? at) {
    if (at == null) return null;
    var from = started;
    for (final mark in _marks) {
      if (mark == null || mark == at) continue;
      if (mark.isBefore(at) && mark.isAfter(from)) from = mark;
    }
    return at.difference(from);
  }
}
