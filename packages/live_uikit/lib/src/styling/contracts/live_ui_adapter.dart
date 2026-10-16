import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_capabilities.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_surfaces.dart';
import 'package:live_uikit/src/styling/style/recipe.dart';
import 'package:live_uikit/src/styling/style/style.dart';
import 'package:live_uikit/src/styling/tokens/design_token.dart';
import 'package:live_uikit/src/styling/widgets/chrome/live_nav_bar.dart' show LiveNavBarItem;
import 'package:live_uikit/src/styling/widgets/controls/live_tabs.dart' show LiveTab;
import 'package:live_uikit/src/styling/widgets/overlays/live_toast.dart' show LiveToastType;

/// The switchable design languages.
///
/// Every entry except [token] names a widget library the app can be drawn from
/// and has an adapter of its own; [token] is the base every language falls
/// through to, not a library, so it is never registered.
enum LiveDesignLanguage {
  /// The shared token base: the resolved `DesignToken` painted with Flutter's
  /// Material primitives. It is the fallback renderer, claims no control and
  /// ships no host of its own.
  token,

  /// Windows `fluent_ui`.
  fluent,

  /// macOS `macos_ui`.
  macos,

  /// `flutter_neumorphic_ui_kit`.
  neumorphic,

  /// `glass_morphism_plus`.
  glass,

  /// `fluttersdk_wind`.
  wind,

  /// `forui` (the shadcn-style `F*` widget library).
  forui,

  /// `material_ui` — Flutter's Material library, the same one
  /// `package:flutter/material.dart` was moved into. The design system [token]
  /// already paints, taken from the library's own widgets, theme and host.
  material,

  /// `cupertino_ui` — Flutter's Cupertino library, the same one
  /// `package:flutter/cupertino.dart` was moved into. This is the iOS language:
  /// [token] draws Material primitives, so nothing else stands in for it.
  cupertino,
}

/// A button described the same way every language draws it.
class LanguageButtonSpec {
  /// A button spec.
  const new({
    required this.label,
    required this.enabled,
    required this.variant,
    required this.size,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.iconOnly = false,
    this.selected = false,
    this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.style,
  });

  /// The label text.
  final String label;

  /// Whether the button accepts input.
  final bool enabled;

  /// The semantic kind.
  final ButtonVariant variant;

  /// The size step.
  final ControlSize size;

  /// An optional leading icon.
  final IconData? icon;

  /// Whether a spinner replaces the content.
  final bool loading;

  /// Whether the button fills its parent's width.
  final bool expand;

  /// Whether the button carries an icon and no visible text, as a toolbar or
  /// control-bar action does. [tooltip] is then the accessible name, so the
  /// renderer never paints the empty [label] the caller passed to satisfy the
  /// contract. `LiveIconButton` sets it; the token base also squares the control
  /// to its [size] step, which is the geometry a text button never needs.
  final bool iconOnly;

  /// Whether the button shows a mode that is currently on — a toggled filter, an
  /// active view. This is state, not emphasis: the token base tints the
  /// foreground with the primary colour, and an adapter maps it only where its
  /// library has an equivalent; where it does not, the button renders unselected
  /// and the spec says so.
  final bool selected;

  /// The tap callback.
  final VoidCallback? onPressed;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An optional tooltip.
  final String? tooltip;

  /// An inline style override — the `style=` attribute, and the highest-precedence
  /// layer of the recipe (see `live-uikit.md` §8). The card and text-field specs have
  /// carried this field all along; the button spec only gained it once `LiveButton`
  /// started forwarding the `style:` it already accepted. A library whose button paints
  /// its own surface records in its §9 that it does not map this.
  final Style? style;
}

/// A card described the same way every language draws it.
class LanguageCardSpec {
  /// A card spec.
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
  });

  /// The card content.
  final Widget child;

  /// The tap handler; makes the card interactive.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the card shows a selected state.
  final bool selected;

  /// Whether the card is bordered.
  final bool bordered;

  /// Whether the card uses a tighter padding.
  final bool dense;

  /// An explicit inner padding, overriding the token default.
  final EdgeInsetsGeometry? padding;

  /// A focus node and first-focus flag for interactive cards.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An inline style override.
  final Style? style;
}

/// A text field described the same way every language draws it.
class LanguageTextFieldSpec {
  /// A text field spec.
  const new({
    this.controller,
    this.focusNode,
    this.placeholder,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscure = false,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.style,
    this.onChanged,
    this.onSubmitted,
  });

  /// The text controller; the field owns one when null.
  final TextEditingController? controller;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// The empty-state hint.
  final String? placeholder;

  /// The validation message.
  final String? errorText;

  /// Whether the field responds to input.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether the field hides its content.
  final bool obscure;

  /// The line count.
  final int? maxLines;

  /// Keyboard action and type.
  final TextInputAction? textInputAction;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// A widget before the text.
  final Widget? prefix;

  /// A widget after the text.
  final Widget? suffix;

  /// An inline style override.
  final Style? style;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the field is submitted.
  final ValueChanged<String>? onSubmitted;
}

/// A switch described the same way every language draws it.
class LanguageSwitchSpec {
  /// A switch spec.
  const new({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value; null disables it.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch responds to input.
  final bool enabled;

  /// A focus node and first-focus flag.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;
}

/// A checkbox described the same way every language draws it.
class LanguageCheckboxSpec {
  /// A checkbox spec.
  const new({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  /// Whether the box is checked.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// An optional trailing label.
  final String? label;

  /// Whether the box responds to input.
  final bool enabled;

  /// A focus node and first-focus flag.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;
}

/// A slider described the same way every language draws it.
class LanguageSliderSpec {
  /// A slider spec.
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
    this.focusNode,
  });

  /// The current value.
  final double value;

  /// Called with each new value; null (or `enabled: false`) disables it.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// Whether the slider responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;
}

/// A segmented control described the same way every language draws it.
class LanguageSegmentedSpec {
  /// A segmented spec.
  const new({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.enabled = true,
    this.expand = false,
  });

  /// The segment labels, in order.
  final List<String> labels;

  /// The selected index.
  final int index;

  /// Called with a segment's index; null (or `enabled: false`) disables it.
  final ValueChanged<int>? onChanged;

  /// Whether the control responds to input.
  final bool enabled;

  /// Whether segments share the full width.
  final bool expand;
}

/// A linear progress indicator described the same way every language draws it.
class LanguageProgressSpec {
  /// A progress spec.
  const new({required this.value, this.height = 8, this.showLabel = false, this.barColor});

  /// The completion fraction 0..1, or null for an indeterminate spinner.
  final double? value;

  /// The track thickness.
  final double height;

  /// Whether to show the trailing percentage.
  final bool showLabel;

  /// An optional fill colour override.
  final Color? barColor;
}

/// A dropdown select described the same way every language draws it. Generic
/// over the value type [T] so a page keeps typed selection through the swap.
class LanguageSelectSpec<T> {
  /// A select spec.
  const new({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.placeholder,
    this.enabled = true,
  });

  /// The selectable values.
  final List<T> items;

  /// Maps a value to its display label.
  final String Function(T item) itemLabel;

  /// Called with the chosen value; null (or `enabled: false`) disables it.
  final ValueChanged<T>? onChanged;

  /// The currently selected value, if any.
  final T? value;

  /// Text shown when nothing is selected.
  final String? placeholder;

  /// Whether the control responds to input.
  final bool enabled;
}

/// A tab strip described the same way every language draws it.
class LanguageTabsSpec {
  /// A tabs spec.
  const new({required this.tabs, required this.index, required this.onChanged, this.spacing = 0, this.enabled = true});

  /// The tabs, in order.
  final List<LiveTab> tabs;

  /// The selected index.
  final int index;

  /// Called with a tab's index when chosen; null (or `enabled: false`) disables.
  final ValueChanged<int>? onChanged;

  /// The gap between tabs (token renderer).
  final double spacing;

  /// Whether the strip responds to input.
  final bool enabled;
}

/// A page frame described the same way every language draws it.
///
/// The frame is the control a language difference shows on most: it decides the
/// background surface, where the bars sit, and whether the content runs behind
/// the top bar. It carries the bars as already-built widgets because the bar is
/// its own dispatched control — a page names its frame, the frame asks for its
/// bar, and each of those answers in the active language.
class LanguageScaffoldSpec {
  /// A scaffold spec.
  const new({
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.background,
    this.extendBodyBehindAppBar = false,
    this.avoidKeyboard = true,
  });

  /// The page content.
  final Widget body;

  /// The already-dispatched top bar, null for a page without one.
  final Widget? appBar;

  /// The bottom bar — a navigation rail's footer, a tab strip, an action row.
  final Widget? bottomBar;

  /// A floating action, placed at the trailing bottom corner of the frame.
  final Widget? floatingActionButton;

  /// A background override; null keeps the surface role of the theme.
  final Color? background;

  /// Whether [body] starts under [appBar] rather than below it, for the pages
  /// whose cover art or scroll view is meant to reach the top edge.
  final bool extendBodyBehindAppBar;

  /// Whether the content keeps clear of an open on-screen keyboard. A library
  /// whose frame handles this itself maps it natively; the token renderer
  /// answers with the view insets, which is what the Material frame it replaced
  /// did by default.
  final bool avoidKeyboard;
}

/// A top bar described the same way every language draws it.
class LanguageAppBarSpec {
  /// An app bar spec.
  const new({
    required this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.bottom,
    this.background,
    this.centerTitle,
    this.height,
  });

  /// The page title.
  final String title;

  /// A widget before the title — a back affordance, a drawer button, a logo.
  final Widget? leading;

  /// Actions after the title, in order.
  final List<Widget> actions;

  /// A strip under the title row, typically a dispatched `LiveTabs`.
  final Widget? bottom;

  /// A background override; null keeps the theme's header surface.
  final Color? background;

  /// Whether the title sits in the middle. Null defers to what the language
  /// does by default — a centre-titled bar is a platform statement, not a
  /// layout preference, so the caller only overrides it deliberately.
  final bool? centerTitle;

  /// The title row height; null takes the language's own bar height.
  final double? height;
}

/// A tappable list row described the same way every language draws it.
class LanguageListRowSpec {
  /// A list row spec.
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.divided = false,
    this.focusNode,
    this.autofocus = false,
  });

  /// The row's main line.
  final String title;

  /// The secondary line.
  final String? subtitle;

  /// A widget before the text — an avatar, an icon, a cover.
  final Widget? leading;

  /// A widget after the text — a chevron, a switch, a menu button.
  final Widget? trailing;

  /// The tap handler; null renders a row that does not respond.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the row shows the selected state.
  final bool selected;

  /// Whether a divider follows the row.
  final bool divided;

  /// A focus node and first-focus flag for interactive rows.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;
}

/// A bottom navigation bar described the same way every language draws it.
class LanguageNavBarSpec {
  /// A nav bar spec.
  const new({required this.items, required this.index, this.onChanged, this.enabled = true});

  /// The destinations, in order.
  final List<LiveNavBarItem> items;

  /// The selected destination.
  final int index;

  /// Called with a destination's index; null (or `enabled: false`) refuses taps.
  final ValueChanged<int>? onChanged;

  /// Whether the bar responds to input.
  final bool enabled;
}

/// A transient status message described the same way every language draws it.
///
/// The spec covers the message's own surface only: the overlay it is placed
/// in, the fade-and-slide in and the timer that removes it belong to the core
/// (`LiveToast.show`), because those are the same in every language and a
/// library that wants its own placement overrides the whole call.
class LanguageToastSpec {
  /// A toast spec.
  const new({
    required this.message,
    this.type = LiveToastType.info,
    this.icon,
    this.accent,
    this.duration = const Duration(milliseconds: 2200),
  });

  /// The text.
  final String message;

  /// The semantic kind, which decides the default accent and glyph.
  final LiveToastType type;

  /// A glyph override; null takes the one that matches [type].
  final IconData? icon;

  /// A colour override; null takes the status role of [type].
  final Color? accent;

  /// How long the message stays up.
  final Duration duration;
}

/// A modal message over the page, described the same way every language draws it.
///
/// Like [LanguageToastSpec] this covers the dialog's own surface: the barrier it
/// dims, the route it arrives on and the dismissal belong to the core
/// (`LiveDialog.show`), because those are the same behaviour in every language and
/// a library that wants its own presentation overrides the whole call. [actions]
/// carries already-built widgets for the same reason the bars do — a dialog's
/// buttons are the language's `button`, and the frame must not re-pick them.
class LanguageDialogSpec {
  /// A dialog spec.
  const new({this.title, this.content, this.actions = const <Widget>[], this.icon, this.dismissible = true});

  /// The heading; null leaves the body to start at the top.
  final String? title;

  /// The body under the heading.
  final Widget? content;

  /// The buttons, in order.
  final List<Widget> actions;

  /// A glyph over the heading; null draws none.
  final IconData? icon;

  /// Whether tapping outside the surface closes it.
  final bool dismissible;
}

/// The page switcher a tab strip drives, described the same way every language
/// draws it.
///
/// [LanguageTabsSpec] is the strip and this is the content under it; they are two
/// controls rather than one because the two differ per language more than they
/// agree — iOS swipes between pages, Windows does not, and a Material view
/// animates through a controller of its own. The caller builds the pages and owns
/// the index, so a language decides only how a page changes, never what is on it.
class LanguageTabViewSpec {
  /// A tab view spec.
  const new({
    required this.pages,
    required this.index,
    this.onIndexChanged,
    this.duration = const Duration(milliseconds: 300),
  });

  /// The pages, in the order of the strip's tabs.
  final List<Widget> pages;

  /// The visible page.
  final int index;

  /// Called with a page's index when the viewer moves it by swiping; null (or
  /// [pages] of one) leaves the view non-interactive.
  final ValueChanged<int>? onIndexChanged;

  /// How long a page change takes where the language animates one at all.
  final Duration duration;
}

/// The application host described the same way every language wires it.
///
/// A widget library's identity is not only its controls: the app widget owns
/// the route transitions, the overlay the dialogs and text-selection toolbars
/// open into, the scrollbars, and the strings the chrome reads. A language whose
/// library ships an app widget has to be hosted by it, or the whole tree keeps
/// behaving like Material no matter what the controls are drawn with.
///
/// The token is deliberately absent: the host is themed from the resolved
/// `LiveTheme` the adapter already reads, so a preference change re-skins the
/// host along with everything under it.
class LanguageHostSpec {
  /// A host spec.
  const new({
    required this.routerConfig,
    this.title = '',
    this.onGenerateTitle,
    this.localizationsDelegates = const <LocalizationsDelegate<dynamic>>[],
    this.supportedLocales = const <Locale>[Locale('en')],
    this.locale,
    this.builder,
    this.debugShowCheckedModeBanner = false,
  });

  /// The router the app runs on — a `GoRouter`, typically.
  final RouterConfig<Object>? routerConfig;

  /// The window title. Ignored when [onGenerateTitle] is given.
  final String title;

  /// Called to resolve the title once the localizations are in scope, which is
  /// how a translated title survives a locale change without a restart.
  final GenerateAppTitle? onGenerateTitle;

  /// The localizations every language below needs, in priority order. The host
  /// appends its library's own defaults to these.
  final List<LocalizationsDelegate<dynamic>> localizationsDelegates;

  /// The locales the app declares, kept in step with the translation layer.
  final List<Locale> supportedLocales;

  /// The forced locale; null follows the platform.
  final Locale? locale;

  /// Wraps the navigator, below the host's localizations and above its routes
  /// — where a translation provider belongs.
  final TransitionBuilder? builder;

  /// Whether the debug banner shows.
  final bool debugShowCheckedModeBanner;
}

/// One destination in the application shell's navigation.
///
/// It carries what a destination *is* — an id the caller maps back onto a route,
/// a label, a glyph, and whether it can be taken at all — rather than a
/// `NavigationDestination`, a `NavigationPaneItem` or any other library's own
/// item type, because the shell that receives it is not known yet (§ surfaces).
class LiveShellDestination {
  /// A destination.
  const new({required this.id, required this.label, required this.icon, this.enabled = true});

  /// The stable identity the caller addresses navigation by. A library that keys
  /// its selection internally still reports the id it was given.
  final String id;

  /// The label.
  final String label;

  /// The glyph. `IconData` is a value, not a widget, so it crosses this boundary
  /// without dragging a widget library's build context with it.
  final IconData icon;

  /// Whether the destination can be taken; a disabled one stays visible so the
  /// layout does not shift when it becomes available.
  final bool enabled;
}

/// Where the shell's navigation sits, when the caller knows better than the
/// window width does.
enum LiveShellPlacement {
  /// Let the language choose from the environment: a strip under the content on
  /// a phone, a rail beside it once there is room.
  adaptive,

  /// A vertical navigation column beside the content.
  rail,

  /// A horizontal strip under the content.
  bottom,

  /// No navigation: the shell is a frame around a full-screen page.
  none,
}

/// The application shell described the same way every language draws it
/// (§ surfaces — the structural surface between the host and the page).
///
/// The shell owns the navigation *around* the page; the page keeps its own bar,
/// so [LanguageShellSpec] carries no title. Navigation state belongs to the
/// caller: the shell reports [onSelected] and renders [selectedId], and never
/// keeps a second copy of its own that could disagree with the router.
class LanguageShellSpec {
  /// A shell spec.
  const new({
    required this.child,
    this.destinations = const <LiveShellDestination>[],
    this.selectedId,
    this.onSelected,
    this.trailing,
    this.placement = LiveShellPlacement.adaptive,
  });

  /// The page content.
  final Widget child;

  /// The destinations, in order.
  final List<LiveShellDestination> destinations;

  /// The selected destination's id; null selects nothing.
  final String? selectedId;

  /// Called with a destination's id; null (or an empty list) renders the shell
  /// without working navigation.
  final ValueChanged<String>? onSelected;

  /// Content pinned at the far end of the navigation column — a settings entry,
  /// a footer. The bottom-strip form has no such slot, so a language that draws
  /// one drops it rather than inventing a place for it.
  final Widget? trailing;

  /// The caller's intent about where navigation sits.
  final LiveShellPlacement placement;
}

/// Renders one design language's controls from the real widget library, themed
/// from the resolved [DesignToken]. Each language provides an adapter; the
/// active one is chosen at runtime by `UiConfig.language`, so switching a
/// language re-skins the whole subtree without the page changing a line.
///
/// Where a library has no equivalent for a control, the adapter delegates to
/// the shared token-driven fallback renderer — so every component still
/// works and stays on-theme.
abstract interface class LanguageAdapter {
  /// The language this adapter renders.
  LiveDesignLanguage get language;

  /// A stable, machine-readable style id (e.g. `fluent`) used by the registry,
  /// persistence and diagnostics — never a localized label (§7).
  String get id;

  /// A human-readable name for the style selector (e.g. `Fluent`) (§7).
  String get displayName;

  /// Which controls this adapter renders natively; the rest fall back to the
  /// shared token renderer and are reported by the resolver (§3.1/§7).
  LiveUiCapabilities get capabilities;

  /// Which structural surfaces — the app host and the shell — this adapter owns
  /// with its library's own widgets (§ surfaces). Declared apart from
  /// [capabilities] because owning one says nothing about the other: fluent owns
  /// both, `macos_ui` owns the host and a sidebar but no bottom strip, and ForUI
  /// owns neither.
  LiveUiSurfaceCapabilities get surfaces;

  /// Installs this language's theme (from [token]) around [child].
  Widget wrap(BuildContext context, DesignToken token, Widget child);

  /// Draws a button with the language's real widget.
  Widget button(BuildContext context, LanguageButtonSpec spec);

  /// Draws a card with the language's real widget.
  Widget card(BuildContext context, LanguageCardSpec spec);

  /// Draws a text field with the language's real widget.
  Widget textField(BuildContext context, LanguageTextFieldSpec spec);

  /// Draws a switch with the language's real widget.
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec);

  /// Draws a checkbox with the language's real widget.
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec);

  /// Draws a slider with the language's real widget.
  Widget slider(BuildContext context, LanguageSliderSpec spec);

  /// Draws a segmented control with the language's real widget.
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec);

  /// Draws a linear progress indicator with the language's real widget.
  Widget progress(BuildContext context, LanguageProgressSpec spec);

  /// Draws a dropdown select with the language's real widget.
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec);

  /// Draws a tab strip with the language's real widget.
  Widget tabBar(BuildContext context, LanguageTabsSpec spec);

  /// Draws the page frame with the language's real widget.
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec);

  /// Draws a top bar with the language's real widget.
  Widget appBar(BuildContext context, LanguageAppBarSpec spec);

  /// Draws a list row with the language's real widget.
  Widget listRow(BuildContext context, LanguageListRowSpec spec);

  /// Draws a bottom navigation bar with the language's real widget.
  Widget navBar(BuildContext context, LanguageNavBarSpec spec);

  /// Draws a toast's surface with the language's real widget.
  Widget toast(BuildContext context, LanguageToastSpec spec);

  /// Draws a dialog's surface with the language's real widget.
  Widget dialog(BuildContext context, LanguageDialogSpec spec);

  /// Draws the page switcher under a tab strip with the language's real widget.
  Widget tabView(BuildContext context, LanguageTabViewSpec spec);

  /// Wraps the whole app in the language's own host widget, when its library
  /// ships one — a [LiveUiSurface.appHost] capability. The shared renderer answers
  /// with the token-seeded Material host, which is the documented fallback, not a
  /// claim that this language owns the root.
  Widget appHost(BuildContext context, LanguageHostSpec spec);

  /// Draws the application shell — the navigation around the page — with the
  /// language's own structural widget, when its library ships one (a
  /// [LiveUiSurface.appShell] capability). Otherwise the shared token shell
  /// stands in, which is a navigation column or strip built from the token
  /// rather than the language's widget set.
  Widget shell(BuildContext context, LanguageShellSpec spec);
}
