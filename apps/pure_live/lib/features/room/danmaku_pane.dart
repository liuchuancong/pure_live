import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/features/room/super_chat_card.dart';
import 'package:pure_live/features/room/widgets/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/features/shield/shield_lists.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/danmaku/danmaku_settings_content.dart';
import 'package:pure_uikit/pure_uikit.dart' hide InteractionState;

/// The room's interaction pane (the reference's `DanmakuTabView`): the live
/// danmaku list, the super-chat board, the barrage settings and the keyword
/// block — the reference's own four-tab set — over one [InteractionSession].
///
/// The session is owned by [danmakuSessionProvider] — the pane only renders
/// it. Chat keeps the newest line pinned to the bottom and pauses the follow
/// the moment the viewer scrolls up, with a "back to live" pill that counts
/// what arrived in the meantime. Gifts render inline in the chat feed, as the
/// reference does; the block tab edits the same rules the standalone shield
/// page hosts.
///
/// Sending is the reference's local interaction: what is typed is injected
/// into this room's own feed and the video barrage through
/// [roomLocalMessageBusProvider], and the composer only appears when the
/// setting is on. It is not a platform send — the reference never had one.
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
      // showing a connection failure. The composer still works — local
      // messages need no socket — but with nothing to answer them a phone's
      // sheet is better spent on the picture.
      AsyncData() => _EmptySupport(identity: identity, dark: dark),
      AsyncError() => PureError(
        message: context.t.room.danmakuFailed,
        retryLabel: context.t.common.retry,
        onRetry: () => ref.invalidate(danmakuSessionProvider(identity)),
      ),
      _ => const Center(child: PureSpinner(size: 28)),
    };
  }
}

/// The no-danmaku-support shape: the composer alone, when local interaction
/// is on, so the reference's "iptv shows nothing here" honesty is kept while
/// the feature the user did ask for still works.
final class _EmptySupport extends ConsumerStatefulWidget {
  const new({required this.identity, required this.dark});

  final RoomIdentity identity;
  final bool dark;

  @override
  ConsumerState<_EmptySupport> createState() => _EmptySupportState();
}

final class _EmptySupportState extends ConsumerState<_EmptySupport> {
  final TextEditingController _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(appPreferencesProvider).localInteractionEnabled) {
      return PureEmpty(
        title: context.t.room.danmakuFailed,
        message: context.t.errors.unsupported,
        icon: Icons.forum_outlined,
      );
    }
    return Column(
      children: [
        Expanded(
          child: Center(child: Text(context.t.errors.unsupported, style: PureTheme.of(context).text.caption)),
        ),
        _SendBar(identity: widget.identity, draft: _draft, dark: widget.dark),
      ],
    );
  }
}

/// One session's feeds and their shared tab strip.
final class _SessionPane extends ConsumerStatefulWidget {
  const new({required this.identity, required this.session, required this.dark});

  /// The room this pane renders; the bus and the block rules key off it.
  final RoomIdentity identity;

  final InteractionSession session;
  final bool dark;

  @override
  ConsumerState<_SessionPane> createState() => _SessionPaneState();
}

final class _SessionPaneState extends ConsumerState<_SessionPane> {
  /// How long message bursts are coalesced before a rebuild.
  static const _throttle = Duration(milliseconds: 60);

  /// The feed cap: the room's tail is what matters, and an unbounded
  /// list is one long-session memory leak.
  static const _chatCap = 200;
  static const _superChatCap = 50;

  StreamSubscription<LiveMessage>? _messages;
  StreamSubscription<LiveMessage>? _local;
  StreamSubscription<InteractionState>? _states;
  final ScrollController _chatScroll = ScrollController();
  final TextEditingController _draft = TextEditingController();

  final List<LiveMessage> _chats = [];
  final List<LiveSuperChatMessage> _superChats = [];

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
      _pinned = true;
      _pendingCount = 0;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _chatScroll.dispose();
    _draft.dispose();
    unawaited(_messages?.cancel());
    unawaited(_local?.cancel());
    unawaited(_states?.cancel());
    super.dispose();
  }

  void _subscribe() {
    unawaited(_messages?.cancel());
    unawaited(_local?.cancel());
    unawaited(_states?.cancel());
    _messages = widget.session.messages.listen(_onMessage, onError: (Object _) {});
    // The bus is the reference's local delivery queue: what the viewer types
    // lands in the same feed, marked local, and the barrage draws it too.
    _local = ref.read(roomLocalMessageBusProvider(widget.identity)).messages.listen(_onMessage);
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
    if (_chats.length > _chatCap) {
      _chats.removeRange(0, _chats.length - _chatCap);
    }
    if (_superChats.length > _superChatCap) {
      _superChats.removeRange(0, _superChats.length - _superChatCap);
    }
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final dark = widget.dark;
    // The reference gates the chat feed on the same answer the overlay uses:
    // a viewer who turned the barrage off globally gets the hint, not the
    // list — and the settings tab is where they turn it back.
    final hidden = !ref.watch(appPreferencesProvider).danmakuVisible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: PureTabs(
            tabs: [
              PureTab(label: t.room.chat),
              PureTab(label: t.room.superChat),
              PureTab(label: t.room.barrageSettings),
              PureTab(label: t.room.keywordBlock),
            ],
            index: _tab,
            // Four labels in a chat column that is narrower on a phone than
            // the text is wide: let the strip scroll rather than squeeze.
            isScrollable: true,
            onChanged: (index) => setState(() => _tab = index),
          ),
        ),
        if (_phase == InteractionPhase.reconnecting)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PureSpinner(size: 10),
                const SizedBox(width: 6),
                Text(
                  t.room.reconnecting,
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
                    t.room.danmakuEnded,
                    style: PureTheme.of(context).text.caption
                        .copyWith(color: dark ? Colors.white54 : PureTheme.of(context).colors.textSecondary),
                  ),
                ),
                PureIconButton(
                  icon: Icons.refresh,
                  tooltip: t.common.retry,
                  onPressed: () => ref.invalidate(danmakuSessionProvider(widget.identity)),
                ),
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              if (hidden) _hiddenHint(context, dark) else _chatTab(context, dark),
              _superChatTab(context, dark),
              _settingsTab(context),
              const ShieldListsPanel(),
            ],
          ),
        ),
        if (ref.watch(appPreferencesProvider).localInteractionEnabled)
          _SendBar(identity: widget.identity, draft: _draft, dark: dark),
      ],
    );
  }

  /// The reference's `danmaku_display_disabled_hint` shape: the reason, and
  /// the way back to the tab that flips it.
  Widget _hiddenHint(BuildContext context, bool dark) {
    final theme = PureTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t.room.barrageHiddenHint, textAlign: TextAlign.center, style: theme.text.caption),
            const SizedBox(height: 10),
            PureButton(
              label: context.t.room.barrageOn,
              icon: Icons.comment_outlined,
              size: ControlSize.sm,
              variant: ButtonVariant.secondary,
              onPressed: () => unawaited(
                ref
                    .read(appPreferencesProvider.notifier)
                    .update((preferences) => preferences.copyWith(danmakuVisible: true)),
              ),
            ),
          ],
        ),
      ),
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
    // The list's look answers to the shared barrage settings: size, spacing,
    // plain rows or cards, and whether the sender's name leads the line.
    final listPrefs = ref.watch(appPreferencesProvider);
    final cardStyle = listPrefs.barrageListStyle == 'card';
    final family = listPrefs.barrageFontFamily.trim();
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: (listPrefs.barrageListLineSpacing / 2).clamp(1, 14)),
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
                  if (sender.userName.isNotEmpty && listPrefs.barrageShowSender)
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
              style: TextStyle(
                fontSize: listPrefs.barrageListFontSize,
                fontFamily: family.isEmpty ? null : family,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
    if (!cardStyle) {
      // U.2k c10: the line keeps its long press — the same message actions
      // the line on the picture opens.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => unawaited(showRoomMessageActions(context, message, identity: widget.identity)),
        child: row,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => unawaited(showRoomMessageActions(context, message, identity: widget.identity)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.06) : PureTheme.of(context).colors.fillSecondary,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: row,
        ),
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

  /// The barrage answers the overlay and the list draw with, edited where
  /// they are read — the reference's third tab: the shared
  /// `DanmakuSettingsContent` with the room's visibility switch on top, and
  /// the "改动立即生效" note beside the first group.
  Widget _settingsTab(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PureCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.room.barrageOn, style: theme.text.title),
                    Text(
                      t.room.barrageOnSubtitle,
                      style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              PureSwitch(
                value: preferences.danmakuVisible,
                onChanged: (value) => unawaited(update((p) => p.copyWith(danmakuVisible: value))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        DanmakuSettingsContent(preferences: preferences, update: update, hint: t.danmaku.liveHint),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            t.room.barrageSettingsNote,
            style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
          ),
        ),
      ],
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

/// The composer, the reference's local-message input: what is typed goes onto
/// the room's bus, lands in the chat feed and crosses the barrage. It is
/// visible only while the local-interaction setting is on — the reference
/// ships the same gate, and this build has no platform send channel to fake.
final class _SendBar extends ConsumerStatefulWidget {
  const new({required this.identity, required this.draft, required this.dark});

  final RoomIdentity identity;

  /// Shared with the pane so a tab rebuild never drops a half-typed line.
  final TextEditingController draft;
  final bool dark;

  @override
  ConsumerState<_SendBar> createState() => _SendBarState();
}

final class _SendBarState extends ConsumerState<_SendBar> {
  void _send() {
    final text = widget.draft.text;
    if (text.trim().isEmpty) {
      return;
    }
    final preferences = ref.read(appPreferencesProvider);
    final name = preferences.localInteractionUserName.trim().isEmpty
        ? context.t.room.localMe
        : preferences.localInteractionUserName.trim();
    ref
        .read(roomLocalMessageBusProvider(widget.identity))
        .sendChat(text: text, userName: name, colorArgb: preferences.localInteractionColor);
    widget.draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: PureTextField(
              controller: widget.draft,
              textInputAction: TextInputAction.send,
              placeholder: context.t.room.sendPlaceholder,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          PureIconButton(icon: Icons.send_rounded, tooltip: context.t.room.send, onPressed: _send),
        ],
      ),
    );
  }
}
