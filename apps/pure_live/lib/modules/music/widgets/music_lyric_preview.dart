import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart' show MusicLyricAlignment, musicSettingsProvider;
import 'package:pure_live/modules/music/controller/sources/chinese_s2t.dart' show traditionalize;

/// The lyric settings' own sample: three fixed lines drawn with the pane's
/// current choices — their size, their alignment, the active line's zoom and
/// the secondary line's presence and order — so a change is seen here rather
/// than only in the player. A sample, not a song: the lines are the module's
/// dummy text, the same way the danmaku page shows its own sample.
final class MusicLyricPreview extends ConsumerWidget {
  /// The sample card.
  const MusicLyricPreview({super.key});

  /// The sample's lines; the middle one is the line "on air".
  static const List<String> _sample = ['夜色漫过窗台', '我把耳机戴好', '让这一首歌把世界放慢'];

  /// The secondary texts the two switches turn on; the swap flips their order.
  static const String _translation = 'The night spills over the windowsill';
  static const String _romanization = 'yè sè màn guò chuāng tái';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final settings = ref.watch(musicSettingsProvider);
    final scale = settings.lyricFontScale / 100;
    const active = 1;
    final (alignment, cross, textAlign) = switch (settings.lyricAlignment) {
      MusicLyricAlignment.left => (Alignment.centerLeft, CrossAxisAlignment.start, TextAlign.left),
      MusicLyricAlignment.center => (Alignment.center, CrossAxisAlignment.center, TextAlign.center),
      MusicLyricAlignment.right => (Alignment.centerRight, CrossAxisAlignment.end, TextAlign.right),
    };
    // What a line carries under it, in the viewer's order; traditionalizing
    // rewrites the sample exactly as it would a fetched lyric.
    final secondary = [if (settings.showTranslation) _translation, if (settings.showRomanization) _romanization];
    final ordered = settings.swapLyricSecondary ? secondary.reversed.toList() : secondary;
    final bodySize = theme.typography.body.fontSize ?? 14;
    final captionSize = theme.typography.caption.fontSize ?? 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.music.lyricPreviewHint, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
        DsSurface(
          decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20, vertical: DsSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              if (settings.lyricProgress) DsProgressBar(value: 0.42, semanticLabel: t.music.lyricProgress),
              for (final (index, line) in _sample.indexed)
                Align(
                  alignment: alignment,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: cross,
                    children: [
                      Text(
                        settings.traditionalizeLyric ? traditionalize(line) : line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: theme.typography.body.copyWith(
                          fontSize: bodySize * scale * (settings.lyricZoomActive && index == active ? 1.1 : 1),
                          color: index == active ? colors.text : colors.textMuted,
                          fontWeight: index == active ? FontWeight.w600 : null,
                        ),
                      ),
                      if (ordered.isNotEmpty)
                        Text(
                          ordered.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: textAlign,
                          style: theme.typography.caption.copyWith(
                            fontSize: captionSize * scale,
                            color: colors.textSubtle,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The desktop overlay's own sample: the floating window lives in a window of
/// its own, so the page draws the line it would show — the chosen colour,
/// stroke, size, gap, alignment and the vertical switch — on the dark wash the
/// overlay uses.
final class MusicDesktopLyricPreview extends ConsumerWidget {
  /// The sample card.
  const MusicDesktopLyricPreview({super.key});

  /// The line the overlay would be showing, and the one beside it.
  static const String _line = '夜色漫过窗台';
  static const String _beside = '我把耳机戴好';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final settings = ref.watch(musicSettingsProvider);
    final size = settings.desktopLyricFontSize;
    final textColor = Color(settings.desktopLyricTextColor);
    final strokeColor = Color(settings.desktopLyricStrokeColor);
    final stroke = settings.desktopLyricStrokeWidth;
    final alignment = switch (settings.desktopLyricAlignment) {
      audio.DesktopLyricAlignment.left => Alignment.centerLeft,
      audio.DesktopLyricAlignment.center => Alignment.center,
      audio.DesktopLyricAlignment.right => Alignment.centerRight,
    };
    final textAlign = switch (settings.desktopLyricAlignment) {
      audio.DesktopLyricAlignment.left => TextAlign.left,
      audio.DesktopLyricAlignment.center => TextAlign.center,
      audio.DesktopLyricAlignment.right => TextAlign.right,
    };
    // The overlay's stroke is a painted outline behind the fill; the sample
    // draws it the same way, and skips it when the width is zero.
    Widget line(String text, {required double fontSize, Color? color, FontWeight? weight}) {
      final style = theme.typography.body.copyWith(fontSize: fontSize, color: color ?? textColor, fontWeight: weight);
      final fill = Text(text, textAlign: textAlign, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
      if (stroke <= 0) return fill;
      return Stack(
        children: [
          Text(
            text,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
              fontWeight: weight,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = stroke
                ..strokeJoin = StrokeJoin.round
                ..color = strokeColor,
            ),
          ),
          fill,
        ],
      );
    }

    final current = line(_line, fontSize: size, weight: settings.desktopLyricBoldLine ? FontWeight.w700 : null);
    final beside = line(
      _beside,
      fontSize: size * 0.7,
      color: textColor.withValues(alpha: 0.8),
      weight: settings.desktopLyricBoldExtended ? FontWeight.w700 : null,
    );
    final lines = settings.desktopLyricVertical
        ? [
            // The overlay stacks characters when it is vertical; the sample
            // stacks the same way so the shape is honest.
            Wrap(
              direction: Axis.vertical,
              spacing: 2,
              alignment: WrapAlignment.center,
              children: [
                for (final char in _line.split(''))
                  Text(
                    char,
                    style: theme.typography.body.copyWith(
                      fontSize: size,
                      color: textColor,
                      fontWeight: settings.desktopLyricBoldLine ? FontWeight.w700 : null,
                    ),
                  ),
              ],
            ),
          ]
        : [current, SizedBox(height: settings.desktopLyricLineGap.toDouble()), beside];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.music.desktopLyricPreviewHint, style: theme.typography.caption.copyWith(color: theme.colors.textSubtle)),
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
          child: Container(
            height: 168,
            padding: const EdgeInsets.all(DsSpace.s16),
            color: const Color(0xCC121417),
            child: Opacity(
              opacity: settings.desktopLyricOpacity,
              child: Align(
                alignment: alignment,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: switch (settings.desktopLyricAlignment) {
                    audio.DesktopLyricAlignment.left => CrossAxisAlignment.start,
                    audio.DesktopLyricAlignment.center => CrossAxisAlignment.center,
                    audio.DesktopLyricAlignment.right => CrossAxisAlignment.end,
                  },
                  children: lines,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
