import 'dart:async' show unawaited;
import 'dart:ui' show clampDouble;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/settings/settings.dart' show kChatListFontSizeFixed;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/chat/chat_message_filter.dart' show isStandaloneBadgeEcho;
import 'package:pure_live/modules/live/room/chat/gift_text.dart' show giftSentenceText;
import 'package:pure_live/modules/live/room/chat/room_chat.dart' show chatSenderNameInk;
import 'package:pure_live/modules/live/room/chat/room_emotes.dart' show chatWordSpans;
import 'package:pure_live/modules/live/room/chat/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/modules/live/room/controller/room_controller.dart';
import 'package:pure_live/shared/player/on_video_colors.dart';

/// The immersive room's chat overlay (the reference's pill feed): the room's
/// talk as translucent pills anchored above the composer bar, newest at the
/// bottom, over the picture instead of in a column beside it.
///
/// The overlay is a glance surface, not the chat panel: it shows the same
/// lines the panel's danmaku tab shows (super chats keep their own tab, so a
/// paid board line never doubles here), each in its own pill, and never takes
/// the panel's place — the full panel with its tabs stays a drawer away.
///
/// Reading back is the same contract the column's list keeps, without the
/// memory the layout switch needs: scrolled away from the bottom, the overlay
/// holds the lines it showed so the feed's cap cannot pull the row under the
/// viewer's eye away, arrivals count into a jump pill, and returning to the
/// bottom resumes the chase. A room switch empties the list under it, and the
/// held lines of the room that is gone go with it.
final class RoomChatOverlay extends ConsumerStatefulWidget {
  /// The chat overlay.
  const RoomChatOverlay({super.key});

  @override
  ConsumerState<RoomChatOverlay> createState() => _RoomChatOverlayState();
}

final class _RoomChatOverlayState extends ConsumerState<RoomChatOverlay> {
  /// The chat list's controller, read once: [ref] is gone by the time the
  /// state is (Riverpod throws on a ref read after dispose).
  late final RoomChatController _chat = ref.read(roomChatProvider.notifier);

  /// The scroll, so the overlay knows when the viewer is reading away from
  /// the bottom.
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);

  /// Whether the overlay chases the newest pill. False while the viewer
  /// reads away from the bottom: the overlay then holds the lines it showed.
  bool _following = true;

  /// The lines shown while held, oldest first.
  List<LiveMessage> _shown = const [];

  /// The feed's count of added lines when [_shown] was last seen.
  int _seen = 0;

  /// The feed's count of removals already applied to [_shown].
  int _removals = 0;

  /// How many lines arrived while the viewer was away from the bottom. The
  /// jump pill carries the count and the press that takes them back.
  int _unseen = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(roomChatProvider, _onChat);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// The overlay moved: at the bottom it chases again, past the reading mark
  /// it holds what it showed.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset <= 2) {
      if (_following && _unseen == 0) return;
      setState(() {
        _following = true;
        _shown = const [];
        _unseen = 0;
      });
      return;
    }
    if (_following && _scroll.offset > 40) {
      _chat.flush();
      setState(() {
        _following = false;
        _shown = List.of(ref.read(roomChatProvider));
        _seen = _chat.added;
        _removals = _chat.removals;
      });
    }
  }

  /// The feed changed: a chasing overlay shows it as it is; a held one
  /// applies the removals and the combos' replacements to the lines it
  /// holds, and counts what arrived for the jump pill.
  void _onChat(List<LiveMessage>? previous, List<LiveMessage> next) {
    if (!mounted || _following) return;
    // The feed was emptied under the held lines (a new room opened): the
    // held lines are of a room that is gone, and the count with them.
    if (_chat.added < _seen) {
      setState(() {
        _following = true;
        _shown = const [];
        _seen = _chat.added;
        _removals = _chat.removals;
        _unseen = 0;
      });
      return;
    }
    var shown = _shown;
    if (_chat.removals != _removals) {
      final tests = _chat.removalsSince(_removals) ?? const [];
      _removals = _chat.removals;
      shown = [for (final line in shown) if (!tests.any((test) => test(line))) line];
    }
    shown = [for (final line in shown) _chat.replacementOf(line) ?? line];
    final arrivals = _chat.added - _seen;
    _seen = _chat.added;
    if (identical(shown, _shown) && arrivals == 0) return;
    setState(() {
      _shown = shown;
      if (arrivals > 0) _unseen += arrivals;
    });
  }

  /// The jump pill's press: back to the newest pill, dropping the held list.
  void _resume() {
    setState(() {
      _following = true;
      _shown = const [];
      _unseen = 0;
      _seen = _chat.added;
      _removals = _chat.removals;
    });
    void jump() {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    }

    jump();
    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(roomChatProvider);
    final standing = ref.watch(roomChatStandingProvider);
    final anchorName = ref.watch(roomAnchorNameProvider);
    // While the viewer reads away from the bottom, what they read is the held
    // list, not the feed's. Super chats live in their own tab; the overlay,
    // like the panel's own list, stays plain talk. The glance surface keeps
    // only the last pills — the feed holds the history, and a capped list is
    // what lets the scroll hug its content instead of reserving the cap's
    // height in invisible rows.
    final source = _following || _shown.isEmpty ? chat : _shown;
    final lines = [
      for (final message in source)
        if (message.type != LiveMessageType.superChat && !isStandaloneBadgeEcho(message)) message,
    ];
    final visible = lines.length > _visibleCap ? lines.sublist(lines.length - _visibleCap) : lines;
    // A fixed share of the window, with a floor and a ceiling: enough pills
    // to read a conversation's shape, never half the picture.
    final maxHeight = clampDouble(MediaQuery.sizeOf(context).height * 0.40, 160, 340);
    final content = switch (visible.length) {
      0 => switch (standing.status) {
        // A list that already holds talk never shows the socket's trouble,
        // so one quiet pill says which it is — with the retry when there is
        // one. Connected-and-quiet, or a room without chat, stays silent: an
        // empty glance surface is the honest answer there.
        RoomChatStatus.connecting => const _OverlayStatusPill(busy: true) as Widget,
        RoomChatStatus.failed => _OverlayStatusPill(
          busy: false,
          error: standing.error ?? '',
          onRetry: () => unawaited(ref.read(roomProvider.notifier).retryChat()),
        ),
        _ => const SizedBox.shrink(),
      },
      _ => Stack(
        children: [
          ShaderMask(
            // The pills fade out at their top instead of stopping at a hard
            // edge: the overlay has no frame of its own to end with.
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.18, 1],
              colors: [OnVideoColors.clear, OnVideoColors.foreground, OnVideoColors.foreground],
            ).createShader(bounds),
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s3),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final message = visible[visible.length - 1 - index];
                return _OverlayLine(message: message, anchorName: anchorName);
              },
            ),
          ),
          if (_unseen > 0)
            PositionedDirectional(
              bottom: DsSpace.s3,
              end: 0,
              child: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: _resume,
                child: Text(context.t.room.newMessagesCount(count: _unseen)),
              ),
            ),
        ],
      ),
    };
    // Bottom-anchored: a quiet room's pill and a full feed both stand where
    // the newest line belongs, and the picture above them stays clear.
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: maxHeight), child: content),
    );
  }

  /// The pills the glance surface keeps: past this, the oldest fall off the
  /// top (the feed's cap already bounds what exists at all).
  static const int _visibleCap = 30;
}

/// One pill of the overlay: the line's own words on a translucent dark
/// capsule, the sender's name before the words in the ink the column reads.
/// No blur — a pill per line would hang a score of BackdropFilters over the
/// picture; the fill alone reads as a pill on any frame.
final class _OverlayLine extends ConsumerWidget {
  const _OverlayLine({required this.message, required this.anchorName});

  final LiveMessage message;

  /// The room's streamer: a gift names its receiver only when it differs.
  final String anchorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final sender = message.sender;
    final senderName = sender?.userName.trim() ?? '';
    final fontPx = kChatListFontSizeFixed > 0 ? kChatListFontSizeFixed.toDouble() : 15.0;
    final lineStyle = theme.typography.caption.copyWith(
      fontSize: fontPx,
      height: 1.45,
      color: OnVideoColors.foreground,
    );
    final gift = message.type == LiveMessageType.gift && message.payload is LiveGift
        ? message.payload! as LiveGift
        : null;
    final words = gift == null ? message.text : giftSentenceText(t, gift, anchorName);
    // The room's own voice (its notices and system lines) and the door's
    // traffic (entering and leaving viewers) sit in quiet capsules of their
    // own: they are facts, not conversation, and centring them keeps the
    // talk's left edge readable as one stream.
    final quiet = gift == null && (message.type == LiveMessageType.notice || message.type == LiveMessageType.system);
    final door = gift == null && !quiet && sender == null;
    if (quiet || door) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.s3),
        child: Align(
          alignment: AlignmentDirectional.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: 2),
            decoration: BoxDecoration(color: OnVideoColors.panel, borderRadius: BorderRadius.circular(8)),
            child: Text(
              words,
              textAlign: TextAlign.center,
              style: lineStyle.copyWith(color: OnVideoColors.inkSubtle),
            ),
          ),
        ),
      );
    }
    final spans = <InlineSpan>[
      // A gift line leads with its words in the gift gold: the pill is the
      // mark, the ink says what kind of line it is.
      if (gift != null)
        ...chatWordSpans(
          words,
          lineStyle.copyWith(color: OnVideoColors.giftGold, fontWeight: FontWeight.w600),
          fontPx * 1.2,
          emotes: message.emotes.toList(growable: false),
        )
      else ...[
        if (senderName.isNotEmpty)
          TextSpan(
            text: '$senderName: ',
            style: lineStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: chatSenderNameInk(
                sender: sender,
                messageColor: message.color,
                background: OnVideoColors.ground,
                fallback: OnVideoColors.inkMuted,
              ),
            ),
          ),
        ...chatWordSpans(words, lineStyle, fontPx * 1.2, emotes: message.emotes.toList(growable: false)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s3),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              unawaited(showRoomMessageActions(context, ref, text: words, userName: senderName, isLocal: message.isLocal)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: 3),
            decoration: BoxDecoration(color: OnVideoColors.panel, borderRadius: BorderRadius.circular(8)),
            child: Text.rich(TextSpan(style: lineStyle, children: spans)),
          ),
        ),
      ),
    );
  }
}

/// The overlay's one-line word about the socket: connecting, or failed with
/// the retry. A pill like the talk's own, so the overlay's trouble never
/// reads as a panel.
final class _OverlayStatusPill extends StatelessWidget {
  const _OverlayStatusPill({required this.busy, this.error = '', this.onRetry});

  /// Whether the socket is still handshaking (a spinner) or has failed (a
  /// retry button).
  final bool busy;

  /// The platform's own reason, for a failure.
  final String error;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s3, DsSpace.s8, DsSpace.s3),
        decoration: BoxDecoration(color: OnVideoColors.panel, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s6,
          children: [
            if (busy)
              const DsSpinner(style: DsSpinnerStyle(size: 12))
            else
              const DsIcon(DsIcons.cloudOff, size: 12, color: OnVideoColors.inkSubtle),
            Flexible(
              child: Text(
                busy ? t.room.chatConnecting : t.room.danmakuConnectFailed(reason: error),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(fontSize: 12, color: OnVideoColors.inkMuted),
              ),
            ),
            if (!busy && onRetry != null)
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.xs,
                onPressed: onRetry,
                child: Text(t.common.retry),
              ),
          ],
        ),
      ),
    );
  }
}
