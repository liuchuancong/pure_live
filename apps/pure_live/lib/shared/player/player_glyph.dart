import 'package:flutter/widgets.dart';

/// The player's picture glyphs, drawn from the bundled player art set
/// (`assets/app/icons/player/`): the transport, the danmaku's states, the
/// camera and the window verbs — the vocabulary a video surface speaks —
/// instead of the app's stroke icons.
///
/// Every source file is a white alpha mask, so the glyph is drawn with the
/// same [IconTheme] a `DsIcon` slot resolves — size and color fall back
/// to the ambient theme, and a given color replaces the white with it —
/// which keeps the selected and disabled states of a bar button working.
enum PlayerGlyph {
  /// The play triangle.
  play('play'),

  /// The two pause bars.
  pause('pause'),

  /// A loudspeaker sounding.
  volumeOn('volume_on'),

  /// A loudspeaker struck through.
  volumeOff('volume_off'),

  /// Two arrows parting along the diagonal: into fullscreen.
  fullscreenEnter('fullscreen_enter'),

  /// Two arrows closing along the diagonal: out of fullscreen.
  fullscreenExit('fullscreen_exit'),

  /// The padlock closed: the picture's controls are locked away.
  locked('locked'),

  /// The padlock open.
  unlocked('unlocked'),

  /// The 「弹」 badge: the danmaku is on.
  barrageOn('barrage_on'),

  /// The struck-through 「弹」 badge: the danmaku is off.
  barrageOff('barrage_off'),

  /// A page of lines and a gear: the danmaku's settings.
  barrageSettings('barrage_settings'),

  /// The video camera the recorder and the record verb speak in.
  recordCamera('record_camera'),

  /// The picture-in-a-picture window.
  miniVideo('mini_video'),

  /// Three dots in a row: the overflow menu.
  more('more'),

  /// The bent arrow of a share.
  share('share'),

  /// The cross of a close.
  close('close'),

  /// The outline star of a favourite.
  star('star'),

  /// The left chevron of a step back.
  back('back'),

  /// The right chevron of a step forward.
  forward('forward');

  PlayerGlyph(this.file);

  /// The asset file name under `assets/app/icons/player/`.
  final String file;
}

/// One player glyph at [size], tinted [color].
///
/// A null size or color reads the ambient [IconTheme] the way the stroke
/// icons do, so the glyph drops into a themed slot without the call site
/// learning the theme.
final class GlyphIcon extends StatelessWidget {
  /// The glyph to draw.
  const GlyphIcon(this.kind, {this.size, this.color, super.key});

  /// Which glyph.
  final PlayerGlyph kind;

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
      'assets/app/icons/player/${kind.file}.png',
      width: side,
      height: side,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
    );
  }
}
