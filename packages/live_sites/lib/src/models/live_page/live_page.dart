import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_page.freezed.dart';

// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed factories
// cannot use the `new` shorthand.

/// One page of results plus the pagination facts the source actually gave.
///
/// An unknown total stays null; an empty page is not the same as
/// end-of-pagination, and adapters keep the two distinct where the source can.
@freezed
abstract class LivePage<T> with _$LivePage<T> {
  /// Creates a page of [items] with optional [totalCount], [nextCursor] and
  /// [hasMore].
  const factory LivePage({required List<T> items, int? totalCount, String? nextCursor, bool? hasMore}) = _LivePage<T>;
}
