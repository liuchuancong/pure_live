import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
// Only for the [PureDesignLanguage] enum the switch below names; the widget
// draws every language itself and touches no adapter.
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';

/// The public card. [build] switches on `UiConfig.language` and constructs the
/// design language's own surface directly — Material's `Card` + `InkWell`, the
/// iOS inset-grouped section, macOS's `MacosSheet` panel, Fluent's `FluentCard`,
/// ForUI's `FCard`, glass's `GlassCard`, the Neumorphic `NeuCard`, Wind's `WCard`
/// — so what the user sees is exactly what that library's own documentation
/// shows. Switching `UiConfig.language` re-skins every card.
///
/// A surface, not a control, is what most languages ship: where the library has
/// no tap or focus slot of its own, the card composes one (`GestureDetector`,
/// a click cursor) rather than hand-painting an approximation of one.
class PureCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final interactive = onTap != null || onLongPress != null;
    final inset = padding ?? EdgeInsets.all(dense ? theme.card.padding * 0.66 : theme.card.padding);
    final fill = style?.background ?? (selected ? theme.colors.primaryBg : null);
    final edge = style?.borderColor ?? (bordered ? theme.colors.border : null);

    return switch (language) {
      // Yaru draws cards with the Material widgets — that is what Yaru itself
      // is; its character comes from the host theme, not from a different card.
      PureDesignLanguage.material || PureDesignLanguage.yaru => Card(
        clipBehavior: Clip.antiAlias,
        color: fill,
        shape: RoundedRectangleBorder(
          side: edge == null ? BorderSide.none : BorderSide(color: edge, width: style?.borderWidth ?? 1),
          borderRadius: style?.borderRadius ?? BorderRadius.circular(theme.card.borderRadius),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          // Focus belongs to an interactive card; a plain one must not take it.
          focusNode: interactive ? focusNode : null,
          autofocus: interactive && autofocus,
          child: Padding(padding: inset, child: child),
        ),
      ),
      // The iOS card *is* the inset-grouped section. Its own page margin and
      // grouped-background band are reset — the caller places the card.
      PureDesignLanguage.cupertino => cupertino.CupertinoListSection.insetGrouped(
        backgroundColor: const Color(0x00000000),
        margin: EdgeInsets.zero,
        decoration: fill == null
            ? null
            : // The 10pt corner the section clips to, which it does not expose.
              BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
        children: [
          if (interactive)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(padding: inset, child: child),
            )
          else
            Padding(padding: inset, child: child),
        ],
      ),
      // macOS has no card: the one inline panel `macos_ui` owns is the sheet,
      // whose double hairline *is* the group-box edge, so `bordered` is free.
      PureDesignLanguage.macos => macos.MacosSheet(
        insetPadding: EdgeInsets.zero,
        backgroundColor: fill,
        child: Padding(
          padding: inset,
          child: interactive
              ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: child,
                  ),
                )
              : child,
        ),
      ),
      // Fluent's card is interactive itself, and `selected` selects its real
      // `*Selected` tokens — no token fill is forced on top. Only the
      // properties [style] names are mapped; the rest stay Fluent's own.
      PureDesignLanguage.fluent => f2.FluentCard(
        onPressed: onTap,
        selected: selected,
        focusNode: focusNode,
        autofocus: autofocus,
        // Windows 11 Settings card grammar: an 8 px radius, no outline — the
        // card separates by fill against the muted page canvas, not by a
        // stroke. A border appears only when the caller asks for one.
        style: f2.FluentCardStyle(
          backgroundColor: style?.background == null ? null : WidgetStatePropertyAll(style!.background),
          borderColor: WidgetStatePropertyAll(edge ?? const Color(0x00000000)),
          borderWidth: WidgetStatePropertyAll(edge == null ? 0.0 : (style?.borderWidth ?? 1.0)),
          borderRadius: WidgetStatePropertyAll(style?.borderRadius ?? BorderRadius.circular(8)),
          padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(inset),
        ),
        // FluentCard has no long-press slot; the wrapper recognises it without
        // changing how the card looks.
        child: onLongPress == null
            ? child
            : GestureDetector(behavior: HitTestBehavior.opaque, onLongPress: onLongPress, child: child),
      ),
      PureDesignLanguage.forui => _foruiCard(inset),
      PureDesignLanguage.glass => _glassCard(inset),
      PureDesignLanguage.neumorphic => _neumorphicCard(inset),
      PureDesignLanguage.wind => _windCard(theme, inset),
    };
  }

  /// ForUI's `FCard` paints the surface and none of the inside space, so the
  /// token padding wraps the content here — `dense` is the same 0.66 step the
  /// rest of the family takes. `FCard` is a surface, not a tappable: forui
  /// composes interaction with a tap layer around a card, so the gestures are
  /// attached outside the surface rather than by rebuilding the decoration by
  /// hand. Selection has no chrome of its own to borrow and stays unstated.
  Widget _foruiCard(EdgeInsetsGeometry inset) {
    final card = forui.FCard(
      child: Padding(padding: inset, child: child),
    );
    if (onTap == null && onLongPress == null) {
      return card;
    }
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, onLongPress: onLongPress, child: card);
  }

  /// Glass's `GlassCard` owns the surface, radius and blur, so they stay at the
  /// library's defaults and only the padding passes through, tightened by the
  /// same `dense` step the family takes. `selected` and `bordered` have no
  /// frosted equivalent — the card is translucent by definition — so they are
  /// left unstated rather than faked with an opaque border that would defeat
  /// the whole style.
  Widget _glassCard(EdgeInsetsGeometry inset) => glass.GlassCard(
    padding: inset,
    child: onTap == null && onLongPress == null
        ? child
        : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, onLongPress: onLongPress, child: child),
  );

  /// `NeuCard` is the library's own card, and the embossed surface is the
  /// card's whole identity; it takes no callbacks itself, so the gesture layer
  /// wraps the content. `selected` and `bordered` have no soft-surface
  /// equivalent — a Neumorphic card is defined by its shadow, not a border or
  /// fill — so they are left to the library's own pressed state rather than
  /// faked with an outline.
  Widget _neumorphicCard(EdgeInsetsGeometry inset) => neu.NeuCard(
    padding: inset,
    child: onTap == null && onLongPress == null
        ? child
        : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, onLongPress: onLongPress, child: child),
  );

  /// Wind's `WCard` is structure only — a `w-full flex flex-col` container with
  /// header/body/footer slots rendered through `WDiv` — and paints no surface,
  /// so the surface comes from the resolved token: selection tints it,
  /// `bordered` or a selection draws the token border, and a gesture layer
  /// appears only when the caller supplied a tap. The body is stretched so an
  /// interactive card's hit area matches the surface `WCard` paints full width.
  Widget _windCard(PureTheme theme, EdgeInsetsGeometry inset) {
    Widget body = Padding(padding: inset, child: child);
    if (onTap != null || onLongPress != null) {
      body = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, onLongPress: onLongPress, child: body);
    }
    body = SizedBox(width: double.infinity, child: body);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style?.background ?? (selected ? theme.colors.primaryBg : theme.card.background),
        borderRadius: style?.borderRadius ?? BorderRadius.circular(theme.card.borderRadius),
        border: bordered || selected ? Border.all(color: theme.colors.border) : null,
      ),
      child: wind.WCard(child: body),
    );
  }
}

/// A selectable list row. [build] switches on `UiConfig.language` and
/// constructs the language's own row — `ListTile`, `CupertinoListTile`,
/// `MacosListTile`, Fluent's `FluentListItem`, ForUI's `FTile`, glass's
/// `GlassListTile` — and where the library ships no row at all, the row is
/// hand-built in that language's own idiom from its primitives (the Neumorphic
/// `NeuContainer`, Wind's `WAnchor` + `WDiv`). The ink, the pressed fill and
/// the typography are the library's own either way. Switching
/// `UiConfig.language` re-skins every row.
///
/// Each language shows `selected` its own way — Material tints the content,
/// iOS fills the tile, Fluent's plain list marks the row by its semibold
/// title, Neumorphic sinks it with depth, Wind recolours its accent bar —
/// because the row is the library's, not a painted approximation.
class PureListRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      // Yaru draws rows with the Material widgets — that is what Yaru itself
      // is; its character comes from the host theme, not from a different row.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialRow(theme),
      PureDesignLanguage.cupertino => _cupertinoRow(theme),
      PureDesignLanguage.macos => _macosRow(theme),
      PureDesignLanguage.fluent => _fluentRow(theme),
      PureDesignLanguage.forui => _foruiRow(),
      PureDesignLanguage.glass => _glassRow(context, theme),
      // The neumorphic library and Wind ship no settings row; Flutter's
      // official Material ListTile is the fallback.
      PureDesignLanguage.neumorphic => _materialRow(theme),
      PureDesignLanguage.wind => _materialRow(theme),
    };
  }

  /// Material's tile carries every field natively; `divided` is the one it has
  /// no slot for (a Material list puts separators between items), so the
  /// library's own `Divider` is drawn under it.
  Widget _materialRow(PureTheme theme) {
    final tile = Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: leading,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
        selected: selected,
        selectedColor: selected ? theme.colors.primary : null,
        enabled: onTap != null || onLongPress != null,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
    );
    if (!divided) {
      return tile;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        Divider(
          height: theme.token.motion.lineWidth * 2,
          thickness: theme.token.motion.lineWidth,
          color: theme.listTile.dividerColor,
        ),
      ],
    );
  }

  /// The iOS settings row. Long-press (which iOS tiles do not recognise) gets
  /// a translucent wrapper, and `divided` draws the inset hairline itself — a
  /// bare tile has no separator concept outside a `CupertinoListSection`.
  Widget _cupertinoRow(PureTheme theme) {
    Widget tile = cupertino.CupertinoListTile(
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
      backgroundColor: selected ? theme.listTile.selectedBackground : null,
    );
    if (onLongPress != null) {
      tile = GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: onLongPress, child: tile);
    }
    if (!divided) {
      return tile;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        Container(
          height: theme.token.motion.lineWidth,
          color: theme.listTile.dividerColor,
          margin: const EdgeInsets.only(left: 16),
        ),
      ],
    );
  }

  /// macOS rows end at their text, so `trailing` sits beside the tile in a
  /// row and `selected` paints the fill the tile has no slot for.
  Widget _macosRow(PureTheme theme) {
    final trailing = this.trailing;
    Widget tile = macos.MacosListTile(
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle().copyWith(color: theme.colors.textSecondary),
            ),
      onClick: onTap,
      onLongPress: onLongPress,
      mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    );
    if (selected) {
      tile = DecoratedBox(
        decoration: BoxDecoration(color: theme.listTile.selectedBackground),
        child: tile,
      );
    }
    final row = trailing == null
        ? tile
        : Row(
            children: [
              Expanded(child: tile),
              SizedBox(width: theme.listTile.gap),
              trailing,
            ],
          );
    if (!divided) {
      return row;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Container(height: theme.token.motion.lineWidth, color: theme.listTile.dividerColor),
      ],
    );
  }

  /// Fluent's row is owned by its list — selection, keyboard handling and the
  /// roving focus live on `FluentList` — so a single row is that list with one
  /// item: the tap arrives as a selection change with no affordance drawn.
  /// The list owns its focus nodes, so [focusNode]/[autofocus] have no slot
  /// under Fluent.
  Widget _fluentRow(PureTheme theme) {
    final row = f2.FluentList<int>(
      // The default `none` selection draws no affordance; a selected row is
      // Fluent's own plain-list treatment — a semibold title.
      selectedValues: selected ? const {0} : const <int>{},
      onSelectionChange: onTap == null ? null : (_) => onTap!(),
      items: [
        f2.FluentListItem<int>(
          value: 0,
          media: leading,
          secondary: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: trailing,
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    final longPressable = onLongPress == null
        ? row
        : GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: onLongPress, child: row);
    if (!divided) {
      return longPressable;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        longPressable,
        Container(height: theme.token.motion.lineWidth, color: theme.listTile.dividerColor),
      ],
    );
  }

  /// ForUI's `FTile` is the library's own row and carries every part the
  /// fields do — the hover fill, ink and text roles come from its style table.
  /// A row with no callbacks is simply not hoverable, so nothing has to be
  /// disabled by hand. `divided` is the one field a lone tile has no slot for
  /// (the library puts separators between items, through `FTileGroup`), so the
  /// row draws the library's own `FDivider` under itself — the same widget a
  /// grouped list would paint, not an invented hairline.
  Widget _foruiRow() {
    final row = forui.FTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      prefix: leading,
      suffix: trailing,
      onPress: onTap,
      onLongPress: onLongPress,
      selected: selected,
      focusNode: focusNode,
      autofocus: autofocus,
    );

    if (!divided) {
      return row;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [row, const forui.FDivider()]);
  }

  /// `glass_morphism_plus` ships a row: `GlassListTile`, a `GlassContainer`
  /// sheet with the leading, title, subtitle and trailing slots — the surface,
  /// radius, blur and stroke are its inherited values. Two things the library
  /// hardcodes are given back to the theme: it styles the labels white
  /// whatever the brightness, so each is wrapped in the token's text role.
  /// Selection raises the sheet's opacity and takes the token's selected tint,
  /// which is how this style marks a choice everywhere, and `divided` appends
  /// the library's own `GlassDivider`. `GlassListTile` builds its Material row
  /// inside the sheet and forwards no focus parameter, so a glass row is
  /// reached by the traversal around it, not handed a node.
  Widget _glassRow(BuildContext context, PureTheme theme) {
    final glassTheme = glass.GlassTheme.of(context);
    final row = glass.GlassListTile(
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.text.body.copyWith(color: theme.colors.text),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
      trailing: trailing,
      // A row with no callback is inert rather than greyed: `GlassListTile`
      // folds `enabled` into its Material row, which dims the labels the
      // contract wants kept readable, so the callback nullability drives it.
      onTap: onTap,
      onLongPress: onLongPress,
      color: selected ? theme.colors.primaryBg : glassTheme.color,
      opacity: selected ? (glassTheme.opacity * 2.6).clamp(0.0, 1.0) : glassTheme.opacity,
      borderColor: selected ? theme.colors.primary : glassTheme.borderColor,
    );

    // `GlassListTile` paints a Material row inside its sheet. Placed on a
    // surface that is not itself Material — the frosted column a glass page is
    // built out of — that inner row has no sheet to print on and Flutter throws
    // for it. The transparent Material here is that sheet: it paints nothing and
    // changes no pixel of the frost.
    final tile = Material(type: MaterialType.transparency, child: row);
    if (!divided) {
      return tile;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        glass.GlassDivider(thickness: theme.token.motion.lineWidth, color: theme.listTile.dividerColor),
      ],
    );
  }
}
