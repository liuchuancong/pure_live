import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The shape an avatar can take.
enum LiveAvatarShape {
  /// Fully circular.
  circle,

  /// Rounded square.
  rounded,
}

/// A person or channel avatar — Ant's `Avatar`. Shows [src] when supplied and
/// falls back to initials derived from [name]; the surface and text colours come
/// from theme tokens.
class LiveAvatar extends StatelessWidget {
  /// An avatar.
  const new({this.name, this.src, this.size, this.shape = LiveAvatarShape.circle, super.key});

  /// The display name; used for the initials fallback.
  final String? name;

  /// An optional image.
  final ImageProvider? src;

  /// The edge length; defaults to the large control height.
  final double? size;

  /// Circle or a rounded square.
  final LiveAvatarShape shape;

  /// The initials from [name]: the first letters of up to two words.
  static String initialsOf(String? name) {
    if (name == null) {
      return '';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    final letters = parts.take(2).map((word) => word.substring(0, 1)).join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final edge = size ?? theme.token.scale.controlHeightLG;
    final radius = shape == LiveAvatarShape.circle
        ? BorderRadius.circular(edge)
        : BorderRadius.circular(theme.token.scale.radii.sm);

    final content = src != null
        ? Image(
            image: src!,
            fit: BoxFit.cover,
            width: edge,
            height: edge,
            errorBuilder: (_, _, _) => _initials(theme, edge),
          )
        : _initials(theme, edge);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: edge,
        height: edge,
        child: src == null ? ColoredBox(color: theme.colors.fillSecondary, child: content) : content,
      ),
    );
  }

  Widget _initials(LiveTheme theme, double edge) => Center(
    child: Text(
      initialsOf(name),
      style: theme.text.label.copyWith(
        color: theme.colors.textSecondary,
        fontSize: edge * 0.4,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
