import 'package:flutter/widgets.dart';

/// The player's picture glyphs, drawn from Huya's own player art set
/// (`assets/app/icons/huya/`): the transport and the camera the recorder
/// speaks in, instead of the app's stroke icons.
///
/// Every source file is a white alpha mask, so the glyph is drawn with the
/// same [IconTheme] a `DsIcon` slot resolves — size and color fall back
/// to the ambient theme, and a given color replaces the white with it —
/// which keeps the selected and disabled states of a bar button working.
enum HuyaVideoGlyph {
  /// The play triangle.
  play('play'),

  /// The two pause bars.
  pause('pause'),

  /// Two arrows parting along the diagonal: into fullscreen.
  fullscreenEnter('fullscreen_enter'),

  /// Two arrows closing along the diagonal: out of fullscreen.
  fullscreenExit('fullscreen_exit'),

  /// The video camera the recorder and the record verb speak in.
  recordCamera('record_camera'),

  /// The picture-in-a-picture window.
  miniVideo('mini_video');

  HuyaVideoGlyph(this.file);

  /// The asset file name under `assets/app/icons/huya/`.
  final String file;
}

/// One Huya glyph at [size], tinted [color].
///
/// A null size or color reads the ambient [IconTheme] the way the stroke
/// icons do, so the glyph drops into a themed slot without the call site
/// learning the theme.
final class HuyaVideoIcon extends StatelessWidget {
  /// The glyph to draw.
  const HuyaVideoIcon(this.kind, {this.size, this.color, super.key});

  /// Which glyph.
  final HuyaVideoGlyph kind;

  /// Width and height; the icon theme's size, then 16, when null.
  final double? size;

  /// The tint; the icon theme's color when null. The source art is white,
  /// so the tint replaces it wholesale.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 16.0;
    final tint = color ?? theme.color;
    return Image.asset(
      'assets/app/icons/huya/${kind.file}.png',
      width: side,
      height: side,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
    );
  }
}
