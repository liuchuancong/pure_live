part of 'room_page.dart';

/// The follows the room page reads (the follow button's watched list).
final followsRoomProvider = Provider<List<LiveRoom>>((ref) {
  ref.watch(followsProvider);
  return ref.read(followsProvider).rooms;
});

/// The room page's app bar — the title bar, redesigned (the layout ledger's
/// twenty-first round): the avatar with two lines beside it, the anchor's
/// name over the platform and area; at the end the follow and — on a window
/// wide enough for them — the reference's system group (share, the details
/// door, the theme, the chat column's toggle) and, where the app draws its
/// own caption, the window's three buttons. A compact bar keeps the follow
/// and the window keys alone: the room's verbs live in the more container
/// there, and the bar answers "who and where" and nothing more.
/// On a desktop that draws its own caption the bar *is* the caption: the
/// identity block sits inside the drag band, so the page never stacks two
/// title bars.
PreferredSizeWidget _roomAppBar(
  BuildContext context, {
  required DsColors colors,
  required bool ownChrome,
  required VoidCallback leave,
}) {
  final t = context.t;
  // Two lines of identity need the room's 56; the caption controls ride
  // centered between the rows.
  var height = WindowClassScope.toolbarHeightOf(context);
  // Two lines of identity need the room's 56; a taller class keeps its own.
  if (height < 56) height = 56;
  // The compact bar trims to follow plus the window keys (the reference's
  // own compact topbar): share and the details live in the more container,
  // the theme in the settings, and the column toggle folds itself away
  // under the wide breakpoint.
  final compact = MediaQuery.sizeOf(context).width < kRoomCompactBreakpoint;
  final leading = DsTooltip(
    message: t.common.back,
    side: DsSide.bottom,
    child: WindowCaptionButton(semanticLabel: t.common.back, icon: DsIcons.arrowLeft, size: 36, onPressed: leave),
  );
  return AppBar(
    backgroundColor: colors.surface,
    surfaceTintColor: const Color(0x00000000),
    elevation: 0,
    automaticallyImplyLeading: false,
    toolbarHeight: height,
    leadingWidth: 36,
    leading: leading,
    titleSpacing: DsSpace.s4,
    // The identity block is the window's handle where the app draws its own
    // caption: the drag band wraps it, never a second title bar.
    title: ownChrome
        ? const SizedBox(
            width: double.infinity,
            child: WindowDragArea(child: RoomIdentityBar()),
          )
        : const RoomIdentityBar(),
    actions: [
      const _FollowPill(),
      if (!compact) ...[
        const _ShareButton(),
        DsTooltip(
          message: t.room.detailsHint,
          side: DsSide.bottom,
          child: ChromeIconButton(
            icon: DsIcons.badgeInfo,
            semanticLabel: t.room.detailsHint,
            tooltip: t.room.detailsHint,
            size: 36,
            onPressed: () => unawaited(showRoomDetails(context)),
          ),
        ),
        const ThemeModeToggle(size: 36),
        const _ChatColumnToggle(),
      ],
      if (ownChrome) ...[
        const SizedBox(width: DsSpace.s4),
        const SizedBox(height: 16, child: DsDivider.vertical()),
        const WindowCaptionControls(height: 36),
      ],
      const SizedBox(width: DsSpace.s4),
    ],
  );
}

/// The bar's share verb (the reference's sys group head): the same share
/// sheet the more container's circle opens.
final class _ShareButton extends ConsumerWidget {
  const _ShareButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final detail = ref.watch(roomProvider.select((room) => room.room));
    return DsTooltip(
      message: t.room.share,
      side: DsSide.bottom,
      child: ChromeIconButton(
        icon: DsIcons.share,
        semanticLabel: t.room.share,
        tooltip: t.room.share,
        size: 36,
        onPressed: detail == null ? null : () => unawaited(shareRoom(context, detail)),
      ),
    );
  }
}

/// The follow action in the app bar: a labelled pill on a wide window, the
/// same pill on a phone (it gives way only if the header needs the room).
final class _FollowPill extends ConsumerWidget {
  const _FollowPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final detail = ref.watch(roomProvider.select((room) => room.room));
    if (detail == null) return const SizedBox.shrink();
    final followed = ref.watch(
      followsRoomProvider.select((follows) {
        final key = detail.ref.identityKey;
        return follows.any((followed_) => followed_.ref.identityKey == key);
      }),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s4),
      child: DsButton(
        variant: followed ? DsButtonVariant.secondary : DsButtonVariant.primary,
        size: DsSize.sm,
        onPressed: () => unawaited(toggleRoomFollow(context, ref)),
        leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconSm),
        child: Text(followed ? t.room.unfollow : t.room.follow),
      ),
    );
  }
}

/// Shows or folds the chat column from the room bar — the live sites' panel
/// verb, beside share and more. Only the wide room has a column to fold.
final class _ChatColumnToggle extends ConsumerWidget {
  const _ChatColumnToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The column exists wherever the wide layout does (840 and up), not only
    // past the sidebar breakpoint: a viewer who folded the chat at 900 must
    // still be able to unfold it at 900.
    if (MediaQuery.sizeOf(context).width < kRoomWideBreakpoint) return const SizedBox.shrink();
    final open = !ref.watch(chatCollapsedProvider);
    return ChromeIconButton(
      icon: open ? DsIcons.panelRightClose : DsIcons.panelRightOpen,
      semanticLabel: open ? context.t.room.collapseChat : context.t.room.expandChat,
      tooltip: open ? context.t.room.collapseChat : context.t.room.expandChat,
      size: 36,
      onPressed: () {
        if (open) {
          unawaited(ref.read(chatCollapsedProvider.notifier).set(value: true));
        } else {
          unawaited(ref.read(chatCollapsedProvider.notifier).set(value: false));
        }
      },
    );
  }
}
