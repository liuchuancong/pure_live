import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_page.freezed.dart';

/// One page of results, carrying whatever pagination facts the source gave.
///
/// An unknown total stays unknown; `hasMore` is null when the source does not
/// say. An empty [items] list is a successful empty page, never a failure.
@freezed
abstract class LivePage<T> with _$LivePage<T> {
  /// Creates a LivePage with already-normalized fields.
  const factory LivePage({required List<T> items, int? totalCount, String? nextCursor, bool? hasMore}) = _LivePage<T>;
}
