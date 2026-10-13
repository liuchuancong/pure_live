import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_search_request.freezed.dart';

/// A search request for one content type.
///
/// A blank [query] or invalid pagination fails at the API boundary; the
/// target must be one the site actually searches (`LiveSearchProvider
/// .supportedTargets`), never silently narrowed.
@freezed
abstract class LiveSearchRequest with _$LiveSearchRequest {
  /// Creates a LiveSearchRequest with already-normalized fields.
  const factory LiveSearchRequest({
    required String query,
    required LiveSearchTarget target,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _LiveSearchRequest;
}
