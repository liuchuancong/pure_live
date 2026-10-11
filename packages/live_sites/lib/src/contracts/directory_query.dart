import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_sites/src/models/live_area.dart';
import 'package:live_sites/src/models/live_room.dart';

part 'directory_query.freezed.dart';

/// What a caller wants from a site's directory.
///
/// A seam for pages: the discover page, the search box and a category browser
/// all ask the same question — "give me rooms" — and differ only in which
/// filter they carry. Passing this value instead of calling the three
/// methods by name means a page can hold a query in its state, rebuild it
/// from user input, and hand it to whichever site the user picked, without a
/// switch over the three shapes at every call site.
///
/// The rule from the site contract is preserved: a directory is a query, not
/// a room. Room-level operations take a [LiveRoom]; a directory browse has no
/// room yet, which is exactly why this type exists.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
sealed class DirectoryQuery with _$DirectoryQuery {
  /// The site's own recommendation feed.
  const factory DirectoryQuery.recommend({@Default(1) int page}) = RecommendQuery;

  /// The rooms of one area of the site.
  const factory DirectoryQuery.category({required LiveArea area, @Default(1) int page}) = CategoryQuery;

  /// A keyword search over live rooms.
  const factory DirectoryQuery.search({required String keyword, @Default(1) int page}) = SearchQuery;
}

/// The query's page number, whichever shape it is.
extension DirectoryQueryPage on DirectoryQuery {
  /// The 1-based page this query asks for.
  int get page => switch (this) {
    RecommendQuery(:final page) => page,
    CategoryQuery(:final page) => page,
    SearchQuery(:final page) => page,
  };

  /// The same query for another page.
  DirectoryQuery withPage(int page) => switch (this) {
    RecommendQuery() => DirectoryQuery.recommend(page: page),
    CategoryQuery(:final area) => DirectoryQuery.category(area: area, page: page),
    SearchQuery(:final keyword) => DirectoryQuery.search(keyword: keyword, page: page),
  };

  /// A one-line description, for logs and diagnostics.
  String get describe => switch (this) {
    RecommendQuery() => 'recommend page $page',
    CategoryQuery(:final area) => 'category ${area.id} page $page',
    SearchQuery(:final keyword) => 'search "$keyword" page $page',
  };
}
