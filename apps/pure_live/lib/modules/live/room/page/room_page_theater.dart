part of 'room_page.dart';

/// The theatre's chat drawer (the reference's `.chat.glassy` over the stage):
/// a frosted column down the window's end edge, full height, carrying the
/// same chat panel the docked column does — tabs, messages, composer.
///
/// Its width is the viewer's own chat column width, kept between the touch
/// floor and a fraction of the window so a narrow theatre still shows most of
/// the picture. The drawer opens over the capsule and the tool cluster, the
/// way the reference stacks it; the scrim outside it — or the picture's 聊天
/// verb again — puts it away.
final class _TheaterChatDrawer extends ConsumerWidget {
  const _TheaterChatDrawer({required this.onClose});

  /// Closes the drawer; the panel's own verbs do not need it, the scrim and
  /// the picture's chat verb do.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final width = clampDouble(
      ref.watch(chatPanelWidthProvider),
      kChatPanelWidthMin,
      math.max(kChatPanelWidthMin, MediaQuery.sizeOf(context).width * 0.44),
    );
    return SizedBox(
      width: width,
      child: RoomGlassCard(
        // The drawer hangs off the window's end edge: it rounds on its start
        // side alone, the way the more panel does.
        borderRadius: BorderRadiusDirectional.horizontal(start: Radius.circular(theme.radii.card)),
        child: RoomChatPanel(translucent: true, trailing: _TheaterDrawerClose(onClose: onClose)),
      ),
    );
  }
}

/// The drawer's close verb, riding the tab row's end where a pointer looks
/// for it: the same ✕ the more panel's header carries.
final class _TheaterDrawerClose extends StatelessWidget {
  const _TheaterDrawerClose({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: context.t.common.close,
      onPressed: onClose,
      builder: (context, states, _) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: DsBoxDecoration(
          color: states.contains(WidgetState.hovered) ? colors.hover : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DsIcon(DsIcons.close, size: 16, color: colors.textMuted),
      ),
    );
  }
}
