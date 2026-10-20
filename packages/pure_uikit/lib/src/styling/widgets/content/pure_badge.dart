import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A status badge anchored to [child] — Ant's `Badge`.
///
/// The pill is Flutter's official Material `Badge` when the badge is anchored
/// to [child] — that widget owns the corner-indicator grammar every language
/// needs here — and the active language's own badge component when it stands
/// alone as a tag.
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

  /// An optional background override (defaults to the error colour). Fluent and
  /// forui resolve it to the nearest colour family rather than to the exact
  /// colour, because that is all their badge component takes.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final bt = theme.badge;
    final background = color ?? bt.background;
    // The badge's colour family: the component token seeds the background from
    // the error colour, and the family is as far as fluent and forui can be
    // told — both name a badge's colour by what it means, not by a value.
    final isErrorBadge = background == theme.token.color.error;

    final String? text;
    if (dot) {
      text = null;
    } else if (count case final c?) {
      text = c > max ? '$max+' : '$c';
    } else {
      text = label;
    }

    // Two components share this contract, and they disagree on size. Anchored
    // to a child, a badge is a small indicator in its corner — Flutter's
    // official `Badge` is the only widget with that grammar, because fluent's
    // and forui's pills are *tags*: laid out at their own padding, a count over
    // a 36dp avatar filled the avatar. Standalone, the text is a tag and the
    // library's own badge is the right thing to draw.
    final anchored = child != null;

    final Widget pill = switch (theme.config.language) {
      // Both of these libraries name a badge's colour by its semantic family
      // rather than by a colour, so the token's error background selects the
      // danger family and any other choice the brand/primary one.
      PureDesignLanguage.fluent when !anchored && !dot && text != null => f2.FluentBadge(
        size: f2.FluentBadgeSize.small,
        color: isErrorBadge ? f2.FluentBadgeColor.danger : f2.FluentBadgeColor.brand,
        child: Text(text),
      ),
      PureDesignLanguage.forui when !anchored && !dot && text != null => forui.FBadge(
        variant: isErrorBadge ? forui.FBadgeVariant.destructive : forui.FBadgeVariant.primary,
        child: Text(text),
      ),
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
