import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The blank an opening CJK punctuation leaves before its ink.
///
/// 【 (and its relatives) is drawn about 0.56 em into its full-width cell —
/// the Windows CJK families measure between 0.43 and 0.64 em — so a line that
/// starts with one begins further right than a line that starts with a han
/// character, even when both boxes share a left edge. A caption printed under
/// such a title takes the same blank so the two read as one left edge.
double recorderPunctuationHang(String text, double fontSize) {
  const openers = {
    0x2018, 0x201C, // ‘ “
    0x3008, 0x300A, 0x300C, 0x300E, // 〈 《 「 『
    0x3010, 0x3014, 0x3016, 0x3018, 0x301A, // 【 〔 〖 〘 〚
    0xFF08, 0xFF3B, 0xFF5B, // （ ［ ｛
  };
  if (text.isEmpty || !openers.contains(text.runes.first)) return 0;
  return fontSize * 0.56;
}

/// The edge a recorder panel's list sections wear.
///
/// The theme draws a section's edge as an outer hairline: one device pixel at
/// 8% ink, which on a panel's white surface halves away between pixels and is
/// clipped at the scroll top. An inner ring in the border ink reads as a line
/// and stays inside the card's own bounds.
DsListSectionStyle recorderPanelSectionStyle(BuildContext context) =>
    DsListSectionStyle(shadows: [DsShadow.innerRing(DsTheme.colorsOf(context).border)]);

/// One small fact on a recorder card: the room's platform with its mark, a
/// category, a take's size or rate.
///
/// The subscription cards and the takes both print their facts this way, so
/// the two lists read as one page with two views rather than two designs.
final class RecorderTagChip extends StatelessWidget {
  /// Creates a chip; [icon] leads the text when the fact has a mark.
  const RecorderTagChip({required this.text, this.icon, super.key});

  /// The chip's word.
  final String text;

  /// A small mark before the word, usually a platform glyph.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return DecoratedBox(
      decoration: DsBoxDecoration(color: colors.hover, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s4,
          children: [
            ?icon,
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
