// Module: lib/src/models/live/live_audience/live_audience.dart
// Purpose: One room's audience, with each figure's own meaning kept instead of collapsing them into one number.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/platform-models.md §11. The reference product carries the same split on its room model
// (`onlineViewers` / `totalViewers` / `popularity` / `watching` plus `AudienceMetricType`); here it is its own
// model because a site reports a *subset* and a surface needs to know which ones exist.
//
// A null field means the endpoint did not state it; a zero means it stated zero. Those render differently, and
// it is the same rule that made this package stop reading missing numbers as 0 everywhere else.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../support/json.dart';
import '../live_audience_metric/live_audience_metric.dart';

part 'live_audience.freezed.dart';
part 'live_audience.g.dart';

/// The audience a source reported for one room.
@freezed
abstract class LiveAudience with _$LiveAudience {
  const factory LiveAudience({
    /// Concurrent viewers, when the site reports them (huya `totalCount`, acfun `onlineCount`).
    @JsonKey(fromJson: _count, toJson: _count) int? onlineViewers,

    /// Total visits since the broadcast began. Monotonic; never a headcount of who watches now.
    @JsonKey(fromJson: _count, toJson: _count) int? totalViewers,

    /// A computed heat score (douyu `room_biz_all.hot`, kugou `hot`). It ranks rooms; it does not count people.
    @JsonKey(fromJson: _count, toJson: _count) int? popularity,

    /// The figure exactly as the platform worded it ("9.8万"、"热度 12.3万"), for surfaces that show the site's
    /// own text rather than our formatting of a number.
    @JsonKey(fromJson: _label) String? label,

    /// What [label] - or the primary number above - actually measures.
    @JsonKey(fromJson: _metric) @Default(LiveAudienceMetric.unknown) LiveAudienceMetric metric,
  }) = _LiveAudience;

  const LiveAudience._();

  factory LiveAudience.fromJson(Map<String, Object?> json) => _$LiveAudienceFromJson(json);

  /// The number a surface shows first, in the order the site actually stated one. Nothing is invented: when a
  /// site reports only a heat score, callers get the heat score and [metric] says what it is.
  int? get primary => onlineViewers ?? totalViewers ?? popularity;

  bool get isReported => primary != null || (label?.isNotEmpty ?? false);

  /// Whether [primary] counts people. A false here means "do not print this as 人在看".
  bool get countsPeople => metric == LiveAudienceMetric.onlineViewers || metric == LiveAudienceMetric.totalViewers;

  /// The three fields at once, for the sites that report one number and name its kind.
  factory LiveAudience.ofMetric(int? value, LiveAudienceMetric metric) => LiveAudience(
    onlineViewers: metric == LiveAudienceMetric.onlineViewers ? value : null,
    totalViewers: metric == LiveAudienceMetric.totalViewers ? value : null,
    popularity: metric == LiveAudienceMetric.popularity ? value : null,
    metric: value == null ? LiveAudienceMetric.unknown : metric,
  );
}

int? _count(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

String? _label(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

LiveAudienceMetric _metric(Object? value) =>
    enumByName(LiveAudienceMetric.values, value as String?) ?? LiveAudienceMetric.unknown;
