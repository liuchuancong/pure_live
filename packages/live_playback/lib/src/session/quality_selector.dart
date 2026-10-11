import 'package:live_sites/live_sites.dart';

/// Picks a quality and orders lines when a session starts or recovers.
///
/// The strategy is deliberately small: a preferred label wins when the
/// platform offers it, otherwise the best available one; the recovery
/// ladder walks down this order.
final class QualitySelector {
  /// A selector preferring [preferredLabel] exactly, and otherwise the
  /// highest `sort` quality first.
  const new({this.preferredLabel});

  /// The user's preferred quality label, when one is configured.
  final String? preferredLabel;

  /// The qualities in play order, best first.
  List<LivePlayQuality> order(List<LivePlayQuality> qualities) {
    final ordered = [...qualities]..sort((a, b) => b.sort.compareTo(a.sort));
    final preferred = preferredLabel;
    if (preferred == null || preferred.isEmpty) {
      return ordered;
    }
    final index = ordered.indexWhere((quality) => quality.label == preferred);
    if (index <= 0) {
      return ordered;
    }
    return [ordered[index], ...ordered.where((quality) => quality.label != preferred)];
  }

  /// The first quality to try, or null for an empty list.
  LivePlayQuality? first(List<LivePlayQuality> qualities) => order(qualities).firstOrNull;
}
