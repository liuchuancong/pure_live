import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart' show desktopWindowHostProvider;
import 'package:pure_live/app/shell/desktop/title_bar_search.dart' show TitleBarSearch;
import 'package:pure_live/app/shell/desktop/window_caption_controls.dart' show WindowCaptionControls;
import 'package:pure_live/i18n/translations.g.dart';

/// The height of the strip: the drag band and the caption buttons' row.
const double kTitleBarHeight = 44;

/// The window's own strip: drag band, brand, title-bar search and the
/// caption controls, one copy above every route.
///
/// A drag on the band and a double-tap go to the window host; the app owns
/// what the strip shows, `live_shell_desktop` owns what the window does.
final class PureTitleBar extends ConsumerWidget {
  /// The title bar.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final host = ref.watch(desktopWindowHostProvider);
    return ColoredBox(
      color: colors.surface,
      child: SizedBox(
        height: kTitleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => host.startDragging(),
                onDoubleTap: host.toggleMaximize,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    DsIcon(DsIcons.tv, size: 16, color: colors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      context.t.app.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const TitleBarSearch(),
            const WindowCaptionControls(),
          ],
        ),
      ),
    );
  }
}
