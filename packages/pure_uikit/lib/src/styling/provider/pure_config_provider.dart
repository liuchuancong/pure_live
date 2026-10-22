import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/styling/config/pure_config.dart';
import 'package:pure_uikit/src/styling/style/recipe.dart';
import 'package:pure_uikit/src/styling/style/style.dart';
import 'package:pure_uikit/src/styling/tokens/component_token.dart';
import 'package:pure_uikit/src/styling/tokens/design_token.dart';
import 'package:pure_uikit/src/styling/tokens/seed_token.dart';
import 'package:pure_uikit/src/styling/tokens/theme_algorithm.dart';

/// The eight text roles, built from the resolved [TypeTokens] with the global
/// font scale and family applied — the neutral vocabulary a component asks for
/// (`title`, `body`, `label`) instead of Material's `TextTheme`.
@immutable
final class TextStyles {
  /// The role styles.
  const new({
    required this.display,
    required this.headline,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.label,
  });

  /// Builds the roles from [token], scaled by [scale] and overridden by
  /// [family]; each `*Size` is an absolute pixel size (before [scale]) that
  /// replaces the token's own, and null keeps the design language's value.
  factory from(
    DesignToken token, {
    required double scale,
    String? family,
    double? headlineSize,
    double? titleSize,
    double? subtitleSize,
    double? bodySize,
    double? bodySmallSize,
  }) {
    final t = token.type;
    TextStyle role(double size, FontWeight weight, double height, [double? override]) =>
        TextStyle(fontSize: (override ?? size) * scale, fontWeight: weight, height: height, fontFamily: family ?? t.fontFamily);
    return TextStyles(
      display: role(t.fontSizeHeading1, FontWeight.w600, t.lineHeight),
      headline: role(t.fontSizeHeading2, FontWeight.w600, t.lineHeight, headlineSize),
      title: role(t.fontSizeHeading4, FontWeight.w600, t.lineHeight, titleSize),
      subtitle: role(t.fontSizeLG, FontWeight.w500, t.lineHeightLG, subtitleSize),
      body: role(t.fontSize, FontWeight.w400, t.lineHeight, bodySize),
      bodySmall: role(t.fontSizeSM, FontWeight.w400, t.lineHeightSM, bodySmallSize),
      caption: role(t.fontSizeSM, FontWeight.w400, t.lineHeightSM, bodySmallSize),
      label: role(t.fontSize, FontWeight.w500, t.lineHeight, bodySize),
    );
  }

  /// The largest text.
  final TextStyle display;

  /// Section headers.
  final TextStyle headline;

  /// Card and dialog titles.
  final TextStyle title;

  /// Subtitles.
  final TextStyle subtitle;

  /// Running text.
  final TextStyle body;

  /// Dense text.
  final TextStyle bodySmall;

  /// Captions and metadata.
  final TextStyle caption;

  /// Control labels.
  final TextStyle label;
}

/// A resolved theme handed down the tree: the design tokens, the text roles,
/// the current component tokens and the runtime flags (blur, motion) a component
/// needs. Components read only this — never a config or a design language — so
/// the whole visual system is one `PureTheme.of(context)` away.
@immutable
final class PureTheme {
  /// A resolved theme; produced by [PureConfigProvider].
  const new({
    required this.config,
    required this.token,
    required this.text,
    required this.button,
    required this.canBlur,
    required this.isDark,
  });

  /// The configuration this theme was resolved from.
  final UiConfig config;


  /// The full resolved design token set.
  final DesignToken token;

  /// The scaled text roles.
  final TextStyles text;

  /// The Button component tokens (the pattern other components follow).
  final ButtonComponentToken button;

  /// The Card component tokens, derived from the resolved design token.
  CardComponentToken get card => CardComponentToken.of(token);

  /// The text input component tokens.
  InputComponentToken get input => InputComponentToken.of(token);

  /// The switch component tokens.
  SwitchComponentToken get switchToken => SwitchComponentToken.of(token);

  /// The tabs component tokens.
  TabsComponentToken get tabs => TabsComponentToken.of(token);

  /// The list-row component tokens.
  ListTileComponentToken get listTile => ListTileComponentToken.of(token);

  /// The checkbox component tokens.
  CheckboxComponentToken get checkbox => CheckboxComponentToken.of(token);

  /// The slider component tokens.
  SliderComponentToken get slider => SliderComponentToken.of(token);

  /// The badge component tokens.
  BadgeComponentToken get badge => BadgeComponentToken.of(token);

  /// The select component tokens.
  SelectComponentToken get select => SelectComponentToken.of(token);

  /// Whether a backdrop filter may be drawn: the config's transparency policy
  /// and the device's capability, resolved once here.
  final bool canBlur;

  /// Whether the resolved brightness is dark.
  final bool isDark;

  /// The colour roles.
  ColorTokens get colors => token.color;

  /// The medium transition duration, honoured by animated components.
  Duration get duration => config.animations ? token.motion.durationMid : Duration.zero;


  /// Resolves the Button style for a [variant], [size] and interaction [state]
  /// — `recipe ⊕ component token` in one call. A widget paints the result and
  /// never inspects the design language or the raw tokens itself.
  Style resolveButton({required ButtonVariant variant, required ControlSize size, required InteractionState state}) =>
      const ButtonRecipe().resolve(token, button, variant: variant, size: size, state: state);

  /// The theme of the nearest [PureConfigProvider].
  static PureTheme of(BuildContext context) {
    final theme = maybeOf(context);
    assert(theme != null, 'No PureConfigProvider found above this widget.');
    return theme!;
  }

  /// The theme of the nearest [PureConfigProvider], or null outside one.
  static PureTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PureThemeScope>()?.theme;
}

/// The provider — Ant Design's `ConfigProvider`: it turns a [UiConfig] (plus
/// optional seed / component-token overrides and device facts) into a resolved
/// [PureTheme] for the subtree, and can be nested so a region re-themes
/// independently while the same dispatch pipeline still applies.
class PureConfigProvider extends StatefulWidget {
  /// A provider over [child].
  const new({
    required this.config,
    required this.child,
    this.seed,
    this.buttonToken,
    this.hardwareBlur = true,
    this.systemTextScale = 1,
    super.key,
  });

  /// The configuration driving this subtree.
  final UiConfig config;

  /// An explicit seed override applied over the config-derived seed; a pure
  /// function so a provider can nudge individual seed values without restating
  /// them (Ant's partial `theme.token` override, but typed).
  final SeedToken Function(SeedToken base)? seed;

  /// An override of the Button component tokens (Ant's `components.Button`).
  final ButtonComponentToken Function(DesignToken token)? buttonToken;



  /// Whether the device can afford a backdrop filter.
  final bool hardwareBlur;

  /// The platform text scale, folded into the role sizes.
  final double systemTextScale;

  /// The themed subtree.
  final Widget child;

  @override
  State<PureConfigProvider> createState() => _PureConfigProviderState();
}

class _PureConfigProviderState extends State<PureConfigProvider> with WidgetsBindingObserver {
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    _platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void didChangePlatformBrightness() {
    setState(() => _platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  Widget build(BuildContext context) {
    final platformDark = _platformBrightness == Brightness.dark;
    final dark = widget.config.useDark(platformDark: platformDark);
    final baseSeed = widget.config.toSeed();
    final seed = widget.seed?.call(baseSeed) ?? baseSeed;
    final token = ThemeAlgorithms.resolve(seed, widget.config.algorithms(dark: dark));
    final scale = widget.config.fontScale * widget.systemTextScale;
    final theme = PureTheme(
      config: widget.config,
      token: token,
      text: TextStyles.from(
        token,
        scale: scale,
        family: widget.config.fontFamily,
        headlineSize: widget.config.headlineSize,
        titleSize: widget.config.titleSize,
        subtitleSize: widget.config.subtitleSize,
        bodySize: widget.config.bodySize,
        bodySmallSize: widget.config.bodySmallSize,
      ),
      button: widget.buttonToken?.call(token) ?? ButtonComponentToken.of(token),
      canBlur: widget.config.allowsTransparency && widget.hardwareBlur,
      isDark: dark,
    );
    // The active library's theme wraps the subtree (from our tokens), and the
    // resolved PureTheme sits inside it so both library widgets and our own
    // controls read their styling from one source.
    return _PureThemeScope(theme: theme, child: widget.child);
  }
}

/// An InheritedWidget carrying the resolved [PureTheme]; rebuilt (not mutated)
/// so business state below survives a theme switch untouched.
class _PureThemeScope extends InheritedWidget {
  const new({required this.theme, required super.child});

  final PureTheme theme;

  @override
  bool updateShouldNotify(_PureThemeScope oldWidget) =>
      theme.token != oldWidget.theme.token ||
      theme.config != oldWidget.theme.config ||
      theme.canBlur != oldWidget.theme.canBlur;
}
