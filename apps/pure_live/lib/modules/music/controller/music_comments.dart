import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart' show musicTrackKey;
import 'package:pure_live/modules/music/controller/music_source.dart' show kwMusicSourceProvider;

/// Kuwo's comment endpoints only answer the mobile client's user agent.
const String _userAgent = 'Dalvik/2.1.0 (Linux; U; Android 9;)';

/// One comment under a song — the reference's 评论.
final class MusicComment {
  /// Creates a comment.
  const MusicComment({
    required this.id,
    required this.text,
    required this.userName,
    this.avatar,
    this.time,
    this.likedCount = 0,
    this.replies = const [],
  });

  /// Reads one entry; null when it carries no text.
  static MusicComment? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = '${json['msg'] ?? ''}'.trim();
    if (text.isEmpty) return null;
    final seconds = int.tryParse('${json['time'] ?? ''}');
    final rawReplies = json['child_comments'];
    return MusicComment(
      id: '${json['id'] ?? ''}',
      text: text,
      userName: '${json['u_name'] ?? ''}',
      avatar: _stringOf(json['u_pic']),
      time: seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      likedCount: int.tryParse('${json['like_num'] ?? ''}') ?? 0,
      replies: [for (final entry in rawReplies is List ? rawReplies : const []) ?MusicComment.fromJson(entry)],
    );
  }

  /// The comment's own id.
  final String id;

  /// Its text.
  final String text;

  /// The nickname that wrote it.
  final String userName;

  /// The writer's avatar address.
  final String? avatar;

  /// When it was written.
  final DateTime? time;

  /// How many people liked it.
  final int likedCount;

  /// Replies shown under it.
  final List<MusicComment> replies;

  static String? _stringOf(Object? value) {
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}

/// What the comment sheet holds: the song, the tab, the next page and the
/// in-flight flag.
typedef MusicCommentsState = ({
  String trackKey,
  bool hot,
  List<MusicComment> comments,
  int page,
  bool hasMore,
  bool loading,
  String? error,
});

MusicCommentsState _initial() =>
    (trackKey: '', hot: true, comments: const <MusicComment>[], page: 0, hasMore: false, loading: false, error: null);

/// One song's comments, hot first, then the newest — the reference's two
/// comment tabs.
///
/// Requests are generation-guarded: a tab switch or a new song makes the
/// previous answer drain without writing, so a slow page cannot land in the
/// wrong tab.
final class MusicCommentsController extends Notifier<MusicCommentsState> {
  static const int _pageSize = 20;
  static const int _hotPageSize = 100;

  int _generation = 0;
  audio.MusicTrack? _track;

  @override
  MusicCommentsState build() => _initial();

  /// Loads the first page of [track]'s comments for the selected tab.
  Future<void> load(audio.MusicTrack track, {required bool hot}) async {
    final generation = ++_generation;
    _track = track;
    state = (
      trackKey: musicTrackKey(track),
      hot: hot,
      comments: const <MusicComment>[],
      page: 0,
      hasMore: false,
      loading: true,
      error: null,
    );
    await _fetch(generation, track, hot, 1);
  }

  /// Appends the next page of the tab on screen.
  Future<void> loadMore() async {
    final track = _track;
    if (track == null || state.loading || !state.hasMore) return;
    state = (
      trackKey: state.trackKey,
      hot: state.hot,
      comments: state.comments,
      page: state.page,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    await _fetch(_generation, track, state.hot, state.page + 1);
  }

  /// Retries the page that failed.
  Future<void> retry() async {
    final track = _track;
    if (track == null) return;
    final page = state.page == 0 ? 1 : state.page + 1;
    state = (
      trackKey: state.trackKey,
      hot: state.hot,
      comments: state.comments,
      page: state.page,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    await _fetch(_generation, track, state.hot, page);
  }

  Future<void> _fetch(int generation, audio.MusicTrack track, bool hot, int page) async {
    try {
      final result = await _request(track, hot: hot, page: page);
      if (!ref.mounted || generation != _generation) return;
      state = (
        trackKey: musicTrackKey(track),
        hot: hot,
        comments: page == 1 ? result.comments : [...state.comments, ...result.comments],
        page: page,
        hasMore: result.hasMore,
        loading: false,
        error: null,
      );
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (
        trackKey: musicTrackKey(track),
        hot: hot,
        comments: state.comments,
        page: page == 1 ? 0 : state.page,
        hasMore: state.hasMore,
        loading: false,
        error: '$failure',
      );
    }
  }

  Future<({List<MusicComment> comments, bool hasMore})> _request(
    audio.MusicTrack track, {
    required bool hot,
    required int page,
  }) async {
    final pageSize = hot ? _hotPageSize : _pageSize;
    final uri = Uri.http('ncomment.kuwo.cn', '/com.s', {
      'f': 'web',
      'type': hot ? 'get_rec_comment' : 'get_comment',
      'aapiver': '1',
      'prod': 'kwplayer_ar_10.5.2.0',
      'digest': '15',
      'sid': track.id,
      'start': '${pageSize * (page - 1)}',
      'msgflag': '1',
      'count': '$pageSize',
      'newver': '3',
      'uid': '0',
    });
    final json = await ref.read(kwMusicSourceProvider).getJson(uri, userAgent: _userAgent);
    final raw = json[hot ? 'hot_comments' : 'comments'];
    final total = int.tryParse('${json[hot ? 'hot_comments_counts' : 'comments_counts'] ?? ''}') ?? 0;
    final comments = [for (final entry in raw is List ? raw : const []) ?MusicComment.fromJson(entry)];
    final maxPage = total <= 0 ? 1 : (total / pageSize).ceil();
    return (comments: comments, hasMore: page < maxPage);
  }
}

/// The comment sheet's comments.
final musicCommentsProvider = NotifierProvider<MusicCommentsController, MusicCommentsState>(
  MusicCommentsController.new,
);
