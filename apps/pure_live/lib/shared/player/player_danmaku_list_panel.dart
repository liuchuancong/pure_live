import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/on_video_colors.dart';

/// One line of a replay's danmaku list: its position in the recording, its
/// words, and the colour the station gave it. A record, so any source's
/// comments — a controller's history, a decoded file's entries — pour in
/// without a shared model between modules.
typedef PlayerDanmakuLine = ({Duration at, String text, int color});

/// A recording's danmaku list: the comments in the recording's own order,
/// each with its position — a row's tap seeks there.
///
/// Purely presentational: the host owns the data's rebuilds (a controller
/// revision, a provider watch) and hands the lines in. The card is the
/// players' one panel language (the plate, the card's corners, the quiet
/// border), its rows read like the room's danmaku feed — newest at the
/// bottom without a scroll command.
final class PlayerDanmakuListPanel extends StatelessWidget {
  /// The panel over [lines]; a row's tap hands the line's time to [onSeek].
  const PlayerDanmakuListPanel({
    required this.lines,
    required this.onSeek,
    required this.title,
    required this.empty,
    super.key,
  });

  /// The comments, in the recording's own order.
  final List<PlayerDanmakuLine> lines;

  /// Runs when a line is tapped, with the line's own position.
  final ValueChanged<Duration> onSeek;

  /// The card's name, next to the line count.
  final String title;

  /// The words shown when no comment has arrived yet.
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final caption = theme.typography.caption;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
      decoration: BoxDecoration(
        color: OnVideoColors.menuPlate,
        borderRadius: BorderRadius.circular(theme.radii.card),
        border: Border.all(color: OnVideoColors.inkHover),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s6),
            child: Text(
              '$title · ${lines.length}',
              style: caption.copyWith(color: OnVideoColors.inkSubtle, fontWeight: FontWeight.w600),
            ),
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s12),
              child: Text(empty, style: caption.copyWith(color: OnVideoColors.inkSubtle)),
            )
          else
            // Reversed like the room's feed: item 0 sits at the bottom, so
            // the comment just delivered stays in view without a command.
            Flexible(
              child: ListView.builder(
                reverse: true,
                padding: EdgeInsets.zero,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[lines.length - 1 - index];
                  return DsPressable(
                    semanticLabel: line.text,
                    onPressed: () => onSeek(line.at),
                    builder: (context, states, _) {
                      final active = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                      return Container(
                        color: active ? OnVideoColors.inkHover : null,
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s5),
                        child: Row(
                          spacing: DsSpace.s8,
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(
                                _clock(line.at),
                                style: caption.copyWith(fontSize: 11, color: OnVideoColors.inkSubtle),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                line.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                // The colour the comment flies in, the
                                // recording's own palette kept on the page.
                                style: caption.copyWith(color: Color(line.color)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The row's own clock: minutes and seconds, hours prefixed when the
  /// recording runs past one — a list column reads narrower than the bar's.
  static String _clock(Duration at) {
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = at.inHours;
    final minutes = at.inMinutes % 60;
    final seconds = at.inSeconds % 60;
    return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '$minutes:${two(seconds)}';
  }
}
