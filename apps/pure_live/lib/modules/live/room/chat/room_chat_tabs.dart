part of 'room_chat.dart';

/// The room's standing word about its own chat login, above the list it
/// concerns.
///
/// A toast is the wrong shape for this: the viewer is looking at the picture
/// when the room notices that every name arrives masked, and the fix is a
/// minute at the sign-in page, not a glance. The bar stays until the next
/// connection stops looking like a dead login, or until they say they have
/// seen it.
final class _ChatNoticeBar extends ConsumerWidget {
  const _ChatNoticeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(roomChatNoticeProvider);
    if (notice == null) return const SizedBox.shrink();
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s12, 0),
      child: DsAlert(
        status: DsStatus.warning,
        announce: true,
        title: Text(notice.text),
        action: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.xs,
              onPressed: () => unawaited(
                showAccountSignInAlternative(context, siteId: notice.siteId, exit: AccountQrExit.cookiePage),
              ),
              child: Text(t.account.cookieLogin),
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.xs,
              icon: const DsIcon(DsIcons.close, size: 14),
              semanticLabel: t.common.close,
              onPressed: () => ref.read(roomChatNoticeProvider.notifier).clear(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The super chat board: the platform's own list merged with the paid
/// messages and membership cards that arrive while the room is open; a
/// failure names the reason and offers a retry.
final class _SuperChatTab extends ConsumerWidget {
  const _SuperChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final board = ref.watch(roomSuperChatsProvider);
    void retry() => unawaited(ref.read(roomProvider.notifier).reloadSuperChats());
    if (board.loading && board.messages.isEmpty) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
    }
    final error = board.error;
    if (error != null && board.messages.isEmpty) {
      return _chatStateArea(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.badgeDollarSign),
          title: Text(t.room.superChatFailed),
          description: Text(error),
          actions: [DsButton(onPressed: retry, child: Text(t.common.retry))],
        ),
      );
    }
    if (board.messages.isEmpty) {
      return _chatStateArea(
        child: DsEmptyState(icon: const DsIcon(DsIcons.badgeDollarSign), title: Text(t.room.superChatEmpty)),
      );
    }
    final messages = board.messages;
    return ListView.separated(
      padding: const EdgeInsets.all(DsSpace.s16),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s8),
      // Newest on top, as the reference's super chat page keeps them.
      itemBuilder: (context, index) => _SuperChatCard(message: messages[messages.length - 1 - index]),
    );
  }
}

/// One paid message: who paid, how much, what was said and when it shows.
final class _SuperChatCard extends StatelessWidget {
  const _SuperChatCard({required this.message});

  final LiveSuperChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final name = message.userName.trim();
    final face = message.faceUrl.trim();
    final membership = isMembershipCard(message);
    final price = _superChatPrice(message) ?? '';
    // The price's warmth: the tint deepens with the money on the line, so
    // the board reads by value at a glance (reference's graded cards).
    final amount = message.price.amount ?? 0;
    final tint = amount >= 100
        ? 0.16
        : amount >= 10
        ? 0.10
        : 0.05;
    // The same warmth, in the platform's own two colours when it sends them
    // (the reference paints its super-chat card with exactly these): the money
    // still decides the weight, so the board keeps reading by value, and the
    // row's text keeps the theme's contrast.
    final banner = paidBannerGradient(
      top: message.display.backgroundColor,
      bottom: message.display.backgroundBottomColor,
      surface: colors.surface,
      weight: tint,
    );
    return Container(
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: banner == null
          ? DsBoxDecoration(
              color: colors.accent.withValues(alpha: tint),
              borderRadius: BorderRadius.circular(theme.radii.card),
            )
          : BoxDecoration(gradient: banner, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          // A membership card has no avatar of its own (the reference's
          // D07.2 cards), only the buyer's name.
          if (!membership)
            DsAvatar(
              initials: avatarInitials(name),
              image: face.isEmpty ? null : cachedImage(face, policy: ImageCachePolicies.userAvatar),
              size: DsSize.sm,
              semanticLabel: name,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(color: colors.text),
                      ),
                    ),
                    if (price.isNotEmpty) DsBadge(dot: false, label: Text(price), status: DsStatus.warning),
                  ],
                ),
                Text(message.text, style: theme.typography.body.copyWith(color: colors.text)),
                if (_shownAt() case final shown?)
                  Text(shown, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The time the message stays on the board, in the viewer's clock.
  String? _shownAt() {
    final start = message.startTime?.toLocal();
    final end = message.endTime?.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    String clock(DateTime time) => '${two(time.hour)}:${two(time.minute)}';
    if (start == null && end == null) return null;
    if (start != null && end != null) return '${clock(start)} – ${clock(end)}';
    return start == null ? clock(end!) : clock(start);
  }
}

/// The shield inside the room: the compact tag-based panel the chat
/// column's width was squeezing out of the settings pane.
final class _ShieldTab extends StatelessWidget {
  const _ShieldTab();

  @override
  Widget build(BuildContext context) => const RoomShieldPanel();
}
