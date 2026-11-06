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
/// The bundled art sets' shared shape: a directory under
/// `assets/app/icons/` and the file names inside it.
abstract interface class GlyphSet {
  /// The set's directory under `assets/app/icons/`.
  String get directory;

  /// The file's name inside [directory], extension included.
  String get file;
}

enum PlayerGlyph implements GlyphSet {
  /// The play triangle.
  play('play.png'),

  /// The two pause bars.
  pause('pause.png'),

  /// A loudspeaker sounding.
  volumeOn('volume_on.png'),

  /// A loudspeaker struck through.
  volumeOff('volume_off.png'),

  /// Two arrows parting along the diagonal: into fullscreen.
  fullscreenEnter('fullscreen_enter.png'),

  /// Two arrows closing along the diagonal: out of fullscreen.
  fullscreenExit('fullscreen_exit.png'),

  /// The padlock closed: the picture's controls are locked away.
  locked('locked.png'),

  /// The padlock open.
  unlocked('unlocked.png'),

  /// The 「弹」 badge: the danmaku is on.
  barrageOn('barrage_on.png'),

  /// The struck-through 「弹」 badge: the danmaku is off.
  barrageOff('barrage_off.png'),

  /// A page of lines and a gear: the danmaku's settings.
  barrageSettings('barrage_settings.png'),

  /// The video camera the recorder and the record verb speak in.
  recordCamera('record_camera.png'),

  /// The picture-in-a-picture window.
  miniVideo('mini_video.png'),

  /// Three dots in a row: the overflow menu.
  more('more.png'),

  /// The bent arrow of a share.
  share('share.png'),

  /// The cross of a close.
  close('close.png'),

  /// The outline star of a favourite.
  star('star.png'),

  /// The left chevron of a step back.
  back('back.png'),

  /// The right chevron of a step forward.
  forward('forward.png');

  PlayerGlyph(this.file);

  @override
  String get directory => 'player';

  /// The asset file name under [directory].
  @override
  final String file;
}

/// The music player's own art set (`assets/app/icons/music/`), QQ music's
/// big transport family: the movement verbs, the play modes, the queue, the
/// download states and the song's heart.
enum MusicGlyph implements GlyphSet {
  /// The play disc: a filled circle around the triangle.
  play('play.png'),

  /// The two pause bars in their disc.
  pause('pause.png'),

  /// The step-back skip: triangle and bar pointing left.
  previous('previous.png'),

  /// The step-forward skip: triangle and bar pointing right.
  next('next.png'),

  /// Lines and a note: the playing queue.
  queue('queue.png'),

  /// Circular arrows: the list loops.
  repeat('repeat.png'),

  /// The same arrows around a 1: the song loops.
  repeatOne('repeat_one.png'),

  /// Crossing arrows: random order.
  random('random.png'),

  /// The arrow into a tray: this song can be taken offline.
  download('download.png'),

  /// The tray's arrow with a check: the song is already offline.
  downloaded('downloaded.png'),

  /// The song's heart (a red one in the source art; tint replaces it).
  like('like.webp'),

  /// Three dots in a row: the overflow menu.
  more('more.png');

  MusicGlyph(this.file);

  @override
  String get directory => 'music';

  /// The asset file name under [directory].
  @override
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
  final GlyphSet kind;

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
      'assets/app/icons/${kind.directory}/${kind.file}',
      width: side,
      height: side,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
    );
  }
}
