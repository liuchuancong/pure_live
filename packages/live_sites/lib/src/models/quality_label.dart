import 'package:meta/meta.dart';

/// How a quality level is described, independent of who described it.
///
/// Platforms name their levels in their own vocabulary — 原画, 蓝光, 超清, and
/// numbers behind them — and a user's stored preference ("prefer 蓝光8M") has
/// to survive a round trip through a site that calls the same level
/// differently. The label is therefore kept *as text* and compared by
/// [normalizedLabel], with the platform's own numeric id kept beside it: the
/// text is what the user recognizes, the id is what the API needs, and
/// [rank] is the only ordering the UI may use.
@immutable
final class QualityLabel {
  /// A quality label.
  const new({required this.label, this.quality, this.rank = 0});

  /// The text the platform showed, shown to the user unchanged.
  final String label;

  /// The platform's own numeric id, when it has one.
  final int? quality;

  /// The level's order, higher being better; platforms that do not rank
  /// their levels report 0 and the order they arrive in is kept.
  final int rank;

  /// Whether [other] names the same level as this one, comparing the
  /// platform id when both carry one and the text otherwise.
  ///
  /// This is what a stored preference is matched with: a user who chose
  /// "原画" on one build must get it on the next, where the id may have
  /// changed but the name has not (or the other way round).
  bool sameAs(QualityLabel other) {
    if (quality != null && other.quality != null) {
      return quality == other.quality;
    }
    return normalizedLabel == other.normalizedLabel;
  }

  /// The label lower-cased, stripped of spaces and punctuation, for
  /// comparisons that must survive cosmetic differences.
  String get normalizedLabel => label.toLowerCase().replaceAll(RegExp(r'[\s_\-()（）]'), '');

  /// The label of [labels] that [preference] names, or null when it names
  /// none of them.
  static QualityLabel? match(Iterable<QualityLabel> labels, String preference) {
    final wanted = QualityLabel(label: preference);
    for (final candidate in labels) {
      if (candidate.sameAs(wanted)) {
        return candidate;
      }
    }
    return null;
  }

  /// [labels] ordered best first, by [rank] and then by the order given.
  static List<QualityLabel> ordered(Iterable<QualityLabel> labels) {
    final ordered = labels.toList()..sort((a, b) => b.rank.compareTo(a.rank));
    return ordered;
  }
}
