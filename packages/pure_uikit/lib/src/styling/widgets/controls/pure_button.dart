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
    final child = _content(context, iconOnly: false);

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
        icon: icon == null ? null : Icon(icon, size: 16),
        child: variant == ButtonVariant.danger
            ? Text(label, style: TextStyle(color: enabled ? theme.colors.error : null))
            : Text(label),
      ),
      PureDesignLanguage.macos => macos.PushButton(
        onPressed: enabled ? onPressed : null,
        controlSize: switch (size) {
          ControlSize.sm => macos.ControlSize.small,
          ControlSize.md => macos.ControlSize.regular,
          ControlSize.lg => macos.ControlSize.large,
        },
        secondary: variant != ButtonVariant.primary,
        child: child,
      ),
      PureDesignLanguage.cupertino => cupertino.CupertinoButton(
        onPressed: enabled ? onPressed : null,
        color: variant == ButtonVariant.primary ? cupertino.CupertinoColors.activeBlue : null,
        child: child,
      ),
      // The library's own button, its variant and size tables carrying the
      // token kinds (`secondary` maps to `outline`: the token's secondary is a
      // bordered supporting action, which is what forui's `outline` paints).
      // The inline [style] has no slot on a widget the fork paints itself and
      // rides nowhere; the tooltip is the library's own bubble.
      PureDesignLanguage.forui => _forui(theme),
      // The library's own `GlassButton`: the surface is the fork's, the
      // content and the wraps composed from its own parts. `focusNode` /
      // `autofocus` have no parameter on the fork and are ignored rather than
      // emulated by a second focus node that would not drive activation; so
      // are `selected` and the inline [style] — a widget that paints its own
      // surface takes no overlay.
      PureDesignLanguage.glass => _glass(theme),
      // The library's own button — a soft embossed plane whose pressed state
      // is the style's whole answer to a tap. `focusNode`/`autofocus` have no
      // parameter to land on and are ignored, as are `selected` and the inline
      // [style]; `expand` and `tooltip` are expressed through wraps that do
      // not change the shadow surface.
      PureDesignLanguage.neumorphic => _neumorphic(theme),
      // The fork's own button: press and surface in `WButton`, whose focus
      // handling lives inside `WAnchor` — it creates and tracks its own node,
      // so [focusNode]/[autofocus] have no slot to land on and are ignored
      // rather than faked with a wrapper that would steal focus from the node
      // that actually handles activation. The fork paints its own `disabled:`
      // state from the same flag that nulls the callback — one source of
      // truth.
      PureDesignLanguage.wind => _wind(theme),
      // Yaru draws buttons with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different button.
      PureDesignLanguage.material || PureDesignLanguage.yaru => switch (variant) {
        ButtonVariant.primary => FilledButton(onPressed: enabled ? onPressed : null, child: child),
        ButtonVariant.secondary => OutlinedButton(onPressed: enabled ? onPressed : null, child: child),
        ButtonVariant.danger => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(backgroundColor: theme.colors.error),
          child: child,
        ),
        ButtonVariant.ghost => TextButton(onPressed: enabled ? onPressed : null, child: child),
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

  /// The glass branch: the library's `GlassButton` with its content composed
  /// around it, full-width and tooltip wraps included.
  Widget _glass(PureTheme theme) {
    Widget button = glass.GlassButton(
      onPressed: onPressed != null && !loading ? onPressed : null,
      padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
      child: _glassContent(theme),
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

  /// The neumorphic branch: the library's `NeuButton`, its content padded to
  /// the token geometry inside the embossed plane.
  Widget _neumorphic(PureTheme theme) {
    Widget button = neu.NeuButton(
      onPressed: onPressed != null && !loading ? onPressed : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: _neumorphicContent(theme),
      ),
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

  /// The wind branch: the fork's `WButton`, `expand` spelled in its own width
  /// class and the tooltip as the accessible name plus the shared bubble.
  Widget _wind(PureTheme theme) {
    final interactive = onPressed != null && !loading;
    Widget button = wind.WButton(
      onTap: interactive ? onPressed : null,
      disabled: !interactive,
      className: expand ? 'w-full' : null,
      semanticLabel: tooltip,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: _windContent(theme),
      ),
    );
    final hint = tooltip;
    if (hint != null) {
      button = Tooltip(message: hint, child: button);
    }
    return button;
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

  /// The glass button's inside: the label, an optional leading glyph, and a
  /// loading plate built out of the library's own surface part — the library
  /// ships no button spinner of its own.
  Widget _glassContent(PureTheme theme) {
    final step = theme.text.label.fontSize ?? 14;
    if (loading) {
      return glass.GlassContainer(
        width: step,
        height: step,
        child: Center(
          child: SizedBox.square(
            dimension: step * 0.5,
            child: ColoredBox(color: theme.colors.primary),
          ),
        ),
      );
    }
    return _plainContent(theme, step);
  }

  /// The neumorphic button's inside: the label, an optional leading glyph, and
  /// a thin line of the library's own progress face while [loading] — the
  /// library gives `NeuButton` a child and nothing else, and ships no spinner.
  Widget _neumorphicContent(PureTheme theme) {
    final step = theme.text.label.fontSize ?? 14;
    if (loading) {
      return SizedBox(
        width: step,
        child: neu.NeuProgressBar(height: 2, progressColor: theme.colors.primary),
      );
    }
    return _plainContent(theme, step);
  }

  /// The wind button's inside: the label, an optional leading glyph, and the
  /// library's documented skeleton affordance (`animate-pulse`) while
  /// [loading] — the fork ships no spinner, and it has no transform parser to
  /// spin one with.
  Widget _windContent(PureTheme theme) {
    final step = theme.text.label.fontSize ?? 14;
    if (loading) {
      return SizedBox.square(
        dimension: step,
        child: wind.WDiv(className: 'w-full h-full rounded-full animate-pulse', backgroundColor: theme.colors.primary),
      );
    }
    return _plainContent(theme, step);
  }

  /// Label and optional leading glyph, the shape every one of the four
  /// composed branches shares once its loading face is decided.
  Widget _plainContent(PureTheme theme, double step) {
    final text = Text(label, overflow: TextOverflow.ellipsis);
    if (icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: step),
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
  Widget _content(BuildContext context, {required bool iconOnly}) {
    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }
    if (iconOnly) {
      return Icon(icon);
    }
    if (icon == null) {
      return Text(label);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)]);
  }
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
    final glyph = Icon(icon, size: 18, semanticLabel: tooltip);

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
      PureDesignLanguage.macos => macos.MacosIconButton(icon: glyph, onPressed: active ? onPressed : null),
      PureDesignLanguage.cupertino => cupertino.CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: active ? onPressed : null,
        child: glyph,
      ),
      // An icon-only control is forui's own variant, laid out by the library —
      // squeezing the token square around a full `FButton` clipped the glyph,
      // so this language does not use that geometry.
      PureDesignLanguage.forui => _foruiIcon(theme, active),
      // The library's own icon button: a frosted square carrying the glyph.
      PureDesignLanguage.glass => glass.GlassIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        size: theme.token.scale.controlHeight,
        shape: BoxShape.rectangle,
        borderRadius: theme.button.borderRadius,
        tooltip: tooltip,
      ),
      // The library's own icon button: the same embossed plane as NeuButton.
      PureDesignLanguage.neumorphic => neu.NeuIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        size: theme.token.scale.controlHeight,
        tooltip: tooltip,
      ),
      // The fork's one button shape carries the glyph, the accessible name on
      // the button itself (`WButton` has no icon variant either).
      PureDesignLanguage.wind => _windIcon(theme, active),
      PureDesignLanguage.yaru => yaru.YaruIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        isSelected: selected ? true : null,
      ),
      PureDesignLanguage.material => IconButton(icon: glyph, tooltip: tooltip, onPressed: active ? onPressed : null),
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
  /// name on the button itself.
  Widget _windIcon(PureTheme theme, bool active) {
    final step = theme.text.label.fontSize ?? 14;
    return wind.WButton(
      onTap: active ? onPressed : null,
      disabled: !active,
      semanticLabel: tooltip,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.button.paddingInline, vertical: theme.token.scale.sizes.sm),
        child: Icon(icon, size: step),
      ),
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
