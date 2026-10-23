// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';

part 'live_page.g.dart';

/// One page of results, carrying whatever pagination facts the source gave.
///
/// An unknown total stays unknown; `hasMore` is null when the source does not
/// say. An empty [items] list is a successful empty page, never a failure.
abstract class LivePage<T> implements Built<LivePage<T>, LivePageBuilder<T>> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LivePage([void Function(LivePageBuilder<T>)? updates]) = _$LivePage<T>;

  /// Creates a LivePage with already-normalized fields.
  factory LivePage.of({required List<T> items, int? totalCount, String? nextCursor, bool? hasMore}) => LivePage<T>(
    (b) => b
      ..items.replace(items)
      ..totalCount = totalCount
      ..nextCursor = nextCursor
      ..hasMore = hasMore,
  );

  LivePage._();

  /// The page's items.
  BuiltList<T> get items;

  /// The total count, when the source says so.
  int? get totalCount;

  /// The cursor the next page asks for, when the source pages that way.
  String? get nextCursor;

  /// Whether more pages follow, when the source says so.
  bool? get hasMore;
}
