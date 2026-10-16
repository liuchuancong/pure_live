import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/component_token.dart' show CardComponentToken;

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';
import 'package:live_uikit/src/styling/style.dart';
import 'package:live_uikit/src/styling/widgets/live_box.dart';

/// The token-driven card renderer (surface, radius, border, elevation and the
/// hover lift on a tappable card, all from [CardComponentToken]) — the base
/// implementation for languages that do not map a card to their own widget.
class TokenCard extends StatelessWidget {
  /// A token card built from [spec].
  const new({required this.spec, super.key});

  /// The card configuration.
  final LanguageCardSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return LiveBox(
      style: (state) => _cardStyle(theme, spec, state),
      inlineStyle: spec.style,
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
      // A transparency `Material`, not a painted one: the card's own surface is
      // LiveBox's decoration, but descendants that need a Material ancestor —
      // an `InkWell` a caller put in the content, text selection, a tooltip —
      // have to find one here. `Card` used to supply it by being a Material;
      // a token card that only paints a box leaves those children crashing.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(theme.card.borderRadius),
        child: spec.child,
      ),
    );
  }
}

Style _cardStyle(LiveTheme theme, LanguageCardSpec spec, InteractionState state) {
  final ct = theme.card;
  final interactive = spec.onTap != null || spec.onLongPress != null;
  final showBorder = spec.bordered || spec.selected || state == InteractionState.focused;
  return Style(
    background: switch (state) {
      InteractionState.hovered || InteractionState.pressed when interactive => theme.colors.bgTextHover,
      _ => ct.background,
    },
    borderRadius: BorderRadius.circular(ct.borderRadius),
    padding: spec.padding ?? EdgeInsets.all(spec.dense ? ct.padding * 0.66 : ct.padding),
    shadow: spec.selected || state == InteractionState.pressed ? theme.token.motion.boxShadow : ct.shadow,
    borderColor: switch (state) {
      InteractionState.focused => theme.colors.primary,
      _ when spec.selected => theme.colors.primary,
      _ => spec.bordered ? ct.borderColor : null,
    },
    borderWidth: showBorder ? theme.token.motion.lineWidth : 0,
  );
}

/// The public card: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's surface.
class LiveCard extends StatelessWidget {
  /// A card wrapping [child].
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.bordered = false,
    this.dense = false,
    this.padding,
    this.focusNode,
    this.autofocus = false,
    this.style,
    super.key,
  });

  /// The card content.
  final Widget child;

  /// The tap handler.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the card shows a selected state.
  final bool selected;

  /// Whether the card is bordered.
  final bool bordered;

  /// Whether the card uses a tighter padding.
  final bool dense;

  /// An explicit inner padding.
  final EdgeInsetsGeometry? padding;

  /// A focus node and first-focus flag.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An inline style override.
  final Style? style;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.card(
    context,
    LanguageCardSpec(
      child: child,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      bordered: bordered,
      dense: dense,
      padding: padding,
      focusNode: focusNode,
      autofocus: autofocus,
      style: style,
    ),
  );
}

/// The token-driven list row — the Ant `List`/menu item group: leading, title,
/// subtitle, trailing, a hover fill and an optional divider. The base for
/// languages whose library has no row widget of their own.
class TokenListRow extends StatelessWidget {
  /// A token row built from [spec].
  const new({required this.spec, super.key});

  /// The row configuration.
  final LanguageListRowSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final lt = theme.listTile;
    final row = LiveBox(
      style: (state) => Style(
        background: switch (state) {
          InteractionState.hovered || InteractionState.pressed => lt.hoverBackground,
          _ when spec.selected => lt.selectedBackground,
          _ => null,
        },
        padding: EdgeInsets.symmetric(horizontal: lt.paddingHorizontal, vertical: lt.textPaddingVertical),
        alignment: Alignment.centerLeft,
      ),
      onTap: spec.onTap,
      onLongPress: spec.onLongPress,
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
      child: Row(
        children: [
          if (spec.leading case final lead?)
            Padding(
              padding: EdgeInsets.only(right: lt.gap),
              child: lead,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.title,
                  style: theme.text.body.copyWith(color: theme.colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (spec.subtitle case final sub?)
                  Text(
                    sub,
                    style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (spec.trailing case final trail?) ...[SizedBox(width: lt.gap), trail],
        ],
      ),
    );
    if (!spec.divided) {
      return row;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Container(height: theme.token.motion.lineWidth, color: lt.dividerColor),
      ],
    );
  }
}

/// A selectable list row: a thin dispatcher to the active language adapter.
class LiveListRow extends StatelessWidget {
  /// A list row.
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.divided = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The primary text.
  final String title;

  /// A secondary line of text.
  final String? subtitle;

  /// A leading widget (icon, avatar, thumbnail).
  final Widget? leading;

  /// A trailing widget (chevron, switch, badge).
  final Widget? trailing;

  /// The tap handler; null renders the row non-interactive.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the row shows the selected state.
  final bool selected;

  /// Whether to paint a divider under the row.
  final bool divided;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.listRow(
    context,
    LanguageListRowSpec(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      divided: divided,
      focusNode: focusNode,
      autofocus: autofocus,
    ),
  );
}
