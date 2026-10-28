import 'package:flutter/foundation.dart' show immutable;

import 'package:pure_live/l10n/translations.dart';

/// The station's shelves (体裁): the three genres the source's own browse
/// pages split everything into.
enum HongguoGenre {
  /// 短剧: live-action short drama, the shelf with the 今日上新 tag.
  shortPlay('short_play'),

  /// 漫剧: animated comic drama, the shelf with the status filter.
  comicSeries('comic_series'),

  /// AI短剧: the AI-generated shelf.
  aiSeries('ai_series');

  const HongguoGenre(this.wire);

  /// The source's genre id, as the endpoints name it.
  final String wire;

  /// The shelf's own name.
  String label(Translations t) => switch (this) {
    HongguoGenre.shortPlay => t.hongguo.genreShortPlay,
    HongguoGenre.comicSeries => t.hongguo.genreComicSeries,
    HongguoGenre.aiSeries => t.hongguo.genreAiSeries,
  };

  /// The genre behind its [wire] name, or null.
  static HongguoGenre? ofWire(String? wire) {
    for (final genre in HongguoGenre.values) {
      if (genre.wire == wire) return genre;
    }
    return null;
  }
}

/// The comic boards the rank endpoint serves.
enum HongguoBoard {
  /// The recommended board.
  recommend('recommend'),

  /// The most-played board.
  hot('hot'),

  /// The newest board.
  newest('new');

  const HongguoBoard(this.wire);

  /// The board's id, as the endpoint names it.
  final String wire;

  /// The board's own name.
  String label(Translations t) => switch (this) {
    HongguoBoard.recommend => t.hongguo.boardRecommend,
    HongguoBoard.hot => t.hongguo.boardHot,
    HongguoBoard.newest => t.hongguo.boardNew,
  };
}

/// One series as the station's lists name it: the same shape the browse,
/// rank, latest and search endpoints all answer, give or take a field.
@immutable
final class HongguoSeries {
  /// Creates the series card.
  const HongguoSeries({
    required this.seriesId,
    required this.title,
    this.episodeCount = 0,
    this.score = '',
    this.playCount = 0,
    this.cover = '',
    this.horizontalCover = '',
    this.intro = '',
    this.category = '',
    this.copyright = '',
    this.hot = '',
    this.durationSeconds = 0,
    this.vid = '',
    this.coverTags = const [],
    this.rank,
    this.today = false,
    this.premiere = '',
  });

  /// The series the page opens (`/hongguo/series/<id>`).
  final String seriesId;

  /// The series' name.
  final String title;

  /// How many episodes the listing promises.
  final int episodeCount;

  /// The listing's score, as text ("8.6" or empty).
  final String score;

  /// The series' play count.
  final int playCount;

  /// The poster cover; HEIC is common, the image cache handles it.
  final String cover;

  /// The landscape cover, when the listing carries one.
  final String horizontalCover;

  /// One line on the story, already truncated by the source.
  final String intro;

  /// The shelf categories as one line ("玄幻 / 逆袭").
  final String category;

  /// The studio or rights holder.
  final String copyright;

  /// The listing's own heat line ("1.2万人在看") when it has one.
  final String hot;

  /// The first episode's vid, when the listing carries it.
  final String vid;

  /// The first episode's length in seconds.
  final int durationSeconds;

  /// The cover's corner tags (爆剧 / 新剧 / 独播).
  final List<String> coverTags;

  /// The 1-based board position, on a rank listing.
  final int? rank;

  /// Whether the shelf marks the series 今日上新.
  final bool today;

  /// The premiere tag line (首播/独家), when the listing carries one.
  final String premiere;

  /// Reads the series from one listing cell. The endpoints agree on the
  /// field names; anything they disagree on is read defensively.
  static HongguoSeries fromJson(Map<String, Object?> json) => HongguoSeries(
    seriesId: _str(json['series_id'] ?? json['book_id'] ?? json['search_result_id']),
    title: _str(json['title']),
    episodeCount: _int(json['episode_cnt']) ?? 0,
    score: _score(json['score']),
    playCount: _int(json['play_cnt'] ?? json['series_play_cnt']) ?? 0,
    cover: _str(json['cover'] ?? json['series_cover']),
    horizontalCover: _str(json['horiz_cover']),
    intro: _str(json['intro'] ?? json['video_desc']),
    category: _str(json['category']),
    copyright: _str(json['copyright']),
    hot: _str(json['hot'] ?? json['rec_text']),
    durationSeconds: _int(json['duration']) ?? 0,
    vid: _str(json['vid']),
    coverTags: _strList(json['cover_tags']),
    rank: _int(json['rank']),
    today: _bool(json['today']) ?? false,
    premiere: _str(json['premiere']),
  );
}

/// One episode of a series, as the episode listing names it.
@immutable
final class HongguoEpisode {
  /// Creates the episode row.
  const HongguoEpisode({
    required this.index,
    required this.vid,
    this.title = '',
    this.durationSeconds = 0,
    this.cover = '',
    this.commentCount = 0,
    this.diggedCount = 0,
  });

  /// The 1-based episode number.
  final int index;

  /// The episode's vid — the key every playback call asks for.
  final String vid;

  /// The episode's own title, when it has one.
  final String title;

  /// The episode's length in seconds.
  final int durationSeconds;

  /// The episode's cover.
  final String cover;

  /// How many comments the episode carries.
  final int commentCount;

  /// How many likes the episode carries.
  final int diggedCount;

  /// Reads the episode from the detail listing's cells.
  static HongguoEpisode fromJson(Map<String, Object?> json) => HongguoEpisode(
    index: _int(json['index'] ?? json['vid_index']) ?? 0,
    vid: _str(json['vid']),
    title: _str(json['title']),
    durationSeconds: _int(json['duration']) ?? 0,
    cover: _str(json['cover'] ?? json['episode_cover']),
    commentCount: _int(json['comment_count']) ?? 0,
    diggedCount: _int(json['digged_count']) ?? 0,
  );
}

/// A series' own metadata, as the detail endpoint answers it.
@immutable
final class HongguoSeriesMeta {
  /// Creates the series metadata.
  const HongguoSeriesMeta({
    required this.seriesId,
    required this.title,
    this.intro = '',
    this.episodeCount = 0,
    this.finished = false,
    this.statusText = '',
    this.playCount = 0,
    this.followedCount = 0,
    this.cover = '',
    this.categories = const [],
  });

  /// The series this metadata belongs to.
  final String seriesId;

  /// The series' name.
  final String title;

  /// The story blurb.
  final String intro;

  /// How many episodes the series has.
  final int episodeCount;

  /// Whether the source says the series is complete.
  final bool finished;

  /// The status line the source answered ("完结" / "连载中"), kept as sent.
  final String statusText;

  /// The series' play count.
  final int playCount;

  /// The series' follower count.
  final int followedCount;

  /// The poster cover.
  final String cover;

  /// The shelf categories as separate names.
  final List<String> categories;

  /// Reads the metadata half of a detail answer.
  static HongguoSeriesMeta fromJson(Map<String, Object?> json) {
    final status = _str(json['status']);
    return HongguoSeriesMeta(
      seriesId: _str(json['series_id']),
      title: _str(json['title']),
      intro: _str(json['intro'] ?? json['series_intro']),
      episodeCount: _int(json['episode_cnt']) ?? 0,
      finished: status == '完结',
      statusText: status,
      playCount: _int(json['play_cnt'] ?? json['series_play_cnt']) ?? 0,
      followedCount: _int(json['followed_cnt']) ?? 0,
      cover: _str(json['cover'] ?? json['series_cover']),
      categories: _strList(json['category'] ?? json['categories']),
    );
  }
}

/// A series' whole detail page: its metadata and its episode list.
@immutable
final class HongguoSeriesDetail {
  /// Creates the detail.
  const HongguoSeriesDetail({required this.meta, required this.episodes});

  /// The series' metadata.
  final HongguoSeriesMeta meta;

  /// The episodes, in episode order.
  final List<HongguoEpisode> episodes;

  /// Reads a detail answer's `meta`/`episodes` pair.
  static HongguoSeriesDetail fromJson(Map<String, Object?> json) {
    final metaJson = json['meta'];
    final episodesJson = json['episodes'];
    return HongguoSeriesDetail(
      meta: metaJson is Map<String, Object?> ? HongguoSeriesMeta.fromJson(metaJson) : const HongguoSeriesMeta(seriesId: '', title: ''),
      episodes: [
        for (final episode in episodesJson is List<Object?> ? episodesJson : const <Object?>[])
          if (episode is Map<String, Object?>) HongguoEpisode.fromJson(episode),
      ]..sort((a, b) => a.index.compareTo(b.index)),
    );
  }
}

/// One option of a filter dimension.
@immutable
final class HongguoFilterOption {
  /// Creates the option.
  const HongguoFilterOption({required this.id, required this.name});

  /// The option's id, as the browse call passes it back.
  final String id;

  /// The option's name, as the source shows it.
  final String name;

  /// Reads the option from a selector panel cell.
  static HongguoFilterOption fromJson(Map<String, Object?> json) =>
      HongguoFilterOption(id: _str(json['id']), name: _str(json['name']));
}

/// One filter dimension of a shelf's selector panel: the theme, the setting,
/// the era, the sort, the audience, the window and — on the comic shelf —
/// the serialisation status.
@immutable
final class HongguoFilterRow {
  /// Creates the row.
  const HongguoFilterRow({
    required this.type,
    required this.rowName,
    required this.items,
    this.multiple = false,
  });

  /// The dimension's key — the `select_items` name the source's own browse
  /// call carries (`category_dim_theme`, `sort`, …).
  final String type;

  /// The dimension's label.
  final String rowName;

  /// The dimension's options.
  final List<HongguoFilterOption> items;

  /// Whether the source allows several options of this dimension at once.
  final bool multiple;

  /// Reads the row from a selector panel answer.
  static HongguoFilterRow fromJson(Map<String, Object?> json) => HongguoFilterRow(
    type: _str(json['type']),
    rowName: _str(json['row_name']),
    multiple: _int(json['selection_type']) == 2,
    items: [
      for (final item in json['items'] is List<Object?> ? json['items']! as List<Object?> : const <Object?>[])
        if (item is Map<String, Object?>) HongguoFilterOption.fromJson(item),
    ],
  );
}

String _str(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num) return value.toInt() == value ? value.toInt().toString() : value.toString();
  return value.toString();
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool? _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return null;
}

/// The score the listings show, normalised to text: the source sends a
/// string, a number or nothing.
String _score(Object? value) {
  if (value is num) return value.toStringAsFixed(1);
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return '';
}

List<String> _strList(Object? value) {
  if (value is List<Object?>) {
    return [for (final item in value) if (item != null) item.toString()];
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.split('/');
  }
  return const [];
}
