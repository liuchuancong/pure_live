import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_sites/src/models/live_search_target/live_search_target.dart';

part 'live_search_request.freezed.dart';

// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed factories
// cannot use the `new` shorthand.

/// A search request for [target] with [query], paged from [page].
@freezed
abstract class LiveSearchRequest with _$LiveSearchRequest {
  /// Creates a search request.
  const factory LiveSearchRequest({
    required String query,
    required LiveSearchTarget target,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _LiveSearchRequest;
}
