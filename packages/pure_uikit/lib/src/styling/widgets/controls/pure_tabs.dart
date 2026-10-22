import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The height every language draws its strip at — the slot the shell's app bar
/// reserves (`PreferredSize(Size.fromHeight(48))`) and the height the pages
/// wrap the strip in. A tier per language would put the strip in a box its
/// caller did not ask for, so the number is one, not nine.
const double _stripHeight = 48;

/// One tab's label and optional leading icon.
@immutable
final class PureTab {
  /// A tab.
  const new({required this.label, this.icon, this.enabled = true});

  /// The tab label.
  final String label;

  /// An optional leading icon, drawn before the label in every language — the
  /// strip is painted here, so no library's missing icon slot can drop it.
  final IconData? icon;

  /// Whether this tab answers to input; false greys the cell out and keyboard
  /// traversal steps over it.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is PureTab && other.label == label && other.icon == icon && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, icon, enabled);
}

/// The kit's tab strip: one widget that draws the real shape of the control in
/// every `PureDesignLanguage` — the Material 3 row of medium-weight labels with
/// its full-width ink bar and top-rounded state layer, the iOS segmented strip
/// with its floating white thumb, the macOS control with its hairline-railed
/// track and inset white segment, the WinUI header strip with its short centred
/// accent bar, Ubuntu's accent pill sliding on a rounded card, the shadcn card
/// forui raises out of a bordered track, the wind hairline strip whose selected
/// label answers in the accent with a two-pixel rule under it, a frosted
/// stadium with a gradient pill under glass, and a raised track whose pressed-in
/// pill carries the accent under neumorphic. All of it is painted here, because
/// a strip that slides its own indicator across a measured cell is exactly what
/// the nine libraries each refuse to share — and because borrowing one of their
/// tab widgets handed the interaction contract to whichever library the config
/// happened to name: nine accent treatments, nine focus stories, and a macOS
/// strip that could neither shrink nor ellipsize its own labels. Colours, radii,
/// text and motion come from the tokens, so a language re-skin and a dark switch
/// still come out right.
///
/// Every visual answers to the same interaction contract: hover and pressed
/// tints, a disabled strip (a null `onChanged` or `enabled: false`) and disabled
/// tabs, the kit's focus ring, Left and Right arrows moving focus while Enter,
/// Space and the remote's select keys choose, `button`/`selected`/`enabled`
/// screen-reader traits naming every tab, and a strip that scrolls when the tabs
/// outgrow it. A strip that is not scrolling fills the width it was given,
/// dividing it equally between the tabs; a strip in a box with no width to
/// divide — an unbounded title slot — hugs its content instead of throwing
/// during layout.
class PureTabs extends StatelessWidget {
  /// A tab strip.
  const new({
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.spacing = 0,
    this.enabled = true,
    this.isScrollable = false,
    super.key,
  });

  /// The tabs, in order.
  final List<PureTab> tabs;

  /// The selected index.
  final int index;

  /// Called with a tab's index when it is chosen; null renders the strip inert.
  final ValueChanged<int>? onChanged;

  /// The gap between tabs. The strip paints the cells, so the gap it asks for
  /// is the gap it draws — zero puts them edge to edge, as the libraries do.
  final double spacing;

  /// Whether the strip responds to input; false greys every tab out.
  final bool enabled;

  /// Whether a long strip scrolls instead of squeezing its tabs; a scrolling
  /// strip lays its cells end to end at their own widths, because there is no
  /// width to share.
  final bool isScrollable;

  /// The look the active language draws. Nine cases, because nine tab strips
  /// exist and each of them is its own geometry — none of them delegates to a
  /// library's tab widget.
  _StripVisual _resolveVisual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _StripVisual.material(theme),
    PureDesignLanguage.fluent => _StripVisual.fluent(theme),
    PureDesignLanguage.cupertino => _StripVisual.cupertino(theme),
    PureDesignLanguage.macos => _StripVisual.macos(theme),
    PureDesignLanguage.yaru => _StripVisual.yaru(theme),
    PureDesignLanguage.forui => _StripVisual.forui(theme),
    PureDesignLanguage.wind => _StripVisual.wind(theme),
    PureDesignLanguage.glass => _StripVisual.glass(theme),
    PureDesignLanguage.neumorphic => _StripVisual.neumorphic(theme),
  };

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    // The branch a strip draws is its identity in tests and diagnostics.
    final branch = ValueKey('PureTabs.${theme.config.language.name}');
    final strip = _SlidingStrip(
      key: branch,
      tabs: tabs,
      index: index.clamp(0, tabs.length - 1),
      // A null callback is every language's own inert state, so folding
      // `enabled` into it once gives the strip a single verdict.
      select: enabled ? onChanged : null,
      spacing: spacing,
      visual: _resolveVisual(theme),
    );
    if (!isScrollable) {
      return strip;
    }
    // The scroll view hands the strip an unbounded width, and the strip reads
    // that as "pack at your own widths" — the same LayoutBuilder verdict that
    // keeps a non-scrolling strip in an unbounded slot from dividing a width
    // that is not there.
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: strip);
  }
}

/// How one design language paints the strip: the track its cells sit on, the
/// indicator that slides behind the chosen one, the interaction tints, the
/// colour of a cell's content in each state, and the geometry that makes this
/// language's strip its own — every value resolved from the theme when the
/// strip builds, so a language re-skin, a dark switch and the user's motion
/// settings come out of the tokens the kit's other controls read.
@immutable
final class _StripVisual {
  const new({
    required this.inset,
    required this.cellPadding,
    required this.fontSize,
    required this.iconSize,
    required this.iconLabelGap,
    required this.labelWeight,
    required this.disabledAlpha,
    required this.track,
    required this.stackAlignment,
    required this.cellRadius,
    required this.indicator,
    required this.indicatorHeight,
    required this.indicatorInset,
    required this.hoverTint,
    required this.pressedTint,
    required this.content,
  });

  /// Android Material 3: no track at all — a row of medium-weight labels over
  /// the page's own surface, the chosen one in the accent, and the ink bar
  /// running the cell's full width along the strip's bottom edge. The hover
  /// and pressed answers are M3's state layer, cut with the top-rounded
  /// corners its tabs carry.
  factory material(PureTheme theme) {
    return _StripVisual(
      inset: 0,
      cellPadding: 16,
      fontSize: theme.token.type.fontSize,
      iconSize: 18,
      iconLabelGap: 8,
      labelWeight: FontWeight.w500,
      disabledAlpha: 0.38,
      track: (theme, strip, inset) => strip,
      stackAlignment: AlignmentDirectional.bottomCenter,
      cellRadius: BorderRadius.vertical(top: Radius.circular(theme.token.scale.radii.lg)),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.tabs.inkBarColor : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1.5),
      ),
      indicatorHeight: 3,
      indicatorInset: 0,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: contentOnSurface,
    );
  }

  /// Windows Fluent: the pivot header, which marks its choice the way
  /// WinUI does — a short accent bar centred under the label rather than a
  /// stripe the width of the cell, the chosen label at full foreground and the
  /// rest dimmed, and a rounded-rect fill answering the pointer.
  factory fluent(PureTheme theme) {
    return _StripVisual(
      inset: 0,
      cellPadding: 12,
      fontSize: theme.token.type.fontSize,
      iconSize: 16,
      iconLabelGap: 8,
      labelWeight: FontWeight.w400,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => strip,
      stackAlignment: AlignmentDirectional.bottomCenter,
      cellRadius: BorderRadius.circular(theme.token.scale.radii.sm),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.tabs.inkBarColor : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1.5),
      ),
      indicatorHeight: 3,
      // The bar belongs to the label, not to the hit target: WinUI insets it
      // so a wide cell never looks like a progress track.
      indicatorInset: 12,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        // The chosen header is the *strong* one; the accent rides the bar.
        if (selected || pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// iOS: the sliding segmented strip — a grey stadium with a white thumb
  /// floating over it on its own drop shadow, the chosen label in the accent.
  /// It is the kit's sliding rail's own grammar drawn long, which is why it
  /// carries no hover fill: iOS answers a pointer in the text alone.
  factory cupertino(PureTheme theme) {
    return _StripVisual(
      inset: 4,
      cellPadding: 12,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 14,
      iconLabelGap: 5,
      labelWeight: FontWeight.w400,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => Padding(
        padding: inset,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.fillSecondary,
            borderRadius: BorderRadius.circular(PureRadii.pill),
          ),
          child: strip,
        ),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgElevated : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(PureRadii.pill),
        boxShadow: active
            ? [BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(0, 1.5))]
            : const [],
      ),
      indicatorHeight: null,
      indicatorInset: 0,
      hoverTint: (_) => null,
      pressedTint: (_) => null,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primary;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// macOS: the segmented control as the platform draws it today — a shallow
  /// rail with a hairline edge and a top light, and the chosen cell as an
  /// inset white segment with its own hairline, not an accent fill.
  factory macos(PureTheme theme) {
    return _StripVisual(
      inset: 2,
      cellPadding: 12,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 14,
      iconLabelGap: 5,
      labelWeight: FontWeight.w400,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgElevated,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.sm),
          border: Border.all(color: theme.colors.borderSecondary),
          boxShadow: [
            BoxShadow(
              color: theme.colors.shadowBase.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(padding: inset, child: strip),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(theme.token.scale.radii.sm),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgContainer : theme.colors.fill,
        borderRadius: BorderRadius.circular(theme.token.scale.radii.sm),
        border: active ? Border.all(color: theme.colors.borderSecondary) : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: theme.colors.shadowBase.withValues(alpha: 0.18),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      indicatorHeight: null,
      indicatorInset: 0,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: contentOnPill,
    );
  }

  /// Ubuntu Yaru: the same sliding pill the distribution gives a segmented
  /// choice — an accent pill on a rounded card track, the chosen label in the
  /// solid light role. Yaru asks for the rounder container its theme carries.
  factory yaru(PureTheme theme) {
    return _StripVisual(
      inset: 4,
      cellPadding: 14,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 16,
      iconLabelGap: 6,
      labelWeight: FontWeight.w500,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
          border: Border.all(color: theme.colors.borderSecondary),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primary : theme.colors.fillSecondary,
        borderRadius: BorderRadius.circular(PureRadii.pill),
      ),
      indicatorHeight: null,
      indicatorInset: 0,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: contentOnPill,
    );
  }

  /// shadcn, which forui ships: a bordered track of muted cells, and the active
  /// tab raised out of it as a card — the panel's own surface, its hairline and
  /// its shadow — rather than painted in the accent. The accent stays on
  /// controls that act; a tab here answers with surface.
  factory forui(PureTheme theme) {
    final corner = BorderRadius.circular(theme.token.scale.radii.base);
    return _StripVisual(
      inset: 3,
      cellPadding: 14,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 16,
      iconLabelGap: 6,
      labelWeight: FontWeight.w500,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.fillTertiary,
          borderRadius: corner,
          border: Border.all(color: theme.colors.borderSecondary),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: corner,
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.bgElevated : theme.colors.fill,
        borderRadius: corner,
        border: active ? Border.all(color: theme.colors.border) : null,
        boxShadow: active ? theme.token.motion.boxShadowTertiary : null,
      ),
      indicatorHeight: null,
      indicatorInset: 0,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected || pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// wind, the utility-class strip: a row of muted labels over one hairline,
  /// the chosen one in the accent with a two-pixel rule under it. It answers a
  /// pointer in the text colour alone — a hover class changes the colour, it
  /// paints no fill — so the tints are deliberately empty here.
  factory wind(PureTheme theme) {
    return _StripVisual(
      inset: 0,
      cellPadding: 16,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 15,
      iconLabelGap: 6,
      labelWeight: FontWeight.w500,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colors.borderSecondary)),
        ),
        child: strip,
      ),
      stackAlignment: AlignmentDirectional.bottomCenter,
      cellRadius: BorderRadius.circular(theme.token.scale.radii.sm),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.tabs.inkBarColor : theme.colors.fillTertiary,
        borderRadius: BorderRadius.circular(1),
      ),
      indicatorHeight: 2,
      indicatorInset: 0,
      hoverTint: (_) => null,
      pressedTint: (_) => null,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected || pressed) {
          return theme.tabs.itemSelectedColor;
        }
        if (hovered) {
          return theme.tabs.itemHoverColor;
        }
        return theme.tabs.itemColor;
      },
    );
  }

  /// The glass language: a frosted stadium (a real backdrop blur when the
  /// device can afford it, the pure colour ramp when it cannot) with the
  /// chosen cell as a gradient accent pill glowing under it.
  factory glass(PureTheme theme) {
    Color tint(PureTheme theme, double alpha) =>
        theme.isDark ? Colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);
    return _StripVisual(
      inset: 4,
      cellPadding: 14,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 16,
      iconLabelGap: 6,
      labelWeight: FontWeight.w500,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) {
        final filled = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PureRadii.pill),
            border: Border.all(
              color: theme.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(padding: inset, child: strip),
        );
        if (!theme.canBlur) {
          return filled;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(PureRadii.pill),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: filled),
        );
      },
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) {
        if (!active) {
          return BoxDecoration(color: theme.colors.fill, borderRadius: BorderRadius.circular(PureRadii.pill));
        }
        return BoxDecoration(
          borderRadius: BorderRadius.circular(PureRadii.pill),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [theme.colors.primary, Color.lerp(theme.colors.primary, theme.colors.link, 0.35)!],
          ),
          boxShadow: [
            BoxShadow(color: theme.colors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        );
      },
      indicatorHeight: null,
      indicatorInset: 0,
      hoverTint: (theme) => tint(theme, 0.06),
      pressedTint: (theme) => tint(theme, 0.1),
      content: contentOnPill,
    );
  }

  /// The neumorphic language: a track raised out of the page (light from the
  /// top left, shadow from the bottom right) and the chosen cell pressed into
  /// it, the mould's own shadow inverting so the selection reads as sunk.
  factory neumorphic(PureTheme theme) {
    List<BoxShadow> raised(PureTheme theme) => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
        blurRadius: 6,
        offset: const Offset(-3, -3),
      ),
    ];
    List<BoxShadow> sunk(PureTheme theme) => [
      for (final shadow in raised(theme))
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _StripVisual(
      inset: 4,
      cellPadding: 14,
      fontSize: theme.token.type.fontSizeSM,
      iconSize: 16,
      iconLabelGap: 6,
      labelWeight: FontWeight.w500,
      disabledAlpha: theme.token.motion.opacityLoading,
      track: (theme, strip, inset) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: BorderRadius.circular(theme.token.scale.radii.lg),
          boxShadow: raised(theme),
        ),
        child: Padding(padding: inset, child: strip),
      ),
      stackAlignment: AlignmentDirectional.center,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      indicator: (theme, {required active}) => BoxDecoration(
        color: active ? theme.colors.primaryBg : theme.colors.fill,
        borderRadius: BorderRadius.circular(PureRadii.pill),
        boxShadow: active ? sunk(theme) : null,
      ),
      indicatorHeight: null,
      indicatorInset: 0,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      content: (theme, {required selected, required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (selected) {
          return theme.colors.primary;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
    );
  }

  /// The track's padding around the cells (and so around the sliding
  /// indicator); zero is the languages that sit on the page's own surface.
  final double inset;

  /// The padding on either side of a cell's content.
  final double cellPadding;

  /// The label size, before the theme's font scale.
  final double fontSize;

  /// The glyph size inside a cell.
  final double iconSize;

  /// The gap between a cell's icon and its label.
  final double iconLabelGap;

  /// The weight the strip's labels carry; the languages whose tab is a control
  /// ask for medium, the header strips for the regular text weight.
  final FontWeight labelWeight;

  /// The opacity of a disabled tab; Material 3 answers with its spec's 38
  /// percent, the others with the token's loading opacity.
  final double disabledAlpha;

  /// Wraps the strip: decoration, blur, hairline, padding — whatever the
  /// language puts around the cells.
  final Widget Function(PureTheme theme, Widget strip, EdgeInsets inset) track;

  /// Where the strip sits inside the bar's fixed height; the ink-bar languages
  /// pin it to the bottom edge so the rule touches it.
  final AlignmentDirectional stackAlignment;

  /// The corner radius of a cell's hover tint and focus ring.
  final BorderRadius cellRadius;

  /// The decoration of the sliding indicator behind the chosen cell, with the
  /// `active` flag telling the language's chosen colour apart from the grey an
  /// inert strip shows.
  final Decoration Function(PureTheme theme, {required bool active}) indicator;

  /// The indicator's height; null fills the measured cell from top to bottom
  /// (the pill, the thumb, the raised card), a value pins a rule of that
  /// height to the strip's bottom edge (the ink bar).
  final double? indicatorHeight;

  /// How far the indicator is pulled in from the measured cell's sides; the
  /// language whose bar belongs to the label rather than the hit target gives
  /// it a width the cell does not have.
  final double indicatorInset;

  /// The tint behind a hovered, unselected cell; null is the languages that
  /// answer a hover in the text colour alone.
  final Color? Function(PureTheme theme) hoverTint;

  /// The tint behind a pressed cell.
  final Color? Function(PureTheme theme) pressedTint;

  /// The content colour in each state.
  final Color Function(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  })
  content;

  /// The content colours the filled-pill languages share: the solid light role
  /// on the accent, the text roles elsewhere.
  static Color contentOnPill(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  }) {
    if (!enabled) {
      return theme.colors.textQuaternary;
    }
    if (selected) {
      return theme.colors.textLightSolid;
    }
    if (pressed || hovered) {
      return theme.colors.text;
    }
    return theme.colors.textSecondary;
  }

  /// The content colours the ink-bar languages share: the accent on the chosen
  /// label, the tab roles elsewhere, straight off the tabs component token.
  static Color contentOnSurface(
    PureTheme theme, {
    required bool selected,
    required bool hovered,
    required bool pressed,
    required bool enabled,
  }) {
    if (!enabled) {
      return theme.colors.textQuaternary;
    }
    if (selected || pressed) {
      return theme.tabs.itemSelectedColor;
    }
    if (hovered) {
      return theme.tabs.itemHoverColor;
    }
    return theme.tabs.itemColor;
  }
}

/// The strip every language shares: it measures the chosen cell after layout,
/// slides the indicator there, moves focus with the arrow keys, divides a
/// bounded width equally between its cells or packs them at their own widths,
/// and keeps the selection visible in a scrolled strip.
class _SlidingStrip extends StatefulWidget {
  const new({
    required this.tabs,
    required this.index,
    required this.select,
    required this.spacing,
    required this.visual,
    super.key,
  });

  final List<PureTab> tabs;

  final int index;

  /// The live callback; null is the disabled verdict the public widget has
  /// already folded `enabled` into.
  final ValueChanged<int>? select;

  final double spacing;

  final _StripVisual visual;

  @override
  State<_SlidingStrip> createState() => _SlidingStripState();
}

class _SlidingStripState extends State<_SlidingStrip> {
  final GlobalKey _stripKey = GlobalKey();
  List<GlobalKey> _cellKeys = const [];
  List<FocusNode> _focusNodes = const [];
  Rect? _indicatorRect;

  /// False until the first measurement lands, so the indicator appears on the
  /// chosen cell without sliding in from nowhere.
  bool _indicatorPlaced = false;
  bool _revealPending = false;

  @override
  void initState() {
    super.initState();
    _rebuildCells();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _SlidingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _rebuildCells();
    }
    if (oldWidget.index != widget.index) {
      _revealPending = true;
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Whether the strip is live.
  bool get _active => widget.select != null;

  int get _selectedIndex => widget.index.clamp(0, widget.tabs.length - 1);

  /// Whether the selection may draw as chosen: an inert strip, or a strip whose
  /// chosen tab is itself disabled, shows the grey selection.
  bool get _selectionLive => _active && widget.tabs[_selectedIndex].enabled;

  void _rebuildCells() {
    // The old nodes are still attached until this rebuild lands, so their
    // disposal waits for the frame's end.
    final retired = _focusNodes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in retired) {
        node.dispose();
      }
    });
    _cellKeys = [for (var i = 0; i < widget.tabs.length; i++) GlobalKey()];
    _focusNodes = [for (var i = 0; i < widget.tabs.length; i++) FocusNode(debugLabel: 'PureTabs.cell.$i')];
    _indicatorPlaced = false;
    _indicatorRect = null;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Places the indicator over the chosen cell, wherever layout put it — this
  /// runs after every build, so a font-scale change or a language re-skin
  /// re-seats it too.
  void _measure() {
    if (!mounted) {
      return;
    }
    final stripBox = _stripKey.currentContext?.findRenderObject();
    final cellBox = _cellKeys[_selectedIndex].currentContext?.findRenderObject();
    if (stripBox is! RenderBox || cellBox is! RenderBox || !cellBox.hasSize) {
      return;
    }
    final rect = cellBox.localToGlobal(Offset.zero, ancestor: stripBox) & cellBox.size;
    final reveal = _revealPending;
    _revealPending = false;
    if (rect != _indicatorRect) {
      setState(() {
        _indicatorRect = rect;
        _indicatorPlaced = true;
      });
    }
    if (reveal) {
      _reveal(_selectedIndex);
    }
  }

  /// Scrolls the strip so cell [index] is in view; a no-op when the strip is
  /// not inside a scroll view.
  void _reveal(int index) {
    final cellContext = _cellKeys[index].currentContext;
    if (cellContext != null) {
      Scrollable.ensureVisible(cellContext, duration: context.themeFor.duration, alignment: 0.5);
    }
  }

  /// Focuses the nearest enabled cell in [direction]; reports whether one was
  /// found, so a strip at its edge hands the key back to the shell.
  bool _moveFocus(int from, int direction) {
    if (!_active) {
      return false;
    }
    var next = from + direction;
    while (next >= 0 && next < widget.tabs.length) {
      if (widget.tabs[next].enabled) {
        _focusNodes[next].requestFocus();
        _reveal(next);
        return true;
      }
      next += direction;
    }
    return false;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Left and Right mean previous and next in the reading direction, so a
    // mirrored strip traverses the way it is laid out rather than backwards.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _moveFocus(index, rtl ? 1 : -1) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return _moveFocus(index, rtl ? -1 : 1) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    final activate = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (activate.contains(event.logicalKey)) {
      // A disabled tab must never be chosen through a keyboard or TV remote,
      // even if focus was retained while the tab became disabled.
      if (_active && widget.tabs[index].enabled) {
        widget.select?.call(index);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    // The label size rides the theme's font scale, so the user's small-text
    // preference grows the tab labels with the rest of the chrome.
    final fontRatio = theme.text.label.fontSize! / theme.token.type.fontSize;
    final labelStyle = theme.text.label.copyWith(fontSize: visual.fontSize * fontRatio, fontWeight: visual.labelWeight);
    final inset = EdgeInsets.symmetric(horizontal: visual.inset, vertical: visual.inset);

    return LayoutBuilder(
      builder: (context, constraints) {
        // A strip divides a width it was given; one handed an unbounded box —
        // a scrolling view, or a title slot that never bounded its child —
        // packs at its own widths instead of dividing nothing.
        final stretch = constraints.hasBoundedWidth;
        final cells = [
          for (var i = 0; i < widget.tabs.length; i++) ...[
            if (i > 0 && widget.spacing > 0) SizedBox(width: widget.spacing),
            if (stretch)
              Expanded(
                child: _cell(index: i, visual: visual, labelStyle: labelStyle),
              )
            else
              _cell(index: i, visual: visual, labelStyle: labelStyle),
          ],
        ];
        final row = Row(mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min, children: cells);
        final strip = Stack(
          key: _stripKey,
          clipBehavior: Clip.none,
          alignment: visual.stackAlignment,
          children: [
            if (_indicatorPlaced && _indicatorRect != null) _indicator(theme, visual: visual),
            row,
          ],
        );
        final bar = SizedBox(height: _stripHeight, child: visual.track(theme, strip, inset));
        if (_active) {
          return bar;
        }
        return IgnorePointer(child: bar);
      },
    );
  }

  Widget _indicator(PureTheme theme, {required _StripVisual visual}) {
    final rect = _indicatorRect!;
    final child = DecoratedBox(decoration: visual.indicator(theme, active: _selectionLive));
    // The first placement snaps; every later one slides.
    final duration = context.themeFor.duration;
    // The inset languages pull the rule in from the cell's sides, so it reads
    // as the label's marker; a cell narrower than the inset asks for no rule
    // of its own and takes the cell's width.
    final left = rect.left + visual.indicatorInset;
    final width = rect.width > 2 * visual.indicatorInset ? rect.width - 2 * visual.indicatorInset : rect.width;
    final barRect = Rect.fromLTRB(left, rect.top, left + width, rect.bottom);
    if (visual.indicatorHeight case final height?) {
      // The ink bar: a rule of its own height pinned to the strip's bottom
      // edge, as wide as the cell lets it be.
      if (_indicatorPlaced) {
        return AnimatedPositioned(
          left: left,
          width: width,
          bottom: 0,
          height: height,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: child,
        );
      }
      return Positioned(left: left, width: width, bottom: 0, height: height, child: child);
    }
    if (_indicatorPlaced) {
      return AnimatedPositioned.fromRect(rect: barRect, duration: duration, curve: Curves.easeOutCubic, child: child);
    }
    return Positioned.fromRect(rect: barRect, child: child);
  }

  Widget _cell({required int index, required _StripVisual visual, required TextStyle labelStyle}) {
    return _StripCell(
      key: _cellKeys[index],
      tab: widget.tabs[index],
      selected: index == _selectedIndex,
      stripActive: _active,
      visual: visual,
      labelStyle: labelStyle,
      focusNode: _focusNodes[index],
      onKeyEvent: (node, event) => _handleKey(index, event),
      onSelect: () {
        _reveal(index);
        widget.select?.call(index);
      },
    );
  }
}

extension on BuildContext {
  /// The resolved theme, read the way every component here does.
  PureTheme get themeFor => PureTheme.of(this);
}

/// One cell: interaction states (hover, pressed, focus, disabled), the leading
/// icon, and the semantics that name the tab for a screen reader.
class _StripCell extends StatefulWidget {
  const new({
    required this.tab,
    required this.selected,
    required this.stripActive,
    required this.visual,
    required this.labelStyle,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onSelect,
    super.key,
  });

  final PureTab tab;

  final bool selected;

  /// Whether the strip is live; an inert strip greys every cell out.
  final bool stripActive;

  final _StripVisual visual;

  final TextStyle labelStyle;

  final FocusNode focusNode;

  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  final VoidCallback onSelect;

  @override
  State<_StripCell> createState() => _StripCellState();
}

class _StripCellState extends State<_StripCell> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.stripActive && widget.tab.enabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    final tab = widget.tab;
    final enabled = _enabled;
    final selected = widget.selected && widget.stripActive;
    final color = visual.content(theme, selected: selected, hovered: _hovered, pressed: _pressed, enabled: enabled);
    // The tint rides an unselected cell only: the indicator already paints the
    // chosen one, and a hover over it would muddy the accent.
    final tint = !selected && enabled
        ? (_pressed
              ? visual.pressedTint(theme)
              : _hovered
              ? visual.hoverTint(theme)
              : null)
        : null;

    final label = Text(
      tab.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.labelStyle.copyWith(color: color),
    );
    final icon = tab.icon;
    final content = icon == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: visual.iconSize, color: color),
              SizedBox(width: visual.iconLabelGap),
              Flexible(child: label),
            ],
          );

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: enabled,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) => widget.onKeyEvent(node, event),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (_) {
                  widget.focusNode.requestFocus();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: enabled ? widget.onSelect : null,
          child: Semantics(
            button: true,
            selected: widget.selected,
            enabled: enabled,
            label: tab.label,
            child: ExcludeSemantics(
              child: AnimatedScale(
                // The TV answer: the focused cell grows a touch, and the ring
                // below names it for keyboard and remote users alike.
                scale: _focused ? 1.04 : 1,
                duration: theme.duration,
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: theme.duration,
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(horizontal: visual.cellPadding),
                  decoration: BoxDecoration(color: tint, borderRadius: visual.cellRadius),
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: visual.cellRadius,
                          border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
                        )
                      : null,
                  constraints: BoxConstraints(minHeight: _stripHeight - 2 * visual.inset),
                  alignment: AlignmentDirectional.center,
                  child: AnimatedOpacity(
                    duration: theme.duration,
                    opacity: enabled ? 1 : visual.disabledAlpha,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page area behind a tab strip.
///
/// The content is a stack of the caller's pages, with only the selected one
/// visible. This is intentionally shared by every language: it owns no visual
/// component, only the page-stack mechanics the routers already rely on.
class PureTabView extends StatelessWidget {
  /// A tab view over [pages].
  const new({required this.index, required this.pages, this.onIndexChanged, super.key});

  /// The visible page index.
  final int index;

  /// The page widgets.
  final List<Widget> pages;

  /// Called when a swipe/page change selects another index. The stack itself
  /// never swipes — the strip above it reports the choice — so this is here
  /// for the callers that drive the index from their own gesture.
  final ValueChanged<int>? onIndexChanged;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    return IndexedStack(index: index.clamp(0, pages.length - 1), sizing: StackFit.expand, children: pages);
  }
}
