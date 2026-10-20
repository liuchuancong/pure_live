import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/recipe.dart';
import 'package:pure_uikit/src/styling/style/style.dart';
import 'package:pure_uikit/src/styling/widgets/overlays/pure_tooltip.dart';
import 'package:yaru/yaru.dart' as yaru;

/// A button in the token model: one widget, every theme and density.
///
/// It carries only semantics (`variant`, `size`, `enabled`, `loading`); its
/// appearance comes straight from the active design language's own widget
/// library. There is no adapter and no spec in between: [build] switches on
/// `UiConfig.language` and constructs the library's real component directly —
/// `FluentButton` under fluent, `PushButton` under macOS, `CupertinoButton`
/// under cupertino, `FButton` under forui, `GlassButton` under glass,
/// `NeuButton` under neumorphic, `WButton` under wind — so what the user sees
/// is exactly what that library's own documentation shows. Where a library
/// ships nothing (glass and neumorphic ship no spinner, wind no focus slot),
/// the branch composes the missing piece from that library's own parts rather
/// than borrowing another language's. Switching `UiConfig.language` re-skins
/// every button.
///
/// [ControlSize] is honoured by every branch: the token's three steps map to
/// the library's own size knob where it has one (fluent's `FluentButtonSize`,
/// macOS's `ControlSize`, forui's `FButtonSizeVariant`) and to the height,
/// padding and label size it takes as numbers elsewhere. No language renders
/// sm, md and lg the same.
///
/// ## Platform-only knobs
///
/// A parameter that only one design language can honour is named after that
/// language (`fluentShape`) and its doc starts with "`<Language>` only:". The
/// prefix is the whole convention: it is grep-able, it reads at every call
/// site as "this no-ops elsewhere", and it keeps the shared semantics
/// (`variant`, `size`, `onPressed`) free of per-language spellings. A knob
/// belongs here only when the language's own widget exposes it natively; it is
/// ignored, not approximated, under every other language.
class PureButton extends StatelessWidget {
  /// A button labelled [label].
  const new({
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ControlSize.md,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    this.tooltip,
    this.style,
    this.fluentShape,
    super.key,
  });

  /// The button text.
  final String label;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// An optional leading icon.
  final IconData? icon;

  /// The semantic kind.
  final ButtonVariant variant;

  /// The size step.
  final ControlSize size;

  /// Whether a spinner replaces the content and input is rejected.
  final bool loading;

  /// Whether the button fills its parent's width.
  final bool expand;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Hover/long-press hint and the accessible description of the action.
  final String? tooltip;

  /// An inline style override (the `style=` attribute).
  final Style? style;

  /// Fluent only: the corner treatment passed to `FluentButton.shape`.
  /// Ignored under every other language.
  final f2.FluentButtonShape? fluentShape;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final enabled = onPressed != null && !loading;
    final m = _metrics(theme, size);
    // An empty label means the caller wants the glyph alone: laying out a label
    // slot for it added the icon-to-label gap around a string that is not there.
    final child = _tint(_content(context, iconOnly: icon != null && label.isEmpty, metrics: m), theme);

    final button = switch (language) {
      PureDesignLanguage.fluent => f2.FluentButton(
        onPressed: enabled ? onPressed : null,
        appearance: switch (variant) {
          ButtonVariant.primary => f2.FluentButtonAppearance.primary,
          ButtonVariant.secondary => f2.FluentButtonAppearance.secondary,
          // Fluent has no destructive appearance; the label carries the colour.
          ButtonVariant.danger => f2.FluentButtonAppearance.secondary,
          ButtonVariant.ghost => f2.FluentButtonAppearance.subtle,
        },
        size: switch (size) {
          ControlSize.sm => f2.FluentButtonSize.small,
          ControlSize.md => f2.FluentButtonSize.medium,
          ControlSize.lg => f2.FluentButtonSize.large,
        },
        shape: fluentShape ?? f2.FluentButtonShape.rounded,
        icon: icon == null ? null : Icon(icon, size: m.icon),
        // The library's own label style would drop the theme's family and size
        // step, so the label is built here and only the danger tint is added.
        child: variant == ButtonVariant.danger
            ? Text(label, style: _labelStyle(theme, m).copyWith(color: enabled ? theme.colors.error : null))
            : Text(label, style: _labelStyle(theme, m)),
      ),
      // macOS fills the default action's button with the accent (a white
      // capsule is the library's plain answer, which reads as no primary at
      // all); the destructive keeps the label colour, like every other
      // language's danger.
      PureDesignLanguage.macos => macos.PushButton(
        onPressed: enabled ? onPressed : null,
        controlSize: switch (size) {
          ControlSize.sm => macos.ControlSize.small,
          ControlSize.md => macos.ControlSize.regular,
          ControlSize.lg => macos.ControlSize.large,
        },
        color: variant == ButtonVariant.primary ? theme.colors.primary : null,
        secondary: variant != ButtonVariant.primary,
        child: child,
      ),
      // iOS fills the primary blue with a white label, greys the secondary,
      // and leaves ghost and danger as tinted text — the system's own three
      // button weights. The size step drives the button's own minSize and
      // padding; the library's 44-point default is a touch target, not a
      // size the token should ignore.
      PureDesignLanguage.cupertino => cupertino.CupertinoButton(
        onPressed: enabled ? onPressed : null,
        minimumSize: Size(m.height, m.height),
        padding: EdgeInsets.symmetric(horizontal: m.padH),
        color: switch (variant) {
          ButtonVariant.primary => theme.colors.primary,
          ButtonVariant.secondary => theme.colors.bgContainer,
          _ => null,
        },
        child: child,
      ),
      // The library's own button, its variant and size tables carrying the
      // token kinds (`secondary` maps to `outline`: the token's secondary is a
      // bordered supporting action, which is what forui's `outline` paints).
      // The inline [style] has no slot on a widget the fork paints itself and
      // rides nowhere; the tooltip is the library's own bubble.
      PureDesignLanguage.forui => _forui(theme),
      // The library's own `GlassButton`, through its own icon/label/loading
      // slots and its own height. Left unbounded the frosted plate fills its
      // parent's width (the fork's container aligns to stretch), so a
      // non-expanding button is pinned to its content by a minimum Row.
      PureDesignLanguage.glass => _glass(theme, m),
      // The library's own button — a soft embossed plane whose pressed state
      // is the style's whole answer to a tap. The size step lands on the
      // plane's height and padding; the loading face is the library's own
      // ring. `focusNode`/`autofocus` have no parameter to land on and are
      // ignored, as are `selected` and the inline [style]; `expand` and
      // `tooltip` are expressed through wraps that do not change the shadow
      // surface.
      PureDesignLanguage.neumorphic => _neumorphic(theme, m),
      // The fork's own button: press and surface in `WButton`. It is a
      // utility-class control — with no `className` it paints nothing at all,
      // so the variant and the size step are spelled in its own dialect here.
      // Its focus handling lives inside `WAnchor`, so [focusNode]/[autofocus]
      // have no slot to land on and are ignored rather than faked with a
      // wrapper that would steal focus from the node that actually handles
      // activation. The fork paints its own `disabled:` state from the same
      // flag that nulls the callback — one source of truth.
      PureDesignLanguage.wind => _wind(theme, m),
      // Yaru draws buttons with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different button. The size step maps
      // onto the Material button's own minimum height, density and label size.
      PureDesignLanguage.material || PureDesignLanguage.yaru => switch (variant) {
        ButtonVariant.primary => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: _materialStyle(theme, m),
          child: child,
        ),
        ButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: _materialStyle(theme, m),
          child: child,
        ),
        ButtonVariant.danger => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: _materialStyle(theme, m).copyWith(backgroundColor: WidgetStatePropertyAll(theme.colors.error)),
          child: child,
        ),
        ButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          style: _materialStyle(theme, m),
          child: child,
        ),
      },
    };

    if (tooltip != null &&
        language != PureDesignLanguage.forui &&
        language != PureDesignLanguage.glass &&
        language != PureDesignLanguage.neumorphic &&
        language != PureDesignLanguage.wind) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  /// The Material family's size mapping: the height, density and label size
  /// the token's step asks for, in the library's own style object.
  static ButtonStyle _materialStyle(PureTheme theme, _Metrics m) => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, m.height)),
    visualDensity: switch (m.size) {
      ControlSize.sm => VisualDensity.compact,
      ControlSize.md => const VisualDensity(horizontal: -0.5, vertical: -0.5),
      ControlSize.lg => VisualDensity.standard,
    },
    textStyle: WidgetStatePropertyAll(theme.text.label.copyWith(fontSize: m.fontSize, fontWeight: FontWeight.w500)),
  );

  /// The forui branch: the library's `FButton` under its own `FTooltip`.
  Widget _forui(PureTheme theme) {
    Widget button = forui.FButton(
      onPress: onPressed != null && !loading ? onPressed : null,
      variant: _foruiVariant(variant),
      size: _foruiSize(size),
      focusNode: focusNode,
      autofocus: autofocus,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      child: _foruiContent(theme),
    );
    final hint = tooltip;
    if (hint != null) {
      button = forui.FTooltip(tipBuilder: (context, controller) => Text(hint), child: button);
    }
    return button;
  }

  /// The glass branch: the library's `GlassButton` through its own slots —
  /// the primary takes the accent as its frosted colour, the rest keep the
  /// library's white plate.
  Widget _glass(PureTheme theme, _Metrics m) {
    final fg = _foreground(theme);
    Widget button = glass.GlassButton(
      onPressed: onPressed != null && !loading ? onPressed : null,
      isLoading: loading,
      loadingWidget: SizedBox.square(
        dimension: m.fontSize,
        child: CircularProgressIndicator(strokeWidth: 2, color: fg ?? theme.colors.text),
      ),
      height: m.height,
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: m.padH + 6),
      borderRadius: m.height / 2 > theme.button.borderRadius ? theme.button.borderRadius : m.height / 2,
      color: variant == ButtonVariant.primary ? theme.colors.primary : Colors.white,
      icon: icon == null || loading ? null : Icon(icon, size: m.icon, color: fg),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: m.fontSize, fontWeight: FontWeight.w600),
      ),
    );
    if (!expand) {
      button = Row(mainAxisSize: MainAxisSize.min, children: [button]);
    }
    final hint = tooltip;
    if (hint != null) {
      button = PureTooltip(message: hint, child: button);
    }
    return button;
  }

  /// The neumorphic branch: the library's `NeuButton`, its height and padding
  /// from the token's size step, its loading face the library's own ring.
  Widget _neumorphic(PureTheme theme, _Metrics m) {
    Widget button = neu.NeuButton(
      onPressed: onPressed != null && !loading ? onPressed : null,
      height: m.height,
      padding: EdgeInsets.symmetric(horizontal: m.padH + 4),
      child: loading
          ? neu.NeuCircularProgress(size: m.fontSize, strokeWidth: 2, progressColor: theme.colors.primary)
          : _plainContent(theme, m.fontSize, icon: m.icon),
    );
    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    final hint = tooltip;
    if (hint != null) {
      button = PureTooltip(message: hint, child: button);
    }
    return button;
  }

  /// The wind branch: the fork's `WButton`, its variant and size spelled in
  /// the utility classes the fork parses, the accessible name and the shared
  /// bubble beside them.
  Widget _wind(PureTheme theme, _Metrics m) {
    final interactive = onPressed != null && !loading;
    final surface = switch (variant) {
      ButtonVariant.primary => 'bg-blue-600 text-white rounded hover:bg-blue-700',
      ButtonVariant.secondary => 'bg-white text-gray-900 border border-gray-400 rounded hover:bg-gray-100',
      ButtonVariant.danger => 'bg-red-600 text-white rounded hover:bg-red-700',
      ButtonVariant.ghost => 'text-blue-600 rounded hover:bg-gray-100',
    };
    final shape = switch (m.size) {
      ControlSize.sm => 'px-2.5 py-0.5 text-xs',
      ControlSize.md => 'px-3.5 py-1.5 text-sm',
      ControlSize.lg => 'px-4.5 py-2.5 text-base',
    };
    final fg = _foreground(theme);
    Widget button = wind.WButton(
      onTap: interactive ? onPressed : null,
      disabled: !interactive,
      className: expand ? 'w-full $surface $shape' : '$surface $shape',
      semanticLabel: tooltip,
      child: loading
          ? SizedBox.square(
              dimension: m.fontSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg ?? theme.colors.text),
            )
          : _plainContent(theme, m.fontSize, icon: m.icon),
    );
    final hint = tooltip;
    if (hint != null) {
      button = Tooltip(message: hint, child: button);
    }
    return button;
  }

  /// The label colour a filled or tinted variant owes its content, or null
  /// when the library's own foreground is already right.
  Color? _foreground(PureTheme theme) {
    final language = theme.config.language;
    return switch (variant) {
      ButtonVariant.primary =>
        language == PureDesignLanguage.glass || language == PureDesignLanguage.wind ? theme.colors.onPrimary : null,
      ButtonVariant.danger => language == PureDesignLanguage.wind ? theme.colors.onPrimary : theme.colors.error,
      ButtonVariant.ghost => language == PureDesignLanguage.wind ? null : theme.colors.primary,
      ButtonVariant.secondary => null,
    };
  }

  /// Tints the shared [child] (the macOS, Cupertino and Material branches)
  /// for the variants whose surface the token model fills: a primary label
  /// sits on the accent, a danger label carries the error colour.
  Widget _tint(Widget child, PureTheme theme) {
    final color = switch (variant) {
      ButtonVariant.primary => switch (theme.config.language) {
        PureDesignLanguage.macos || PureDesignLanguage.cupertino => theme.colors.onPrimary,
        _ => null,
      },
      ButtonVariant.danger => theme.config.language == PureDesignLanguage.cupertino ? theme.colors.error : null,
      ButtonVariant.ghost || ButtonVariant.secondary => null,
    };
    if (color == null) return child;
    return DefaultTextStyle.merge(
      style: TextStyle(color: color),
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: child,
      ),
    );
  }

  /// The forui button's inside: the label, an optional leading glyph, and the
  /// library's own spinner while [loading] (forui ships a progress face of
  /// its own).
  Widget _foruiContent(PureTheme theme) {
    final step = theme.text.label.fontSize ?? 14;
    if (loading) {
      return SizedBox.square(
        dimension: step,
        child: forui.FProgress(
          style: forui.FProgressStyleDelta.delta(
            constraints: BoxConstraints.tightFor(width: step, height: step),
          ),
        ),
      );
    }
    return _plainContent(theme, step);
  }

  /// Label and optional leading glyph, the shape every one of the four
  /// composed branches shares once its loading face is decided.
  Widget _plainContent(PureTheme theme, double step, {double? icon}) {
    final text = Text(label, overflow: TextOverflow.ellipsis, style: theme.text.label);
    if (this.icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(this.icon, size: icon ?? step),
        SizedBox(width: theme.token.scale.sizes.xs),
        Flexible(child: text),
      ],
    );
  }

  /// The token variant as forui's closest kind. `secondary` maps to `outline`:
  /// the token model's secondary is a bordered supporting action, which is what
  /// forui's `outline` paints, while forui's own `secondary` is a muted fill
  /// the token has no role for.
  static forui.FButtonVariant _foruiVariant(ButtonVariant variant) => switch (variant) {
    ButtonVariant.primary => forui.FButtonVariant.primary,
    ButtonVariant.secondary => forui.FButtonVariant.outline,
    ButtonVariant.ghost => forui.FButtonVariant.ghost,
    ButtonVariant.danger => forui.FButtonVariant.destructive,
  };

  static forui.FButtonSizeVariant _foruiSize(ControlSize size) => switch (size) {
    ControlSize.sm => forui.FButtonSizeVariant.sm,
    ControlSize.md => forui.FButtonSizeVariant.md,
    ControlSize.lg => forui.FButtonSizeVariant.lg,
  };

  /// The button's inside: optional leading icon, label, or a spinner while
  /// [loading].
  Widget _content(BuildContext context, {required bool iconOnly, required _Metrics metrics}) {
    final labelStyle = _labelStyle(PureTheme.of(context), metrics);
    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: metrics.fontSize, child: const CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(label, style: labelStyle),
        ],
      );
    }
    if (iconOnly) {
      return Icon(icon, size: metrics.icon);
    }
    if (icon == null) {
      return Text(label, style: labelStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: metrics.icon),
        SizedBox(width: metrics.size == ControlSize.sm ? 4 : 6),
        Text(label, style: labelStyle),
      ],
    );
  }
}

/// The label a button draws with: the theme's label style at the size step this
/// control asked for.
///
/// A bare `Text(label)` inherits whatever the surrounding library decides its
/// text should be, which silently dropped two things the design system owns —
/// the family the viewer picked in the appearance settings, and the size step —
/// so every button rendered in the platform font at one size.
TextStyle _labelStyle(PureTheme theme, _Metrics metrics) => theme.text.label.copyWith(fontSize: metrics.fontSize);

/// The token's three size steps, read out of the resolved theme: the control
/// height, the label size, the horizontal padding and the glyph size a branch
/// that takes numbers (rather than the library's own size enum) applies.
final class _Metrics {
  const new({required this.size, required this.height, required this.fontSize, required this.padH, required this.icon});

  final ControlSize size;
  final double height;
  final double fontSize;
  final double padH;
  final double icon;
}

/// The token's three steps, read out of the resolved theme.
_Metrics _metrics(PureTheme theme, ControlSize size) {
  final scale = theme.token.scale;
  final label = theme.text.label.fontSize ?? 14;
  return switch (size) {
    ControlSize.sm => _Metrics(size: size, height: scale.controlHeightSM, fontSize: label - 1, padH: 10, icon: 14),
    ControlSize.md => _Metrics(size: size, height: scale.controlHeight, fontSize: label, padH: 14, icon: 16),
    ControlSize.lg => _Metrics(size: size, height: scale.controlHeightLG, fontSize: label + 2, padH: 18, icon: 18),
  };
}

/// A square icon-only button — the Ant `Button` icon variant. It always carries
/// a [tooltip] (an icon alone is not a readable label) and takes the same
/// `variant` / `size` semantics as [PureButton], so it re-skins identically.
class PureIconButton extends StatelessWidget {
  /// An icon button.
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.variant = ButtonVariant.ghost,
    this.size = ControlSize.md,
    this.selected = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  /// The glyph to draw.
  final IconData icon;

  /// The tooltip and accessibility label.
  final String tooltip;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// The semantic kind.
  final ButtonVariant variant;

  /// The size step; drives the square side length.
  final ControlSize size;

  /// Whether the control shows a mode that is currently on.
  final bool selected;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final active = enabled && onPressed != null;
    final m = _metrics(theme, size);
    final glyph = Icon(icon, size: m.icon, semanticLabel: tooltip);

    final button = switch (language) {
      PureDesignLanguage.fluent => f2.FluentButton.icon(
        icon: glyph,
        semanticLabel: tooltip,
        onPressed: active ? onPressed : null,
        appearance: switch (variant) {
          ButtonVariant.primary => f2.FluentButtonAppearance.primary,
          ButtonVariant.secondary => f2.FluentButtonAppearance.secondary,
          ButtonVariant.danger => f2.FluentButtonAppearance.secondary,
          ButtonVariant.ghost => f2.FluentButtonAppearance.subtle,
        },
        size: switch (size) {
          ControlSize.sm => f2.FluentButtonSize.small,
          ControlSize.md => f2.FluentButtonSize.medium,
          ControlSize.lg => f2.FluentButtonSize.large,
        },
      ),
      PureDesignLanguage.macos => macos.MacosIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        boxConstraints: BoxConstraints.tightFor(width: m.height, height: m.height),
      ),
      PureDesignLanguage.cupertino => cupertino.CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size(m.height, m.height),
        onPressed: active ? onPressed : null,
        child: glyph,
      ),
      // An icon-only control is forui's own variant, laid out by the library —
      // squeezing the token square around a full `FButton` clipped the glyph,
      // so this language does not use that geometry.
      PureDesignLanguage.forui => _foruiIcon(theme, active),
      // The library's own icon button: a frosted square carrying the glyph,
      // sized to the token's step.
      PureDesignLanguage.glass => glass.GlassIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        size: m.height,
        shape: BoxShape.rectangle,
        borderRadius: theme.button.borderRadius,
        tooltip: tooltip,
      ),
      // The library's own icon button: the same embossed plane as NeuButton.
      PureDesignLanguage.neumorphic => neu.NeuIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        size: m.height,
        tooltip: tooltip,
      ),
      // The fork's one button shape carries the glyph, the accessible name on
      // the button itself (`WButton` has no icon variant either) and the
      // surface in its own utility classes.
      PureDesignLanguage.wind => _windIcon(theme, m, active),
      PureDesignLanguage.yaru => yaru.YaruIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        isSelected: selected ? true : null,
        constraints: BoxConstraints.tightFor(width: m.height, height: m.height),
      ),
      PureDesignLanguage.material => IconButton(
        icon: glyph,
        tooltip: tooltip,
        onPressed: active ? onPressed : null,
        visualDensity: switch (size) {
          ControlSize.sm => VisualDensity.compact,
          ControlSize.md => const VisualDensity(horizontal: -0.5, vertical: -0.5),
          ControlSize.lg => VisualDensity.standard,
        },
      ),
    };

    return Tooltip(message: tooltip, child: button);
  }

  /// The forui icon button: the library's own `FButton.icon`.
  Widget _foruiIcon(PureTheme theme, bool active) {
    final step = theme.text.label.fontSize ?? 14;
    return forui.FTooltip(
      tipBuilder: (context, controller) => Text(tooltip),
      child: forui.FButton.icon(
        onPress: active ? onPressed : null,
        variant: PureButton._foruiVariant(variant),
        size: PureButton._foruiSize(size),
        selected: selected,
        focusNode: focusNode,
        autofocus: autofocus,
        child: Icon(icon, size: step, semanticLabel: tooltip),
      ),
    );
  }

  /// The wind icon button: the glyph in `WButton`'s child slot, the accessible
  /// name on the button itself, the plate in the fork's own classes.
  Widget _windIcon(PureTheme theme, _Metrics m, bool active) {
    final surface = switch (variant) {
      ButtonVariant.primary => 'bg-blue-600 text-white rounded hover:bg-blue-700',
      ButtonVariant.secondary => 'bg-white text-gray-900 border border-gray-400 rounded hover:bg-gray-100',
      ButtonVariant.danger => 'bg-red-600 text-white rounded hover:bg-red-700',
      ButtonVariant.ghost => 'text-gray-900 rounded hover:bg-gray-100',
    };
    return wind.WButton(
      onTap: active ? onPressed : null,
      disabled: !active,
      className:
          '$surface ${switch (m.size) {
            ControlSize.sm => 'p-1',
            ControlSize.md => 'p-2',
            ControlSize.lg => 'p-2.5',
          }}',
      semanticLabel: tooltip,
      child: Icon(icon, size: m.icon),
    );
  }
}

/// A standalone circular spinner built from the active language's own progress
/// control where it has one and Flutter's official Material spinner elsewhere.
class PureSpinner extends StatelessWidget {
  /// A spinner.
  const new({this.size = 18, this.color, super.key});

  /// The diameter.
  final double size;

  /// An optional colour override.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final tint = color ?? theme.colors.primary;
    final language = theme.config.language;

    final spinner = switch (language) {
      PureDesignLanguage.fluent => f2.FluentSpinner(
        style: f2.FluentSpinnerStyle.from(diameter: size, indicatorColor: tint),
      ),
      PureDesignLanguage.macos => macos.ProgressCircle(radius: size / 2),
      PureDesignLanguage.cupertino => cupertino.CupertinoActivityIndicator(radius: size / 2, color: tint),
      PureDesignLanguage.forui => const forui.FCircularProgress(),
      PureDesignLanguage.neumorphic => neu.NeuCircularProgress(size: size, strokeWidth: 2, progressColor: tint),
      PureDesignLanguage.yaru => yaru.YaruCircularProgressIndicator(strokeWidth: 2, color: tint),
      PureDesignLanguage.material ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.wind => CircularProgressIndicator(strokeWidth: 2, color: tint),
    };

    return SizedBox.square(dimension: size, child: spinner);
  }
}
