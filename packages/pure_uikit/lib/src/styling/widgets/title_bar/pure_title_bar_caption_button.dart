import 'package:flutter/material.dart';

/// A reusable caption button for title bar window controls.
///
/// The button delegates its operation to [onPressed], keeping window
/// management details outside the UI kit.
class PureTitleBarCaptionButton extends StatelessWidget {
  /// Creates a reusable title bar caption button.
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.buttonKey,
    this.width = 46,
    this.height = 32,
    this.iconSize = 16,
    this.foregroundColor,
    this.backgroundColor,
    this.hoverColor,
    this.borderRadius = BorderRadius.zero,
    this.semanticLabel,
    super.key,
  });

  /// The icon displayed inside the button.
  final IconData icon;

  /// The tooltip displayed when the pointer hovers over the button.
  final String tooltip;

  /// The action invoked when the button is pressed.
  final VoidCallback onPressed;

  /// A stable key used to identify the button.
  final Key buttonKey;

  /// The width of the button.
  final double width;

  /// The height of the button.
  final double height;

  /// The size of the button icon.
  final double iconSize;

  /// The icon and text foreground color.
  final Color? foregroundColor;

  /// The button background color.
  final Color? backgroundColor;

  /// The button background color while hovered.
  final Color? hoverColor;

  /// The radius applied to the button background.
  final BorderRadiusGeometry borderRadius;

  /// An optional semantic label for accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      key: buttonKey,
      width: width,
      height: height,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: iconSize,
        color: foregroundColor ?? theme.colorScheme.onSurface,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered)) {
              return hoverColor;
            }

            return backgroundColor;
          }),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: borderRadius)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: WidgetStatePropertyAll(Size(width, height)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, semanticLabel: semanticLabel),
      ),
    );
  }
}
