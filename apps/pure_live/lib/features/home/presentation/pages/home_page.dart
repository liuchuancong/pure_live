import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/shell/desktop/desktop_layout.dart' show DesktopLayout;
import 'package:pure_live/i18n/translations.g.dart';

/// The home branch: the landing surface the shell opens on.
///
/// Phase one shows the welcome card; the feed of followed rooms and the
/// recommendations arrive with the sites package's wiring.
final class HomePage extends ConsumerWidget {
  /// The home page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final typography = DsTheme.of(context).typography;
    return SingleChildScrollView(
      padding: DesktopLayout.pagePadding,
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.home.welcome, style: typography.title.copyWith(color: colors.text)),
            const SizedBox(height: 8),
            Text(t.home.welcomeHint, style: typography.body.copyWith(color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}
