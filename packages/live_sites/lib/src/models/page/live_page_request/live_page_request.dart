// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';

part 'live_page_request.g.dart';

/// The pagination a caller asks for.
///
/// The fields the source actually uses depend on the platform (page,
/// offset or cursor); adapters translate without inventing semantics
/// (ARCHITECTURE.md §7.5).
abstract class LivePageRequest implements Built<LivePageRequest, LivePageRequestBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LivePageRequest([void Function(LivePageRequestBuilder)? updates]) = _$LivePageRequest;

  /// Creates a LivePageRequest with already-normalized fields.
  factory LivePageRequest.of({int page = 1, int pageSize = 20, int? offset, String? cursor}) => LivePageRequest(
    (b) => b
      ..page = page
      ..pageSize = pageSize
      ..offset = offset
      ..cursor = cursor,
  );

  LivePageRequest._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LivePageRequestBuilder b) => b
    ..page = 1
    ..pageSize = 20;

  /// The 1-based page number.
  int get page;

  /// How many items a page carries.
  int get pageSize;

  /// The offset the source wants, when it pages that way.
  int? get offset;

  /// The cursor the source wants, when it pages that way.
  String? get cursor;
}
