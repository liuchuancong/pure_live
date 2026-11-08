import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/live/room/chat/room_emotes.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/shared/player/on_video_colors.dart';

/// The width the over-picture chat stream takes from a surface of [width]:
/// a third of it, never under a readable column and never over a third of a
/// wide frame; a phone keeps a narrower share so the picture stays the subject.
double chatStreamWidth(double width) => math.min(width * 0.6, (width * 0.32).clamp(160.0, 380.0));

/// The reference layout's chat: plain talk floating over the picture itself,
/// no bubble, no glass, no panel — white ink with a shadow so it reads on any
/// frame, newest line at the column's foot, the oldest pushed out when the
/// corner's room runs out.
///
/// The stream is a glance, not a console: it never takes the pointer (the
/// picture's tap, drag and wheel pass straight through), carries only the
/// conversation and paid messages — gifts, notices and the badge track stay
/// in the full column — and yields whenever the stats panel or the full
/// column opens. Its lines reuse the column's own emoticon spans and the
/// viewer's name/size choices, so one message reads the same in both.
final class RoomChatStream extends ConsumerStatefulWidget {
  /// The stream; the host drops it over the picture as a filled layer.
  const RoomChatStream({
    this.topInset = 52,
    this.bottomInset = 56,
    this.startInset = DsSpace.s12,
    this.endInset = DsSpace.s12,
    super.key,
  });

  /// The room kept above the top strip: 8 of padding, the 32 px control and
  /// 12 below it — the same derivation the stats panel stands on.
  final double topInset;

  /// The room kept under the bottom bar (8 + 32 + 8) plus its wake strip.
  final double bottomInset;

  /// The side the stream's start edge keeps from the picture.
  final double startInset;

  /// The side the stream's end edge keeps; the immersive drawer's tab lives
  /// on the end edge, so that layout hands a wider inset.
  final double endInset;

  @override
  ConsumerState<RoomChatStream> createState() => _RoomChatStreamState();
}

final class _RoomChatStreamState extends ConsumerState<RoomChatStream> {
  /// The conversation as the feed last told it, oldest first.
  List<LiveMessage> _feed = const [];

  /// The lines the corner currently shows, oldest first.
  List<LiveMessage> _shown = const [];

  /// Lines the window just pushed out, fading where they stood.
  List<LiveMessage> _leaving = const [];

  Timer? _leaveTimer;
  bool _syncScheduled = false;
  late final ProviderSubscription<List<LiveMessage>> _subscription;

  @override
  void initState() {
    super.initState();
    _feed = _conversation(ref.read(roomChatProvider));
    // One listener, one rebuild of this layer per frame at most: the page
    // above never hears of a line.
    _subscription = ref.listenManual(roomChatProvider, (previous, next) {
      if (!mounted) return;
      setState(() => _feed = _conversation(next));
    });
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    _subscription.close();
    super.dispose();
  }

  /// What the stream carries: live talk and paid messages with words. Gifts,
  /// notices, entrances and replays are the column's business, not a glance's.
  static List<LiveMessage> _conversation(List<LiveMessage> lines) => [
    for (final line in lines)
      if ((line.type == LiveMessageType.chat || line.type == LiveMessageType.superChat) &&
          !line.replayed &&
          line.text.trim().isNotEmpty)
        line,
  ];

  static bool _sameWindow(List<LiveMessage> a, List<LiveMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// The window the corner can hold: each line may wrap to two, so a slot is
  /// two lines tall plus the gap; the count follows the room's own height.
  void _syncWindow(List<LiveMessage> target) {
    if (_syncScheduled || _sameWindow(_shown, target)) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || _sameWindow(_shown, target)) return;
      final kept = Set<LiveMessage>.identity()..addAll(target);
      final removed = [
        for (final line in _shown)
          if (!kept.contains(line)) line,
      ];
      setState(() {
        _shown = target;
        _leaving = removed;
      });
      _leaveTimer?.cancel();
      if (removed.isNotEmpty) {
        _leaveTimer = Timer(const Duration(milliseconds: 220), () {
          if (mounted) setState(() => _leaving = const []);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final corner = ref.watch(chatStreamCornerProvider);
    final showNames = ref.watch(chatNamesProvider);
    final fontSize = ref.watch(chatListFontSizeProvider);
    // Over the picture the follow-theme pick lands on the flying layer's own
    // default: 18 reads at a glance where the panel's 13 does not.
    final fontPx = fontSize > 0 ? fontSize.toDouble() : 18.0;
    final right = corner == ChatStreamCorner.topRight || corner == ChatStreamCorner.bottomRight;
    final top = corner == ChatStreamCorner.topRight || corner == ChatStreamCorner.topLeft;
    final alignment = switch (corner) {
      ChatStreamCorner.topRight => AlignmentDirectional.topEnd,
      ChatStreamCorner.bottomRight => AlignmentDirectional.bottomEnd,
      ChatStreamCorner.topLeft => AlignmentDirectional.topStart,
      ChatStreamCorner.bottomLeft => AlignmentDirectional.bottomStart,
    };
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = chatStreamWidth(constraints.maxWidth);
          final available = math.max(0, constraints.maxHeight - widget.topInset - widget.bottomInset);
          // Half the free picture at most: the reference keeps its talk to a
          // corner, the frame stays the subject.
          final room = available * 0.5;
          final capacity = math.max(1, (room / (fontPx * 3 + 4)).floor());
          if (width <= 0 || available <= 0) return const SizedBox.shrink();
          final target = _feed.length <= capacity ? _feed : _feed.sublist(_feed.length - capacity);
          _syncWindow(target);
          final style = TextStyle(
            fontSize: fontPx,
            height: 1.5,
            color: OnVideoColors.foreground,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(1, 1))],
          );
          final nameStyle = style.copyWith(color: OnVideoColors.inkMuted, fontWeight: FontWeight.w600);
          return Padding(
            padding: EdgeInsetsDirectional.only(
              top: widget.topInset,
              bottom: widget.bottomInset,
              start: widget.startInset,
              end: widget.endInset,
            ),
            child: Align(
              alignment: alignment,
              child: SizedBox(
                width: width,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      for (final line in _leaving)
                        _LeavingLine(
                          key: ObjectKey(line),
                          child: _lineText(line, style, nameStyle, showNames, right, fontPx),
                        ),
                      for (final line in _shown)
                        _StreamLine(
                          key: ObjectKey(line),
                          child: _lineText(line, style, nameStyle, showNames, right, fontPx),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _lineText(LiveMessage line, TextStyle style, TextStyle nameStyle, bool showNames, bool right, double fontPx) {
    final name = (line.sender?.userName ?? '').trim();
    return Text.rich(
      TextSpan(
        children: [
          if (showNames && name.isNotEmpty) TextSpan(text: '$name: ', style: nameStyle),
          ...chatWordSpans(line.text, style, fontPx * 1.2, emotes: line.emotes.toList(growable: false)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: right ? TextAlign.right : TextAlign.left,
    );
  }
}

/// One arriving line: a short fade and rise, once — the key is the message
/// itself, so a rebuild of the column never replays a line already read.
final class _StreamLine extends StatefulWidget {
  const _StreamLine({required this.child, super.key});

  final Widget child;

  @override
  State<_StreamLine> createState() => _StreamLineState();
}

final class _StreamLineState extends State<_StreamLine> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 160))
    ..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _enter,
    builder: (context, child) => Opacity(
      opacity: _enter.value,
      child: Transform.translate(offset: Offset(0, 6 * (1 - _enter.value)), child: child),
    ),
    child: widget.child,
  );
}

/// One pushed-out line: it fades where it stood while the column's height
/// settles, then the stream lets it go.
final class _LeavingLine extends StatefulWidget {
  const _LeavingLine({required this.child, super.key});

  final Widget child;

  @override
  State<_LeavingLine> createState() => _LeavingLineState();
}

final class _LeavingLineState extends State<_LeavingLine> with SingleTickerProviderStateMixin {
  late final AnimationController _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
    ..forward();

  @override
  void dispose() {
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _leave,
    builder: (context, child) => Opacity(opacity: 1 - _leave.value, child: child),
    child: widget.child,
  );
}
