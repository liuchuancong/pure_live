import 'package:flutter/painting.dart' show BoxFit;
import 'package:live_sites/live_sites.dart' show LivePlayQuality, LiveStreamCodec;

/// The quality to start a room with — the reference's `defaultQualityIndex`
/// (3.x `_setDefaultResolution`): the one labelled like the preference, else
/// the same relative position in the list (3.x's five names, best to worst).
///
/// With [preferH264] (the 优先 H.264 setting) a name match whose codec hint
/// is HEVC is passed over while the room offers anything else: the relative
/// position decides, and should it land on HEVC too the nearest other
/// quality is taken (the better one on a tie). HEVC is then played only when
/// picked by hand or when nothing else is on offer (G01.3).
int defaultQualityIndex(List<LivePlayQuality> qualities, String preferred, {bool preferH264 = false}) {
  if (qualities.isEmpty) {
    return 0;
  }
  bool hevc(int index) => qualities[index].codec == LiveStreamCodec.hevc;
  final exact = qualities.indexWhere((quality) => quality.label == preferred);
  final skip =
      exact >= 0 && preferH264 && hevc(exact) && qualities.any((quality) => quality.codec != LiveStreamCodec.hevc);
  if (exact >= 0 && !skip) {
    return exact;
  }
  final position = _relativePosition(qualities.length, preferred);
  if (!skip || !hevc(position)) {
    return position;
  }
  for (var distance = 1; distance < qualities.length; distance++) {
    for (final index in [position - distance, position + distance]) {
      if (index >= 0 && index < qualities.length && !hevc(index)) {
        return index;
      }
    }
  }
  return position;
}

/// The index at [preferred]'s place among 3.x's five names, scaled to
/// [length] qualities; the first for a name not among them.
int _relativePosition(int length, String preferred) {
  final level = playQualityNames.indexOf(preferred);
  if (level < 0) {
    return 0;
  }
  final ratio = level / (playQualityNames.length - 1);
  return (ratio * (length - 1)).round().clamp(0, length - 1);
}

/// The quality names the preference speaks (3.x `PlayerConsts.resolutions`).
const List<String> playQualityNames = ['原画', '蓝光8M', '蓝光4M', '超清', '流畅'];

/// The six viewport fits, in the reference's stored-index order
/// (`videoFitIndex`: default, crop, fill, height, width, scale-down); the
/// settings row, the room menu and the open-time default all speak this list.
const List<BoxFit> videoFits = [
  BoxFit.contain,
  BoxFit.cover,
  BoxFit.fill,
  BoxFit.fitHeight,
  BoxFit.fitWidth,
  BoxFit.scaleDown,
];

/// [videoFits] index of [fit]; 0 for a fit outside the list.
int videoFitIndexOf(BoxFit fit) {
  final index = videoFits.indexOf(fit);
  return index < 0 ? 0 : index;
}
