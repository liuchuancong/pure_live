import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A hover/focus tooltip built directly from the active language's own tooltip
/// where it has one.
///
/// Cupertino, glass, neumorphic and wind ship no tooltip widget, so Flutter's
/// official Material `Tooltip` is the shared fallback instead of a hand-built
/// overlay. [waitDuration] reaches every library that has a slot for its own
/// delay; fluent_2's is a constant inside the library.
class PureTooltip extends StatelessWidget {
  /// A tooltip around [child].
  const new({
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 400),
    super.key,
  });

  /// The text to reveal.
  final String message;

  /// The hovered widget.
  final Widget child;

  /// How long the pointer must rest before the bubble appears.
  final Duration waitDuration;

  @override
  Widget build(BuildContext context) {
    return switch (PureTheme.of(context).config.language) {
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.cupertino ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.neumorphic ||
      PureDesignLanguage.wind => Tooltip(message: message, waitDuration: waitDuration, child: child),
      // `MacosTooltip` has no wait of its own: it reads `waitDuration` off
      // `MacosTooltipTheme`, and that theme is used verbatim rather than merged
      // with the defaults — so the ambient data is taken and only the wait
      // changes, or every other field of the bubble arrives null.
      PureDesignLanguage.macos => macos.MacosTooltipTheme(
        data: macos.MacosTheme.of(context).tooltipTheme.copyWith(waitDuration: waitDuration),
        child: macos.MacosTooltip(message: message, child: child),
      ),
      // fluent_2's tooltip delay is a private 250ms constant: the widget takes
      // no duration and its style has no such field, so the caller's wait has
      // nowhere to go in this library.
      PureDesignLanguage.fluent => f2.FluentTooltip(content: Text(message), child: child),
      // forui's wait is the style's hover-enter duration, which its delta does
      // expose.
      PureDesignLanguage.forui => forui.FTooltip(
        style: forui.FTooltipStyleDelta.delta(hoverEnterDuration: waitDuration),
        tipBuilder: (context, controller) => Text(message),
        child: child,
      ),
    };
  }
}
