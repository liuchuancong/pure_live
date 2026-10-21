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
import 'package:pure_uikit/src/styling/widgets/overlays/pure_dialog_action_scope.dart';
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
    // A dialog's footer is a different control in two of the libraries: iOS
    // draws a `CupertinoDialogAction` band, macOS an alert row of large buttons.
    final dialogAction = PureDialogActionScope.maybeOf(context);
    final inDialogAction = dialogAction != null;
    // An empty label means the caller wants the glyph alone: laying out a label
    // slot for it added the icon-to-label gap around a string that is not there.
    final plain = _content(context, iconOnly: icon != null && label.isEmpty, metrics: m);
    final child = _tint(plain, theme, enabled);

    final button = switch (language) {
      PureDesignLanguage.fluent => f2.FluentButton(
        onPressed: enabled ? onPressed : null,
        focusNode: focusNode,
        autofocus: autofocus,
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
        // The glyph goes in bare: the library sizes it per its own button size
        // (`iconSize` 20/24), and the token's 14/16/18 made every Fluent icon
        // look a size step smaller than WinUI's.
        icon: icon == null ? null : Icon(icon),
        // The library's own label style would drop the theme's family and size
        // step, so the label is built here and only the danger tint is added.
        child: variant == ButtonVariant.danger
            ? Text(label, style: _labelStyle(theme, m).copyWith(color: enabled ? theme.colors.error : null))
            : Text(label, style: _labelStyle(theme, m)),
      ),
      // macOS fills the default action's button with the accent (a white
      // capsule is the library's plain answer, which reads as no primary at
      // all); the destructive keeps the label colour, like every other
      // language's danger. In a dialog's action row the library's own metric is
      // the large step, whatever step the caller asked for.
      PureDesignLanguage.macos => macos.PushButton(
        onPressed: enabled ? onPressed : null,
        controlSize: inDialogAction
            ? macos.ControlSize.large
            : switch (size) {
                ControlSize.sm => macos.ControlSize.small,
                ControlSize.md => macos.ControlSize.regular,
                ControlSize.lg => macos.ControlSize.large,
              },
        color: variant == ButtonVariant.primary ? theme.colors.primary : null,
        secondary: variant != ButtonVariant.primary,
        child: _macosChild(theme, child, enabled),
      ),
      // iOS fills the primary blue with a white label, greys the secondary,
      // and leaves ghost and danger as tinted text — the system's own three
      // button weights. The size step is handed to the library's own
      // `sizeStyle`, which carries the platform's min size, padding and corner
      // radius per step (28/32/44 and the 16pt vertical padding); passing the
      // token's numbers instead flattened all three steps to one height and
      // dropped the padding the fork computes.
      // In a dialog the library's own action band replaces the button: iOS
      // separates the footer with hairlines, sets the default choice in semibold
      // and keeps the destructive red — none of which a `CupertinoButton` placed
      // there draws, and its white primary label would sit on the sheet's own
      // white. The un-tinted content goes in so the widget answers for the
      // colour; it has no focus slot, so the node is the ordinary button's.
      PureDesignLanguage.cupertino =>
        inDialogAction
            ? cupertino.CupertinoDialogAction(
                onPressed: enabled ? onPressed : null,
                isDefaultAction: dialogAction.isDefault,
                isDestructiveAction: variant == ButtonVariant.danger,
                child: plain,
              )
            : cupertino.CupertinoButton(
                onPressed: enabled ? onPressed : null,
                focusNode: focusNode,
                autofocus: autofocus,
                sizeStyle: switch (size) {
                  ControlSize.sm => cupertino.CupertinoButtonSize.small,
                  ControlSize.md => cupertino.CupertinoButtonSize.medium,
                  ControlSize.lg => cupertino.CupertinoButtonSize.large,
                },
                color: switch (variant) {
                  ButtonVariant.primary => theme.colors.primary,
                  // iOS's own supporting weight is the system grey plate, not the
                  // container colour the token model shares with the surfaces.
                  ButtonVariant.secondary => cupertino.CupertinoColors.secondaryLabel.withAlpha(24),
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
      PureDesignLanguage.glass => _glass(theme),
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
      // wrapper that would steal focus from the node that actually activates
      // the button.
      PureDesignLanguage.wind => _wind(theme, m),
      // Yaru draws buttons with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different button. The size step maps
      // onto the Material button's own minimum height, density and label size.
      // Every Material button shape takes the node and the flag, so the
      // contract's focus fields land on the control rather than being accepted
      // and dropped.
      PureDesignLanguage.material || PureDesignLanguage.yaru => switch (variant) {
        ButtonVariant.primary => FilledButton(
          onPressed: enabled ? onPressed : null,
          focusNode: focusNode,
          autofocus: autofocus,
          style: _materialStyle(theme, m),
          child: child,
        ),
        ButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          focusNode: focusNode,
          autofocus: autofocus,
          style: _materialStyle(theme, m),
          child: child,
        ),
        ButtonVariant.danger => FilledButton(
          onPressed: enabled ? onPressed : null,
          focusNode: focusNode,
          autofocus: autofocus,
          style: _materialStyle(theme, m).copyWith(backgroundColor: WidgetStatePropertyAll(theme.colors.error)),
          child: child,
        ),
        ButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          focusNode: focusNode,
          autofocus: autofocus,
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
  /// library's white plate. The plate's height (48), padding (20×10), corner
  /// radius (16), blur and elevation are the fork's own: they are what makes a
  /// glass button look like glass, and overriding them with the token's 32/6
  /// made this language's buttons read as small Material ones.
  ///
  /// A disabled plate is the fork's known gap: `GlassButton` only drops the tap
  /// (`onTap: isLoading || onPressed == null ? null : …`) and changes no pixel,
  /// and its label is hardcoded white whatever the brightness, so there is no
  /// foreground here to dim either. Left as the library draws it rather than
  /// wrapped in a hand-painted opacity, which would also sink the loading ring.
  Widget _glass(PureTheme theme) {
    final fg = _foreground(theme);
    Widget button = glass.GlassButton(
      onPressed: onPressed != null && !loading ? onPressed : null,
      isLoading: loading,
      width: expand ? double.infinity : null,
      color: variant == ButtonVariant.primary ? theme.colors.primary : Colors.white,
      icon: icon == null || loading ? null : Icon(icon, color: fg),
      // The fork's own label role is 15/w600; only the picked family and a
      // legible colour are added — its hardcoded white disappears on a light
      // plate, which is a legibility bug rather than a style.
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg ?? theme.colors.text, fontFamily: theme.token.type.fontFamily),
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

  /// The neumorphic branch: the library's `NeuButton`, whose own content sizing
  /// (20×14 padding, the emboss derived from the theme's depth) is the style.
  /// The loading face is the library's own ring — sized, because its default is
  /// an 80-point progress circle that would burst the button.
  Widget _neumorphic(PureTheme theme, _Metrics m) {
    Widget button = neu.NeuButton(
      onPressed: onPressed != null && !loading ? onPressed : null,
      child: loading
          ? neu.NeuCircularProgress(size: m.fontSize, strokeWidth: 2, progressColor: theme.colors.primary)
          : _plainContent(theme),
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
  ///
  /// The accent rides the fork's own `primary-*` family, which its theme builder
  /// fills from the token — hard-coding `bg-blue-600` made every wind button
  /// ignore the accent the viewer picked. The plate also carries its `dark:`
  /// pair: the fork resolves those against its own brightness, and without them
  /// a secondary button stayed white on a dark surface.
  Widget _wind(PureTheme theme, _Metrics m) {
    final interactive = onPressed != null && !loading;
    // The fork's `disabled:` flag only *activates* the `disabled:` class prefix,
    // and its `opacity` utility never reaches `WButton`'s plate (measured on
    // 1.8.4: a plain `opacity-50` changes no pixel), so no class spells a sunken
    // face here — the wrap below is the compensation.
    final surface = switch (variant) {
      ButtonVariant.primary => 'bg-primary-500 text-white rounded hover:bg-primary-600',
      ButtonVariant.secondary =>
        'bg-white text-gray-900 dark:bg-gray-800 dark:text-gray-100 border border-gray-400 rounded hover:bg-gray-100',
      ButtonVariant.danger => 'bg-red-600 text-white rounded hover:bg-red-700',
      ButtonVariant.ghost => 'text-primary-600 rounded hover:bg-gray-100 dark:hover:bg-gray-800',
    };
    final shape = switch (m.size) {
      ControlSize.sm => 'px-2.5 py-0.5 text-xs',
      ControlSize.md => 'px-3.5 py-1.5 text-sm',
      ControlSize.lg => 'px-4.5 py-2.5 text-base',
    };
    Widget button = wind.WButton(
      onTap: interactive ? onPressed : null,
      disabled: !interactive,
      className: expand ? 'w-full $surface $shape' : '$surface $shape',
      semanticLabel: tooltip,
      // The fork owns the loading face: it swaps the content for its own ring at
      // its own size and colour, so nothing here has to be hand-drawn.
      isLoading: loading,
      loadingColor: _foreground(theme),
      child: _plainContent(theme),
    );
    // The sunken face the fork cannot state in a class. Loading is left out:
    // the fork swaps the content for its own ring there, and the two states are
    // mutually exclusive, so a disabled plate is the only one to sink.
    if (!interactive && !loading) {
      button = Opacity(opacity: 0.5, child: button);
    }
    final hint = tooltip;
    if (hint != null) {
      button = Tooltip(message: hint, child: button);
    }
    return button;
  }

  /// macOS dims a disabled push button by drawing its label at a quarter of the
  /// luminance-matched text colour, but it routes that through
  /// `DefaultTextStyle` — and an [Icon] does not read it, so a disabled button's
  /// glyph stayed at full accent while its words sank (the number stepper's two
  /// arrows are the case in the review sheet). This hands the same quarter to the
  /// icon theme, which is the only channel the glyph does read.
  Widget _macosChild(PureTheme theme, Widget child, bool enabled) {
    if (enabled) {
      return child;
    }
    return _macosDim(child, variant == ButtonVariant.primary ? theme.colors.onPrimary : theme.colors.text);
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
  ///
  /// A disabled button is left alone. macOS dims its disabled face by drawing
  /// the label at a quarter of its own luminance-matched colour, and a colour
  /// named here replaces that rather than layering over it — the button then
  /// reads live behind a sunken plate. Cupertino's disabled face is an opacity
  /// over the whole child, so nothing is lost by standing down there either.
  Widget _tint(Widget child, PureTheme theme, bool enabled) {
    if (!enabled) {
      return child;
    }
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

  /// The forui button's inside. The loading face is forui's own circular
  /// progress — the linear `FProgress` bar is a different control and read as a
  /// broken button.
  Widget _foruiContent(PureTheme theme) {
    if (loading) {
      return const forui.FCircularProgress();
    }
    return _plainContent(theme);
  }

  /// Label and optional leading glyph. The only thing the label carries is the
  /// family the viewer picked: a merged `TextStyle` with nothing but that field
  /// leaves each library's own type role in charge of size, weight and colour
  /// (forui's `contentStyle`, wind's `text-*` classes, glass's 15/w600 label),
  /// which a full token style used to silence.
  Widget _plainContent(PureTheme theme) {
    final text = Text(label, overflow: TextOverflow.ellipsis, style: _familyOnly(theme));
    if (icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 6),
        Flexible(child: text),
      ],
    );
  }

  /// The picked font family and nothing else. Merged onto whatever the
  /// surrounding library decides, it adds the family without taking the type
  /// role away from the library.
  TextStyle? _familyOnly(PureTheme theme) {
    final family = theme.token.type.fontFamily;
    return family == null ? null : TextStyle(fontFamily: family);
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
    this.color,
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

  /// An explicit glyph colour. A control that carries meaning by colour (a
  /// favourite in the error red, a glyph over a picture in white) needs the
  /// override; null keeps the library's own foreground.
  final Color? color;

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
    // Bare: the libraries size their own icon buttons (Fluent 20/24, Yaru's
    // `iconSize`, glass and neumorphic their plate metrics); the token's
    // 14/16/18 shrank every one of them.
    final glyph = Icon(icon, color: color, semanticLabel: tooltip);

    final button = switch (language) {
      // WinUI's toggle: checked = the accent fill carrying its own foreground
      // (`FluentButton` has no selected state of its own, so the style paints
      // it unconditionally).
      PureDesignLanguage.fluent => f2.FluentButton.icon(
        icon: glyph,
        semanticLabel: tooltip,
        onPressed: active ? onPressed : null,
        focusNode: focusNode,
        autofocus: autofocus,
        style: selected
            ? f2.FluentButtonStyle(
                backgroundColor: WidgetStatePropertyAll(theme.colors.primary),
                foregroundColor: WidgetStatePropertyAll(theme.colors.onPrimary),
              )
            : null,
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
      // `MacosIconButton` sinks only its plate when disabled — the glyph is the
      // caller's and the library leaves it at full colour, so a dead button's
      // mark looked live. It carries `PushButton`'s own quarter-alpha rule over.
      // The selected toggle takes the accent plate with its own foreground.
      PureDesignLanguage.macos => macos.MacosIconButton(
        icon: !active
            ? _macosDim(glyph, color ?? IconTheme.of(context).color ?? theme.colors.text)
            : selected
            ? Icon(icon, color: theme.colors.onPrimary, semanticLabel: tooltip)
            : glyph,
        backgroundColor: selected ? theme.colors.primary : null,
        onPressed: active ? onPressed : null,
      ),
      PureDesignLanguage.cupertino => cupertino.CupertinoButton(
        onPressed: active ? onPressed : null,
        focusNode: focusNode,
        autofocus: autofocus,
        // iOS spells no toggle: selected is the system's tinted fill carrying
        // a contrasting glyph.
        color: selected ? theme.colors.primary : null,
        sizeStyle: switch (size) {
          ControlSize.sm => cupertino.CupertinoButtonSize.small,
          ControlSize.md => cupertino.CupertinoButtonSize.medium,
          ControlSize.lg => cupertino.CupertinoButtonSize.large,
        },
        child: selected ? Icon(icon, color: theme.colors.onPrimary, semanticLabel: tooltip) : glyph,
      ),
      // An icon-only control is forui's own variant, laid out by the library —
      // squeezing the token square around a full `FButton` clipped the glyph,
      // so this language does not use that geometry.
      PureDesignLanguage.forui => _foruiIcon(theme, active),
      // The library's own icon button: its frosted plate, at its own 44-point
      // circular default. Selected frosts the accent and draws its border.
      PureDesignLanguage.glass => glass.GlassIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        tooltip: tooltip,
        color: selected ? theme.colors.primaryBg : Colors.white,
        borderColor: selected ? theme.colors.primary : null,
      ),
      // The library's own icon button: the same embossed plane as NeuButton.
      // The neumorphic selected state is the pressed-in plane on the accent's
      // subtle base.
      PureDesignLanguage.neumorphic => neu.NeuIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        tooltip: tooltip,
        shape: selected ? neu.NeuShape.pressed : neu.NeuShape.flat,
        baseColor: selected ? theme.colors.primaryBg : null,
      ),
      // The fork's one button shape carries the glyph, the accessible name on
      // the button itself (`WButton` has no icon variant either) and the
      // surface in its own utility classes.
      PureDesignLanguage.wind => _windIcon(theme, m, active, selected),
      PureDesignLanguage.yaru => yaru.YaruIconButton(
        icon: glyph,
        onPressed: active ? onPressed : null,
        focusNode: focusNode,
        autofocus: autofocus,
        isSelected: selected ? true : null,
        tooltip: tooltip,
      ),
      PureDesignLanguage.material => IconButton(
        icon: glyph,
        tooltip: tooltip,
        onPressed: active ? onPressed : null,
        focusNode: focusNode,
        autofocus: autofocus,
        // Material 3's own selected icon button: the highlight plate and the
        // tinted glyph are the platform's, not ours to draw.
        isSelected: selected,
        visualDensity: switch (size) {
          ControlSize.sm => VisualDensity.compact,
          ControlSize.md => const VisualDensity(horizontal: -0.5, vertical: -0.5),
          ControlSize.lg => VisualDensity.standard,
        },
      ),
    };

    // The languages whose button shows the hint itself must not be handed a
    // second one — Material, Yaru, glass, neumorphic and forui all take the
    // string, and wrapping them stacked two bubbles on the same hover.
    if (_showsItsOwnTooltip(language)) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }

  /// Whether this language's icon button already reveals [tooltip] on hover.
  bool _showsItsOwnTooltip(PureDesignLanguage language) => switch (language) {
    PureDesignLanguage.material ||
    PureDesignLanguage.yaru ||
    PureDesignLanguage.glass ||
    PureDesignLanguage.neumorphic ||
    PureDesignLanguage.forui => true,
    _ => false,
  };

  /// The forui icon button: the library's own `FButton.icon`.
  Widget _foruiIcon(PureTheme theme, bool active) {
    final button = forui.FButton.icon(
      onPress: active ? onPressed : null,
      variant: PureButton._foruiVariant(variant),
      size: PureButton._foruiSize(size),
      selected: selected,
      focusNode: focusNode,
      autofocus: autofocus,
      child: Icon(icon, semanticLabel: tooltip),
    );
    return forui.FTooltip(tipBuilder: (context, controller) => Text(tooltip), child: button);
  }

  /// The wind icon button: the glyph in `WButton`'s child slot, the accessible
  /// name on the button itself, the plate in the fork's own classes.
  ///
  /// The primary plate rides the fork's `primary-*` family like the text
  /// button's does, and the disabled face is the same `Opacity` compensation,
  /// because `WButton` states neither in a class. Selected holds the deeper
  /// primary plate without the hover step.
  Widget _windIcon(PureTheme theme, _Metrics m, bool active, bool selected) {
    final surface = selected
        ? 'bg-primary-600 text-white rounded'
        : switch (variant) {
            ButtonVariant.primary => 'bg-primary-500 text-white rounded hover:bg-primary-600',
            ButtonVariant.secondary => 'bg-white text-gray-900 border border-gray-400 rounded hover:bg-gray-100',
            ButtonVariant.danger => 'bg-red-600 text-white rounded hover:bg-red-700',
            ButtonVariant.ghost => 'text-gray-900 rounded hover:bg-gray-100',
          };
    Widget button = wind.WButton(
      onTap: active ? onPressed : null,
      disabled: !active,
      className:
          '$surface ${switch (m.size) {
            ControlSize.sm => 'p-1',
            ControlSize.md => 'p-2',
            ControlSize.lg => 'p-2.5',
          }}',
      semanticLabel: tooltip,
      child: Icon(icon, size: m.icon, color: selected ? Colors.white : color, semanticLabel: tooltip),
    );
    if (!active) {
      button = Opacity(opacity: 0.5, child: button);
    }
    return button;
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

/// macOS's own disabled foreground: the label colour at a quarter alpha
/// (`PushButton` lines 306-308). The library reaches its text through
/// `DefaultTextStyle` unaided; this carries the same rule to a glyph, which
/// reads only the icon theme.
Widget _macosDim(Widget child, Color label) => IconTheme.merge(
  data: IconThemeData(color: label.withValues(alpha: 0.25)),
  child: child,
);
