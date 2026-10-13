import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_page_request.freezed.dart';

// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed factories
// cannot use the `new` shorthand.

/// A pagination request. One model covers page-based, offset-based and
/// cursor-based sources; a platform adapter translates its real behavior into
/// this without fabricating a total from a page size.
@freezed
abstract class LivePageRequest with _$LivePageRequest {
  /// Creates a request starting at [page] with [pageSize] items, optionally
  /// offset-based ([offset]) or cursor-based ([cursor]).
  const factory LivePageRequest({@Default(1) int page, @Default(20) int pageSize, int? offset, String? cursor}) =
      _LivePageRequest;
}
