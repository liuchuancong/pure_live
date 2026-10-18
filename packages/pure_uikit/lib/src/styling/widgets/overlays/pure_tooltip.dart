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
/// overlay.
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
      PureDesignLanguage.macos => macos.MacosTooltip(message: message, child: child),
      PureDesignLanguage.fluent => f2.FluentTooltip(content: Text(message), child: child),
      PureDesignLanguage.forui => forui.FTooltip(tipBuilder: (context, controller) => Text(message), child: child),
    };
  }
}
