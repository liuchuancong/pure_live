import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_page_request.freezed.dart';

/// The pagination a caller asks for.
///
/// The fields the source actually uses depend on the platform (page,
/// offset or cursor); adapters translate without inventing semantics
/// (ARCHITECTURE.md §7.5).
@freezed
abstract class LivePageRequest with _$LivePageRequest {
  /// Creates a LivePageRequest with already-normalized fields.
  const factory LivePageRequest({@Default(1) int page, @Default(20) int pageSize, int? offset, String? cursor}) =
      _LivePageRequest;
}
