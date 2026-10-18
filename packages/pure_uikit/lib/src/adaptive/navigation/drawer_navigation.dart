import 'package:flutter/material.dart';
import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/adaptive_brand_mark.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';


/// The phone drawer from the adaptive navigation set.
///
/// Product mark, optional account card, grouped destinations. It closes
/// itself through the nearest [Scaffold] when no callback is supplied.
class PureNavigationDrawer extends StatelessWidget {
  /// A drawer [width] wide listing [destinations].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.width = AdaptiveShellSizes.drawerWidth,
    this.onClose,
    this.header,
    this.footer,
    this.brand,
    this.accountName,
    this.accountSubtitle,
    this.onAccountTap,
    this.accountAvatar,
    this.backgroundColor,
    this.closeTooltip = 'Close',
    super.key,
  });

  /// The destinations, top to bottom.
  final List<PureNavDestination> destinations;

  /// The selected destination's id.
  final String selectedId;

  /// Called with the tapped destination; the drawer closes afterwards.
  final ValueChanged<PureNavDestination> onDestinationSelected;

  /// The drawer's preferred width, clamped to the window.
  final double width;

  /// Overrides the default close behaviour.
  final VoidCallback? onClose;

  /// Optional content displayed beneath the brand row.
  final Widget? header;

  /// Optional content pinned below the destination list.
  final Widget? footer;

  /// The brand lockup at the drawer's head.
  final Widget? brand;

  /// The signed-in account's name; null shows the sign-in fallback.
  final String? accountName;

  /// The account card's subtitle, null hides the card entirely.
  final String? accountSubtitle;

  /// The account card's tap handler.
  final VoidCallback? onAccountTap;

  /// Overrides the account avatar.
  final Widget? accountAvatar;

  /// Overrides the drawer's background.
  final Color? backgroundColor;

  /// The close button's tooltip, localized by the app.
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);
    final media = MediaQuery.of(context);
    final windowWidth = media.size.width - media.padding.horizontal;
    final cap = windowWidth < 260 ? windowWidth : windowWidth * 0.88;
    var resolvedWidth = width;
    if (resolvedWidth > cap) {
      resolvedWidth = cap;
    }
    if (resolvedWidth < 1) {
      resolvedWidth = 1;
    }
    if (resolvedWidth > windowWidth) {
      resolvedWidth = windowWidth;
    }

    return Drawer(
      width: resolvedWidth,
      backgroundColor: backgroundColor ?? colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(PureSpacing.xl, PureSpacing.lg, PureSpacing.sm, PureSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(child: brand ?? AdaptiveBrandMark(onTap: onAccountTap)),
                  IconButton(
                    tooltip: closeTooltip,
                    onPressed: () => _close(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.lg, PureSpacing.xs, PureSpacing.lg, PureSpacing.md),
                child: header,
              ),
            if (accountSubtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.lg, PureSpacing.sm, PureSpacing.lg, PureSpacing.md),
                child: _AccountCard(
                  accountName: accountName,
                  subtitle: accountSubtitle!,
                  onTap: onAccountTap,
                  avatar: accountAvatar,
                  colors: colors,
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: PureSpacing.md, vertical: PureSpacing.xs),
                children: <Widget>[
                  for (int index = 0; index < destinations.length; index++) ...<Widget>[
                    if (destinations[index].startsGroup && index > 0)
                      Padding(
                        padding: const EdgeInsets.all(PureSpacing.sm),
                        child: Divider(height: 1, color: colors.border),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: PureNavigationTile(
                        destination: destinations[index],
                        selected: destinations[index].id == selectedId,
                        onTap: () {
                          onDestinationSelected(destinations[index]);
                          _close(context);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.lg, PureSpacing.xs, PureSpacing.lg, PureSpacing.md),
                child: footer,
              ),
            const SizedBox(height: PureSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
      return;
    }
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      scaffold.closeDrawer();
      return;
    }
    Navigator.maybePop(context);
  }
}

final class _AccountCard extends StatelessWidget {
  const new({
    required this.accountName,
    required this.subtitle,
    required this.onTap,
    required this.avatar,
    required this.colors,
  });

  final String? accountName;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? avatar;
  final AdaptiveSurfaceColors colors;

  @override
  Widget build(BuildContext context) {
    final textStyle = PureTheme.of(context).text;
    final signedIn = accountName != null;

    return Material(
      color: colors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: colors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PureSpacing.md, vertical: PureSpacing.md),
          child: Row(
            children: <Widget>[
              avatar ??
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: colors.brand, shape: BoxShape.circle),
                    child: Icon(
                      signedIn ? Icons.person_rounded : Icons.person_add_alt_1_rounded,
                      color: colors.onBrand,
                      size: 21,
                    ),
                  ),
              const SizedBox(width: PureSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (signedIn) ...<Widget>[
                      Text(
                        accountName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.body.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle.caption.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
