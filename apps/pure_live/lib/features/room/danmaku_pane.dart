import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/routing/routes/settings/shield_routes.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/features/room/super_chat_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart' hide InteractionState;

/// The room's interaction pane (the reference's `DanmakuTabView`): the live
/// danmaku list, the super-chat board and the gift feed as tabs over one
/// [InteractionSession], plus the way into the danmaku shield.
///
/// The session is owned by [danmakuSessionProvider] — the pane only renders
/// it. Chat keeps the newest line pinned to the bottom and pauses the follow
/// the moment the viewer scrolls up, with a "back to live" pill that counts
/// what arrived in the meantime.
///
/// Degraded on purpose:
/// - **Sending** renders unavailable. The app has no platform login /
///   credential layer yet (the reference's cookie settings and per-site send
///   channels have no workspace counterpart), so there is nothing real to
///   send with; faking a send would violate the no-mock rule.
/// - **Gifts** lists what the room *received* (the `LiveGift` payloads of the
///   stream). The reference's local gift centre is a coins simulation, not a
///   platform capability, so it is not carried over.
final class DanmakuPane extends ConsumerWidget {
  /// A pane for the room [identity]; [dark] dresses the pane for the black
  /// sidebar next to the video instead of a light sheet surface.
  const new({required this.identity, this.dark = true, super.key});

  /// The room the pane connects to.
  final RoomIdentity identity;

  /// Whether the pane sits on a dark surface.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(danmakuSessionProvider(identity));
    return switch (session) {
      AsyncData(:final value) when value != null => _SessionPane(identity: identity, session: value, dark: dark),
      // The site exposes no danmaku capability: degrade honestly instead of
      // showing a connection failure.
      AsyncData() => PureEmpty(
        title: context.t.room.danmakuFailed,
        message: context.t.errors.unsupported,
        icon: Icons.forum_outlined,
      ),
      AsyncError() => PureError(
        message: context.t.room.danmakuFailed,
        retryLabel: context.t.common.retry,
        onRetry: () => ref.invalidate(danmakuSessionProvider(identity)),
      ),
      _ => const Center(child: PureSpinner(size: 28)),
    };
  }
}

/// One session's three feeds and their shared tab strip.
final class _SessionPane extends ConsumerStatefulWidget {
  const new({required this.identity, required this.session, required this.dark});

  /// The room this pane renders; the shield entry needs it to re-open the
  /// session's provider.
  final RoomIdentity identity;

  final InteractionSession session;
  final bool dark;

  @override
  ConsumerState<_SessionPane> createState() => _SessionPaneState();
}

final class _SessionPaneState extends ConsumerState<_SessionPane> {
  /// How long message bursts are coalesced before a rebuild.
  static const _throttle = Duration(milliseconds: 60);

  /// The per-feed caps: the room's tail is what matters, and an unbounded
  /// list is one long-session memory leak.
  static const _chatCap = 200;
  static const _superChatCap = 50;
  static const _giftCap = 60;

  StreamSubscription<LiveMessage>? _messages;
  StreamSubscription<InteractionState>? _states;
  final ScrollController _chatScroll = ScrollController();

  final List<LiveMessage> _chats = [];
  final List<LiveSuperChatMessage> _superChats = [];
  final List<LiveGift> _gifts = [];

  InteractionPhase _phase = InteractionPhase.idle;
  int _tab = 0;
  bool _pinned = true;
  int _pendingCount = 0;
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _SessionPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      // A new session (shield rules changed, a retry) starts with clean
      // feeds: replaying the old tail would blur what is happening now.
      _chats.clear();
      _superChats.clear();
      _gifts.clear();
      _pinned = true;
      _pendingCount = 0;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _chatScroll.dispose();
    unawaited(_messages?.cancel());
    unawaited(_states?.cancel());
    super.dispose();
  }

  void _subscribe() {
    unawaited(_messages?.cancel());
    unawaited(_states?.cancel());
    _messages = widget.session.messages.listen(_onMessage, onError: (Object _) {});
    _states = widget.session.states.listen((state) {
      if (mounted) {
        setState(() => _phase = state.phase);
      }
    });
    _phase = widget.session.state.phase;
  }

  void _onMessage(LiveMessage message) {
    switch (message.type) {
      case LiveMessageType.chat:
        _chats.add(message);
        _markArrival();
      case LiveMessageType.gift:
        _chats.add(message);
        final gift = message.giftOrNull;
        if (gift is LiveGift) {
          _gifts.add(gift);
        }
        _markArrival();
      case LiveMessageType.superChat:
        final payload = message.payload;
        if (payload is LiveSuperChatMessage) {
          _superChats.add(payload);
        }
        _markArrival();
      case LiveMessageType.audienceUpdate:
        // The session's own tracker consumes these; nothing to render.
        break;
      case LiveMessageType.retraction:
        break;
      // Notices, entries, leaves, likes, membership joins and system
      // broadcasts render as dim lines in the chat feed.
      case LiveMessageType.notice ||
          LiveMessageType.enter ||
          LiveMessageType.leave ||
          LiveMessageType.follow ||
          LiveMessageType.like ||
          LiveMessageType.membershipJoin ||
          LiveMessageType.system:
        if (message.text.isNotEmpty) {
          _chats.add(message);
          _markArrival();
        }
    }
    _trim();
  }

  void _markArrival() {
    if (!_pinned) {
      _pendingCount++;
    }
    _throttleTimer ??= Timer(_throttle, () {
      _throttleTimer = null;
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _trim() {
    if (_chats.length > _chatCap) {
      _chats.removeRange(0, _chats.length - _chatCap);
    }
    if (_superChats.length > _superChatCap) {
      _superChats.removeRange(0, _superChats.length - _superChatCap);
    }
    if (_gifts.length > _giftCap) {
      _gifts.removeRange(0, _gifts.length - _giftCap);
    }
  }

  void _backToLive() {
    // The reverse list follows the tail by itself while pinned; resuming
    // only has to walk back to the live edge.
    if (_chatScroll.hasClients) {
      _chatScroll.jumpTo(0);
    }
    setState(() {
      _pinned = true;
      _pendingCount = 0;
    });
  }

  /// Opens the shield page; the rules it changes only reach a running
  /// session through a fresh one, so the provider is invalidated on return.
  Future<void> _openShield() async {
    await const ShieldRoute().push<void>(context);
    if (mounted) {
      ref.invalidate(danmakuSessionProvider(widget.identity));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: PureTabs(
                  tabs: [
                    PureTab(label: context.t.room.chat),
                    PureTab(label: context.t.room.superChat),
                    PureTab(label: context.t.room.gifts),
                  ],
                  index: _tab,
                  onChanged: (index) => setState(() => _tab = index),
                ),
              ),
              PureIconButton(
                icon: Icons.block_outlined,
                tooltip: context.t.room.shield,
                onPressed: () => unawaited(_openShield()),
              ),
            ],
          ),
        ),
        if (_phase == InteractionPhase.reconnecting)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.6)),
                const SizedBox(width: 6),
                Text(
                  context.t.room.reconnecting,
                  style: PureTheme.of(context).text.caption
                      .copyWith(color: dark ? Colors.white54 : PureTheme.of(context).colors.textSecondary),
                ),
              ],
            ),
          ),
        if (_phase == InteractionPhase.ended)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t.room.danmakuEnded,
                    style: PureTheme.of(context).text.caption
                        .copyWith(color: dark ? Colors.white54 : PureTheme.of(context).colors.textSecondary),
                  ),
                ),
                PureIconButton(
                  icon: Icons.refresh,
                  tooltip: context.t.common.retry,
                  onPressed: () => ref.invalidate(danmakuSessionProvider(widget.identity)),
                ),
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [_chatTab(context, dark), _superChatTab(context, dark), _giftTab(context, dark)],
          ),
        ),
        _sendBar(context, dark),
      ],
    );
  }

  Widget _chatTab(BuildContext context, bool dark) {
    if (_chats.isEmpty) {
      return Center(
        child: Text(
          context.t.common.empty,
          style: PureTheme.of(context).text.caption
              .copyWith(color: dark ? Colors.white38 : PureTheme.of(context).colors.textSecondary),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // A real drag (or wheel tick with drag details) un-pins the live
        // tail; the pill is the only way back, so a stalled scroll never
        // fights the arriving messages.
        final dragged = switch (notification) {
          ScrollStartNotification(:final dragDetails) => dragDetails != null,
          ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
          _ => false,
        };
        if (dragged && _pinned && mounted) {
          setState(() => _pinned = false);
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: _chatScroll,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: _chats.length,
            itemBuilder: (context, index) => _row(context, _chats[_chats.length - 1 - index], dark),
          ),
          if (!_pinned)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Align(
                alignment: Alignment.centerRight,
                child: PureButton(
                  label: _pendingCount > 0
                      ? context.t.room.newMessages(count: '$_pendingCount')
                      : context.t.room.backToLive,
                  icon: Icons.arrow_downward_rounded,
                  size: ControlSize.sm,
                  onPressed: _backToLive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, LiveMessage message, bool dark) {
    if (message.type != LiveMessageType.chat && message.type != LiveMessageType.gift) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: PureTheme.of(context).text.caption
              .copyWith(color: dark ? Colors.white38 : PureTheme.of(context).colors.textSecondary),
        ),
      );
    }
    final sender = message.effectiveSender;
    final gift = switch (message.giftOrNull) {
      final LiveGift value => value,
      _ => null,
    };
    final giftNote = gift == null ? '' : (gift.count > 1 ? ' ×${gift.count}' : '');
    final accent = gift != null ? const Color(0xFFFFC107) : _readable(message.effectiveColor, dark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sender.avatarUrl != null && sender.avatarUrl!.isNotEmpty) ...[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: sender.avatarUrl!,
                width: 16,
                height: 16,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (sender.fanBadgeName.isNotEmpty)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          sender.fanBadgeLevel.isEmpty
                              ? sender.fanBadgeName
                              : '${sender.fanBadgeName} ${sender.fanBadgeLevel}',
                          style: TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w600, color: accent),
                        ),
                      ),
                    ),
                  if (sender.userName.isNotEmpty)
                    TextSpan(
                      text: '${sender.userName}: ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                    ),
                  TextSpan(
                    text: '${message.text}$giftNote',
                    style: TextStyle(
                      color: dark
                          ? (gift != null ? Colors.white : Colors.white.withValues(alpha: 0.88))
                          : PureTheme.of(context).colors.text,
                      fontWeight: gift != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _superChatTab(BuildContext context, bool dark) {
    if (_superChats.isEmpty) {
      return PureEmpty(
        title: context.t.room.superChatEmpty,
        message: context.t.room.superChatEmptyHint,
        icon: Icons.volunteer_activism_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _superChats.length,
      itemBuilder: (context, index) => SuperChatCard(message: _superChats[_superChats.length - 1 - index]),
    );
  }

  Widget _giftTab(BuildContext context, bool dark) {
    if (_gifts.isEmpty) {
      return PureEmpty(
        title: context.t.room.giftsEmpty,
        message: context.t.room.giftsEmptyHint,
        icon: Icons.card_giftcard_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[_gifts.length - 1 - index];
        final price = gift.value.unitPrice;
        final priced = price != null && gift.value.unit != LiveGiftUnit.free && gift.value.unit != LiveGiftUnit.silver;
        return PureListRow(
          divided: false,
          leading: gift.iconUrl == null || gift.iconUrl!.isEmpty
              ? const Icon(Icons.card_giftcard_outlined)
              : CachedNetworkImage(
                  imageUrl: gift.iconUrl!,
                  width: 32,
                  height: 32,
                  errorWidget: (_, _, _) => const Icon(Icons.card_giftcard_outlined),
                ),
          title: gift.count > 1 ? '${gift.name} ×${gift.count}' : gift.name,
          subtitle: priced ? '￥$price' : null,
        );
      },
    );
  }

  /// The composer, degraded to unavailable: this app has no platform login /
  /// credential layer yet, so there is no account to speak with — the field
  /// and the send action stay disabled rather than pretending.
  Widget _sendBar(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: PureTextField(
              enabled: false,
              readOnly: true,
              textInputAction: TextInputAction.send,
              placeholder: context.t.room.sendUnavailable,
            ),
          ),
          const SizedBox(width: 8),
          // Disabled on purpose: sending is unavailable until the app grows
          // a platform login layer (see the class doc).
          PureIconButton(icon: Icons.send_rounded, tooltip: context.t.room.sendUnavailable),
        ],
      ),
    );
  }

  /// The platform colour a message carries, lifted into a range that reads on
  /// the pane's surface (the reference's vibrant-colour treatment).
  Color _readable(LiveMessageColor color, bool dark) {
    final base = Color.fromARGB(255, color.r, color.g, color.b);
    final isWhite = base.r == 1 && base.g == 1 && base.b == 1;
    final isBlack = base.r == 0 && base.g == 0 && base.b == 0;
    if (isWhite || isBlack) {
      return dark ? Colors.white : const Color(0xFF1D1D1F);
    }
    final hsl = HSLColor.fromColor(base);
    final lightness = dark ? hsl.lightness.clamp(0.62, 0.86) : hsl.lightness.clamp(0.28, 0.55);
    return hsl.withLightness(lightness).toColor();
  }
}
