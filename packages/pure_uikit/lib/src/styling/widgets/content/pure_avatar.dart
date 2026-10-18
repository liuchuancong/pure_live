import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The shape an avatar can take.
enum PureAvatarShape {
  /// Fully circular.
  circle,

  /// Rounded square.
  rounded,
}

/// A person or channel avatar built from the active language's own avatar
/// component where it has one, and Flutter's official `CircleAvatar` where it
/// does not.
class PureAvatar extends StatelessWidget {
  /// An avatar.
  const new({this.name, this.src, this.size, this.shape = PureAvatarShape.circle, super.key});

  /// The display name; used for the initials fallback.
  final String? name;

  /// An optional image.
  final ImageProvider? src;

  /// The edge length; defaults to the large control height.
  final double? size;

  /// Circle or a rounded square.
  final PureAvatarShape shape;

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
    final theme = PureTheme.of(context);
    final edge = size ?? theme.token.scale.controlHeightLG;
    final initials = initialsOf(name);
    final rounded = shape == PureAvatarShape.rounded;

    return switch (theme.config.language) {
      PureDesignLanguage.fluent => f2.FluentAvatar(
        image: src,
        initials: initials.isEmpty ? null : initials,
        name: name,
        size: _fluentSize(edge),
        shape: rounded ? f2.FluentAvatarShape.square : f2.FluentAvatarShape.circular,
      ),
      PureDesignLanguage.forui =>
        src == null
            ? forui.FAvatar.raw(
                size: edge,
                child: Text(initials, maxLines: 1, overflow: TextOverflow.clip),
              )
            : forui.FAvatar(
                image: src!,
                size: edge,
                fallback: Text(initials, maxLines: 1, overflow: TextOverflow.clip),
              ),
      // Material, Yaru, Cupertino, macOS, glass, neumorphic and wind either
      // ship no avatar or ship one without an image/initials slot. Flutter's
      // official CircleAvatar is the shared fallback; the token colours keep it
      // inside this theme.
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.cupertino ||
      PureDesignLanguage.macos ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.neumorphic ||
      PureDesignLanguage.wind => CircleAvatar(
        radius: edge / 2,
        backgroundColor: theme.colors.fillSecondary,
        foregroundImage: src,
        foregroundColor: theme.colors.textSecondary,
        child: src == null
            ? Text(
                initials,
                style: theme.text.label.copyWith(
                  color: theme.colors.textSecondary,
                  fontSize: edge * 0.4,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    };
  }

  /// Fluent avatars are enum-sized; pick the nearest published step.
  static f2.FluentAvatarSize _fluentSize(double edge) {
    const sizes = <(double, f2.FluentAvatarSize)>[
      (16, f2.FluentAvatarSize.size16),
      (20, f2.FluentAvatarSize.size20),
      (24, f2.FluentAvatarSize.size24),
      (28, f2.FluentAvatarSize.size28),
      (32, f2.FluentAvatarSize.size32),
      (36, f2.FluentAvatarSize.size36),
      (40, f2.FluentAvatarSize.size40),
      (48, f2.FluentAvatarSize.size48),
      (56, f2.FluentAvatarSize.size56),
      (64, f2.FluentAvatarSize.size64),
      (72, f2.FluentAvatarSize.size72),
      (96, f2.FluentAvatarSize.size96),
      (120, f2.FluentAvatarSize.size120),
    ];
    return sizes.reduce((best, next) => (next.$1 - edge).abs() < (best.$1 - edge).abs() ? next : best).$2;
  }
}
