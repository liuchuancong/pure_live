import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_area.freezed.dart';
part 'live_area.g.dart';

/// A quality level as the platform names and numbers it.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LivePlayQuality with _$LivePlayQuality {
  /// A quality descriptor. [data] is a runtime cache owned by the platform
  /// adapter (a variant or seat recipe a later `getPlayUrls` re-opens with);
  /// it never enters JSON and never survives a database round trip.
  const factory LivePlayQuality({
    required String label,
    int? quality,
    @Default(0) int sort,
    String? codec,
    @JsonKey(includeToJson: false, includeFromJson: false) Object? data,
  }) = _LivePlayQuality;

  /// Restores a quality from JSON.
  factory LivePlayQuality.fromJson(Map<String, Object?> json) => _$LivePlayQualityFromJson(json);
}

/// A directory area (分区) with its platform id and optional parent.
@freezed
abstract class LiveArea with _$LiveArea {
  /// An area descriptor.
  const factory LiveArea({required String id, required String name, String? parentId, @Default(0) int sort}) =
      _LiveArea;

  /// Restores an area from JSON.
  factory LiveArea.fromJson(Map<String, Object?> json) => _$LiveAreaFromJson(json);
}

/// A directory page: one page of rooms plus the pagination facts.
@Freezed(genericArgumentFactories: true)
abstract class LivePage<T> with _$LivePage<T> {
  /// A page of [items]; [hasMore] is the authoritative continuation
  /// signal, [nextPage] the page number to request next when known.
  const factory LivePage({required List<T> items, @Default(false) bool hasMore, int? nextPage, int? totalCount}) =
      _LivePage<T>;

  /// Restores a page from JSON (items decoded by the caller's [T]).
  factory LivePage.fromJson(Map<String, Object?> json, T Function(Object? json) fromJsonT) =>
      _$LivePageFromJson(json, fromJsonT);
}
