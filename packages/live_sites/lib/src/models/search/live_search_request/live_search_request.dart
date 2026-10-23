// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';

part 'live_search_request.g.dart';

/// A search request for one content type.
///
/// A blank [query] or invalid pagination fails at the API boundary; the
/// target must be one the site actually searches (`LiveSearchProvider
/// .supportedTargets`), never silently narrowed.
abstract class LiveSearchRequest implements Built<LiveSearchRequest, LiveSearchRequestBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveSearchRequest([void Function(LiveSearchRequestBuilder)? updates]) = _$LiveSearchRequest;

  /// Creates a LiveSearchRequest with already-normalized fields.
  factory LiveSearchRequest.of({
    required String query,
    required LiveSearchTarget target,
    int page = 1,
    int pageSize = 20,
  }) => LiveSearchRequest(
    (b) => b
      ..query = query
      ..target = target
      ..page = page
      ..pageSize = pageSize,
  );

  LiveSearchRequest._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveSearchRequestBuilder b) => b
    ..page = 1
    ..pageSize = 20;

  /// What is searched for.
  String get query;

  /// What content type is searched.
  LiveSearchTarget get target;

  /// The 1-based page number.
  int get page;

  /// How many items a page carries.
  int get pageSize;
}
