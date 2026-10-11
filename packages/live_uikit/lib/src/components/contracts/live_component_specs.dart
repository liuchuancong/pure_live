import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What a button means, not how it looks.
///
/// Every design language renders these the same *semantically*: one
/// primary action per view, secondary actions beside it, `danger` for
/// destructive ones, `text` and `outline` for lower emphasis. What changes
/// per language is the fill, the corner radius, the elevation and the
/// focus treatment.
enum LiveButtonVariant {
  /// The main action of the view: filled with the accent.
  primary,

  /// The usual companion action: filled with a low-emphasis tone.
  secondary,

  /// A bordered, unfilled action.
  outline,

  /// A bare label, for the least important actions.
  text,

  /// A destructive action, filled with the error colour.
  danger,
}

/// The size of a control, independent of the design language.
enum LiveControlSize {
  /// Dense chrome: toolbars, chips, table rows.
  small,

  /// The default: forms, dialogs, page actions.
  medium,

  /// Prominent actions and TV layouts.
  large,
}

/// The contract of a text button.
@immutable
final class LiveButtonSpec {
  /// A button spec.
  const new({
    required this.label,
    this.icon,
    this.variant = LiveButtonVariant.primary,
    this.size = LiveControlSize.medium,
    this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    this.tooltip,
    this.semanticLabel,
  });

  /// The button's text.
  final String label;

  /// An optional leading icon.
  final IconData? icon;

  /// What the button means.
  final LiveButtonVariant variant;

  /// How large it is.
  final LiveControlSize size;

  /// The callback; null disables the button exactly like [enabled] false.
  final VoidCallback? onPressed;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it shows a spinner and rejects input while work runs.
  final bool loading;

  /// Whether it fills its parent's width.
  final bool expand;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// A tooltip, also the accessibility label on desktop.
  final String? tooltip;

  /// An accessibility label when [label] alone is not enough (icon-only
  /// usage, abbreviations).
  final String? semanticLabel;

  /// Whether the button reacts to input at all.
  bool get isInteractive => enabled && !loading && onPressed != null;

  /// The spec with some fields replaced, for pages that adjust a shared
  /// style.
  LiveButtonSpec copyWith({
    String? label,
    IconData? icon,
    LiveButtonVariant? variant,
    LiveControlSize? size,
    VoidCallback? onPressed,
    bool? enabled,
    bool? loading,
    bool? expand,
    bool? autofocus,
    FocusNode? focusNode,
    String? tooltip,
    String? semanticLabel,
  }) => LiveButtonSpec(
    label: label ?? this.label,
    icon: icon ?? this.icon,
    variant: variant ?? this.variant,
    size: size ?? this.size,
    onPressed: onPressed ?? this.onPressed,
    enabled: enabled ?? this.enabled,
    loading: loading ?? this.loading,
    expand: expand ?? this.expand,
    autofocus: autofocus ?? this.autofocus,
    focusNode: focusNode ?? this.focusNode,
    tooltip: tooltip ?? this.tooltip,
    semanticLabel: semanticLabel ?? this.semanticLabel,
  );
}

/// The contract of an icon-only button.
@immutable
final class LiveIconButtonSpec {
  /// An icon-button spec.
  const new({
    required this.icon,
    required this.tooltip,
    this.variant = LiveButtonVariant.text,
    this.size = LiveControlSize.medium,
    this.onPressed,
    this.enabled = true,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
  });

  /// The icon to draw.
  final IconData icon;

  /// The tooltip and accessibility label — required, because an icon alone
  /// is not a label anyone can read out.
  final String tooltip;

  /// What the button means.
  final LiveButtonVariant variant;

  /// How large it is.
  final LiveControlSize size;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it renders as toggled on (mute, favourite, danmaku switch).
  final bool selected;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// Whether the button reacts to input at all.
  bool get isInteractive => enabled && onPressed != null;
}

/// The contract of a single-line text field.
@immutable
final class LiveTextFieldSpec {
  /// A text-field spec.
  const new({
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  /// The text controller.
  final TextEditingController? controller;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// The floating label.
  final String? label;

  /// The placeholder.
  final String? hint;

  /// A leading icon.
  final IconData? prefixIcon;

  /// A trailing widget, usually the clear button of a search field.
  final Widget? suffix;

  /// Whether the text is hidden (passwords).
  final bool obscure;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether it takes focus when the view opens.
  final bool autofocus;

  /// Whether the text is selectable but not editable.
  final bool readOnly;

  /// How many lines the field grows to; 1 keeps it single-line.
  final int maxLines;

  /// The on-screen keyboard type.
  final TextInputType? keyboardType;

  /// The keyboard's action key.
  final TextInputAction? textInputAction;

  /// A validation message shown below the field; null hides it.
  final String? errorText;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits.
  final ValueChanged<String>? onSubmitted;
}

/// The contract of a search field: a text field with the search chrome
/// (leading icon, clear action, submit-on-enter) baked in.
@immutable
final class LiveSearchFieldSpec {
  /// A search-field spec.
  const new({
    this.controller,
    this.focusNode,
    this.hint,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  /// The text controller.
  final TextEditingController? controller;

  /// The focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;

  /// The placeholder; the caller supplies a localized string.
  final String? hint;

  /// Whether it takes focus when the view opens — true on TV, where typing
  /// is the only way to search.
  final bool autofocus;

  /// Whether the field accepts input.
  final bool enabled;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the search.
  final ValueChanged<String>? onSubmitted;

  /// Called when the user clears the field; the widget clears the
  /// controller itself when there is one.
  final VoidCallback? onClear;
}

/// The contract of a card.
@immutable
final class LiveCardSpec {
  /// A card spec.
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.dense = false,
    this.selected = false,
    this.padding,
    this.focusNode,
    this.autofocus = false,
  });

  /// The card's content.
  final Widget child;

  /// The tap callback; null makes the card non-interactive (and, on TV,
  /// non-focusable).
  final VoidCallback? onTap;

  /// The long-press callback, for context menus.
  final VoidCallback? onLongPress;

  /// Whether the card packs its content tighter.
  final bool dense;

  /// Whether the card renders as selected.
  final bool selected;

  /// Overrides the token padding when the content manages its own insets
  /// (a cover image flush to the card's edges).
  final EdgeInsetsGeometry? padding;

  /// The focus node, for lists that manage focus themselves.
  final FocusNode? focusNode;

  /// Whether it takes focus when the view opens.
  final bool autofocus;
}

/// One entry of a menu.
@immutable
final class LiveMenuEntry {
  /// A menu entry.
  const new({
    required this.id,
    required this.label,
    this.icon,
    this.enabled = true,
    this.danger = false,
    this.selected = false,
    this.shortcut,
  });

  /// The value reported to the menu's callback.
  final String id;

  /// The entry's text.
  final String label;

  /// An optional leading icon.
  final IconData? icon;

  /// Whether the entry can be chosen.
  final bool enabled;

  /// Whether the entry is destructive.
  final bool danger;

  /// Whether the entry renders as the current choice.
  final bool selected;

  /// A keyboard shortcut hint shown right-aligned, e.g. `Ctrl+C`.
  final String? shortcut;
}

/// The contract of a menu: an anchor widget and the entries to pop up
/// beside it.
@immutable
final class LiveMenuSpec {
  /// A menu spec.
  const new({
    required this.child,
    required this.entries,
    required this.onSelected,
    this.enabled = true,
    this.tooltip,
    this.focusNode,
  });

  /// The anchor the menu opens from.
  final Widget child;

  /// The entries, in display order.
  final List<LiveMenuEntry> entries;

  /// Called with the chosen entry's id; never called for disabled entries.
  final ValueChanged<String> onSelected;

  /// Whether the anchor opens the menu.
  final bool enabled;

  /// An optional tooltip for the anchor.
  final String? tooltip;

  /// The anchor's focus node, for pages that manage focus themselves.
  final FocusNode? focusNode;
}

/// One action of a dialog.
///
/// [result] is what the dialog's future completes with when the action is
/// chosen — the type-safe way for a caller to learn which button was
/// pressed without a second callback.
@immutable
final class LiveDialogAction<T> {
  /// A dialog action.
  const new({
    required this.label,
    required this.result,
    this.variant = LiveButtonVariant.text,
    this.enabled = true,
    this.autofocus = false,
  });

  /// The button's label.
  final String label;

  /// The value the dialog completes with.
  final T result;

  /// What the action means.
  final LiveButtonVariant variant;

  /// Whether the action can be chosen.
  final bool enabled;

  /// Whether it takes focus when the dialog opens; the language gives focus
  /// to the action marked default when none is.
  final bool autofocus;
}

/// The contract of a dialog.
@immutable
final class LiveDialogSpec<T> {
  /// A dialog spec.
  const new({
    required this.actions,
    this.title,
    this.message,
    this.content,
    this.dismissible = true,
    this.maxWidth = 480,
    this.barrierDismissible,
  });

  /// The dialog's title.
  final String? title;

  /// A plain-text body; [content] wins when both are given.
  final String? message;

  /// A custom body.
  final Widget? content;

  /// The actions, in display order.
  final List<LiveDialogAction<T>> actions;

  /// Whether the dialog can be dismissed (escape, barrier, back button);
  /// false makes it modal — for confirmations of destructive work already
  /// under way.
  final bool dismissible;

  /// The dialog's maximum width.
  final double maxWidth;

  /// Whether tapping the barrier dismisses; null follows [dismissible].
  final bool? barrierDismissible;
}

/// The contract of a progress indicator.
@immutable
final class LiveProgressIndicatorSpec {
  /// A progress-indicator spec.
  const new({this.value, this.size = LiveControlSize.medium, this.semanticLabel});

  /// The progress in 0..1, or null for an indeterminate spinner.
  final double? value;

  /// How large the indicator is.
  final LiveControlSize size;

  /// An accessibility label.
  final String? semanticLabel;
}

/// The contract of a full-view loading state.
@immutable
final class LiveLoadingViewSpec {
  /// A loading-view spec.
  const new({this.message, this.value, this.compact = false});

  /// What is being loaded, e.g. "Loading rooms…".
  final String? message;

  /// The progress in 0..1, or null for an indeterminate spinner.
  final double? value;

  /// Whether the view lays out tightly for embedding in a card or a list
  /// instead of filling the page.
  final bool compact;
}

/// The contract of a full-view error state.
@immutable
final class LiveErrorViewSpec {
  /// An error-view spec.
  const new({required this.message, this.details, this.icon, this.retryLabel, this.onRetry, this.compact = false});

  /// What went wrong, in the user's language.
  final String message;

  /// Technical detail for a diagnostics expander; never shown expanded by
  /// default.
  final String? details;

  /// Overrides the error icon.
  final IconData? icon;

  /// The retry button's label; the button appears when this and [onRetry]
  /// are both set.
  final String? retryLabel;

  /// Retries the failed work.
  final VoidCallback? onRetry;

  /// Whether the view lays out tightly for embedding.
  final bool compact;

  /// Whether a retry action is offered.
  bool get canRetry => onRetry != null;
}

/// The contract of a full-view empty state.
@immutable
final class LiveEmptyViewSpec {
  /// An empty-view spec.
  const new({required this.title, this.message, this.icon, this.action, this.compact = false});

  /// The headline, e.g. "No followed rooms".
  final String title;

  /// A sentence explaining what would fill the view.
  final String? message;

  /// Overrides the empty-state icon.
  final IconData? icon;

  /// The primary action offered with the empty state ("Discover rooms").
  final Widget? action;

  /// Whether the view lays out tightly for embedding.
  final bool compact;
}
