import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/scales/sizing.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/style/style.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_box.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_environment.dart';

/// One destination of a bottom navigation bar: what it is called and the glyph
/// that says so. A label is required — an icon-only bar asks a user to memorise
/// five glyphs, which is why the platform bars carry text by default.
@immutable
final class LiveNavBarItem {
  /// A destination labelled [label] with [icon].
  const new({required this.label, required this.icon});

  /// The destination's name.
  final String label;

  /// The destination's glyph.
  final IconData icon;

  @override
  bool operator ==(Object other) => other is LiveNavBarItem && other.label == label && other.icon == icon;

  @override
  int get hashCode => Object.hash(label, icon);
}

/// The token-driven bottom bar: the destinations share the width, the selected
/// one carries its text and glyph in the primary colour, and the whole bar sits
/// on the theme's elevated surface at the layout mode's bar height.
class TokenNavBar extends StatelessWidget {
  /// A token bar built from [spec].
  const new({required this.spec, super.key});

  /// The bar configuration.
  final LanguageNavBarSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final height = geometry?.navBarHeight ?? LiveSizing.navBarHeight;
    final iconSize = geometry?.iconSize ?? 18;
    final gap = theme.token.scale.sizes.xxs;
    final interactive = spec.enabled && spec.onChanged != null;

    return ColoredBox(
      color: theme.colors.bgElevated,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: theme.token.motion.lineWidth, color: theme.colors.border),
          SizedBox(
            height: height,
            child: Row(
              children: [
                for (var index = 0; index < spec.items.length; index++)
                  Expanded(
                    child: _Cell(
                      item: spec.items[index],
                      selected: index == spec.index,
                      enabled: interactive,
                      iconSize: iconSize,
                      gap: gap,
                      theme: theme,
                      onTap: interactive ? () => spec.onChanged!(index) : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const new({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.iconSize,
    required this.gap,
    required this.theme,
    required this.onTap,
  });

  final LiveNavBarItem item;
  final bool selected;
  final bool enabled;
  final double iconSize;
  final double gap;
  final LiveTheme theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = !enabled
        ? theme.colors.textDisabled
        : selected
        ? theme.colors.primary
        : theme.colors.textSecondary;

    return Semantics(
      selected: selected,
      child: LiveBox(
        style: (state) => Style(
          background: enabled && (state == InteractionState.hovered || state == InteractionState.pressed)
              ? theme.colors.fillTertiary
              : null,
          foreground: tint,
          alignment: Alignment.center,
          minHeight: iconSize,
        ),
        enabled: enabled,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: iconSize, color: tint),
            SizedBox(height: gap),
            Text(
              item.label,
              style: theme.text.caption.copyWith(color: tint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The public bottom navigation bar: a thin dispatcher to the active language
/// adapter. A shell passes its destinations here instead of a platform bar, so
/// the bottom of the screen re-skins with the rest of it.
class LiveNavBar extends StatelessWidget {
  /// A bar over [items] with [index] selected.
  const new({required this.items, required this.index, this.onChanged, this.enabled = true, super.key});

  /// The destinations, in order.
  final List<LiveNavBarItem> items;

  /// The selected destination.
  final int index;

  /// Called with a destination's index; null renders the bar inert.
  final ValueChanged<int>? onChanged;

  /// Whether the bar responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) =>
      LiveTheme.of(context).adapter
          .navBar(context, LanguageNavBarSpec(items: items, index: index, onChanged: onChanged, enabled: enabled));
}
