// Module: lib/src/models/live/anchor_summary/anchor_summary.dart
// Purpose: A person a source can be searched for, as opposed to a room or a video.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (anchor search). Existence evidence for the shape is in
// docs/sources/live/*.md: searching for a streamer is a separate query from searching their room on every
// platform that has both, because the endpoint, the paging and the result row all differ.
//
// 直播域的模型,住在 `models/live/`,不和通用内容、点播混在一起。freezed + json_annotation 生成相等 /
// copyWith / toJson(package-architecture.md §2.1),但每个字段仍挂一个显式转换器:平台送来的 `ref` 可能是
// `Map<Object?,Object?>`,`fans` 可能是数字也可能是数字字符串 —— 生成器默认那套会在这种形状上抛,而这里
// "读不出来" 的正确答案是 "没说",不是崩。

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../support/json.dart';
import '../../content/content_ref/content_ref.dart';

part 'anchor_summary.freezed.dart';
part 'anchor_summary.g.dart';

/// One anchor as search results and follow rows describe them.
@freezed
abstract class AnchorSummary with _$AnchorSummary {
  const factory AnchorSummary({
    /// The anchor as content: following someone is a ref, and every other column here is display.
    @JsonKey(fromJson: refFromJson, toJson: refToJson) required ContentRef ref,
    @JsonKey(fromJson: _name) required String name,
    @JsonKey(fromJson: _text, includeIfNull: false) String? avatar,

    /// Follower count as the platform wrote it; null means it did not say, which is not zero.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull, includeIfNull: false) int? fans,

    /// The room they are in right now, when the platform knows. This is what makes the row tappable: an anchor
    /// without a live room opens a profile, not a player.
    @JsonKey(fromJson: refFromJsonOrNull, toJson: refToJsonOrNull, includeIfNull: false) ContentRef? currentRoom,
    @JsonKey(fromJson: _text, includeIfNull: false) String? description,
    @JsonKey(fromJson: _map, toJson: _mapOut) @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = _AnchorSummary;

  const AnchorSummary._();

  factory AnchorSummary.fromJson(Map<String, Object?> json) => _$AnchorSummaryFromJson(json);

  bool get isLiveNow => currentRoom != null;

  @override
  String toString() => 'AnchorSummary($name${fans == null ? '' : ' $fans fans'})';
}

String _name(Object? value) => value is String ? value : '${value ?? ''}';

String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

int? _intOrNull(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

Map<String, Object?> _map(Object? value) => asObjectMap(value);

Map<String, Object?> _mapOut(Map<String, Object?> value) => value;
