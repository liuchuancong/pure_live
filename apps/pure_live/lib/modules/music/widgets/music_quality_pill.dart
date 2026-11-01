import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart'
    show MusicQuality, musicPlaybackSettingsProvider;

/// The song's quality tier as a pill: the step the module asks the source for,
/// the one this song was actually served, and the four steps to choose between
/// — the settings' 播放品质 row, reached from the bar and the stage without
/// leaving the song.
///
/// Both surfaces write the one preference (`music.play.quality`), so the pill
/// and the settings page cannot disagree. A new step lands on the next song:
/// the engine notes the request and the source is asked at resolution, which is
/// what the menu's last line says instead of pretending the song re-opened.
final class MusicQualityPill extends ConsumerWidget {
  /// The pill.
  const MusicQualityPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final settings = ref.watch(musicPlaybackSettingsProvider);
    final player = ref.watch(musicPlayerProvider.select((state) => (quality: state.quality, track: state.track)));
    final asked = settings.quality;
    final served = player.quality;
    // What the song's own platform lists; the built-in sources fill it from the
    // rendition table. An empty list means the source never said, so the menu
    // claims nothing about it.
    final offered = player.track?.qualities ?? const [];
    final known = offered.isNotEmpty;
    final hintStyle = theme.typography.caption.copyWith(color: colors.textSubtle);
    bool offers(MusicQuality quality) => offered.any((entry) => entry.id == quality.scriptName);
    final askedIsServed = served != null && served.id == asked.scriptName;
    return DsMenuAnchor(
      semanticLabel: t.music.quality,
      items: [
        for (final quality in MusicQuality.values)
          DsMenuItem(
            label: Text(quality.label(t)),
            checked: asked == quality,
            // The tier the song is really served at is marked where it differs
            // from the asked one, so a source's downgrade reads as the
            // source's doing.
            trailing: served != null && served.id == quality.scriptName
                ? Text(askedIsServed ? t.music.qualityServedHere : t.music.qualityDowngraded, style: hintStyle)
                : (known && !offers(quality) ? Text(t.music.qualityNotInSong, style: hintStyle) : null),
            onPressed: () => unawaited(ref.read(musicPlaybackSettingsProvider.notifier).setQuality(quality)),
          ),
        const DsMenuDivider(),
        // A read-only footer: the menu's own note, disabled because choosing
        // it is not a thing.
        DsMenuItem(label: Text(t.music.qualityNextTip), onPressed: null),
      ],
      builder: (context, controller, _) => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        semanticLabel: t.music.quality,
        onPressed: controller.toggle,
        child: Text(asked.label(t), style: theme.typography.caption),
      ),
    );
  }
}
