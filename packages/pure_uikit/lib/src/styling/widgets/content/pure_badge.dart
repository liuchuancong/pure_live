import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A status badge anchored to [child] — Ant's `Badge`.
///
/// The pill itself is the active language's own badge component where one
/// exists; the languages whose library ships no badge use Flutter's official
/// Material `Badge`.
class PureBadge extends StatelessWidget {
  /// A badge.
  const new({
    this.child,
    this.count,
    this.label,
    this.dot = false,
    this.enabled = true,
    this.max = 99,
    this.color,
    super.key,
  });

  /// The widget the badge is anchored to; omit for a standalone badge.
  final Widget? child;

  /// A numeric count; shows `max+` when it exceeds [max]. Null hides the count.
  final int? count;

  /// A text label for the pill (used when [count] is null).
  final String? label;

  /// Whether to render a small dot instead of a pill.
  final bool dot;

  /// Whether the badge is shown at all.
  final bool enabled;

  /// The count ceiling before it collapses to `max+`.
  final int max;

  /// An optional background override (defaults to the error colour).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final bt = theme.badge;
    final background = color ?? bt.background;

    final String? text;
    if (dot) {
      text = null;
    } else if (count case final c?) {
      text = c > max ? '$max+' : '$c';
    } else {
      text = label;
    }

    final Widget pill = switch (theme.config.language) {
      PureDesignLanguage.fluent when !dot && text != null => f2.FluentBadge(
        size: f2.FluentBadgeSize.small,
        child: Text(text),
      ),
      PureDesignLanguage.forui when !dot && text != null => forui.FBadge(child: Text(text)),
      // Material, Yaru, Cupertino, macOS, glass, neumorphic and wind use
      // Flutter's official Material Badge; the dot form also uses it, because
      // several libraries' badges require a label.
      _ => Badge(
        backgroundColor: background,
        smallSize: dot ? bt.dotSize : null,
        label: dot || text == null ? null : Text(text),
      ),
    };

    if (!enabled || (text == null && !dot)) {
      return child ?? const SizedBox.shrink();
    }
    if (child == null) {
      return pill;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        Positioned(
          top: -bt.offset,
          right: -bt.offset,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.colors.bgContainer, borderRadius: BorderRadius.circular(bt.height)),
            child: pill,
          ),
        ),
      ],
    );
  }
}
