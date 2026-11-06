import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// A thin indeterminate bar shown over kept content while a page or feed
/// refreshes. It draws nothing else and takes the caller's width, so a page
/// can put it directly under its own toolbar without moving any cards.
final class RefreshProgressBar extends StatelessWidget {
  /// The bar, [height] pixels tall.
  const RefreshProgressBar({this.height = 4, super.key});

  /// The track's thickness.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return IgnorePointer(
      child: DsProgressBar(
        semanticLabel: context.t.common.refresh,
        style: DsProgressBarStyle(
          height: height,
          trackColor: colors.channel,
          fillColor: colors.indicator,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}
