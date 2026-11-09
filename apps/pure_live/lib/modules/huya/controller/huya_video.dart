import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';

/// The Huya video site's client over the shared transport.
///
/// The `api` profile fits the site's fixed endpoints, and the transport stays
/// behind the shared transport, so proxies remain the app shell's business. Nothing on
/// this site asks for a login, so no account cookie rides along.
final huyaVideoApiProvider = Provider<HuyaVideoApi>((ref) {
  // The transport is the process's own: [DioFactory.create] hands the same
  // instance to every `api` caller, so closing it here would kill the next
  // request of the whole app.
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  return HuyaVideoApi(http);
});

/// A readable failure from anything a controller caught.
VodFailure _failure(Object failure) => failure is VodFailure ? failure : VodFailure('$failure');

/// The home's shelves, its loading flag and the last failure.
typedef HuyaHomeState = ({HuyaVideoHome? home, bool loading, VodFailure? error});

/// The station's home: one page of shelves, read once and kept across tabs.
final class HuyaVideoHomeController extends Notifier<HuyaHomeState> {
  @override
  HuyaHomeState build() => (home: null, loading: false, error: null);

  /// Loads the shelves when the page arrives without them.
  Future<void> open() async {
    if (state.home != null || state.loading) return;
    await refresh();
  }

  /// Reads the shelves again, keeping what is on screen while it asks.
  Future<void> refresh() async {
    state = (home: state.home, loading: true, error: null);
    try {
      final home = await ref.read(huyaVideoApiProvider).home();
      if (!ref.mounted) return;
      state = (home: home, loading: false, error: null);
    } on Object catch (failure) {
      if (!ref.mounted) return;
      state = (home: state.home, loading: false, error: _failure(failure));
    }
  }
}

/// The station's home shelves.
final huyaVideoHomeProvider = NotifierProvider<HuyaVideoHomeController, HuyaHomeState>(HuyaVideoHomeController.new);

/// One listing the page may walk: a channel inside a group, in one order.
final class HuyaListRequest {
  /// A listing request.
  const new({required this.channelId, required this.setId, required this.order});

  /// The channel the listing is of; `all` stands for the group itself.
  final String channelId;

  /// The group the listing is narrowed to; zero stands for the whole site.
  final int setId;

  /// The order the station sorts in.
  final HuyaVideoOrder order;

  /// The cache key this listing is kept under.
  String get key => '$channelId|$setId|${order.key}';
}

/// One listing's videos, the next page it asks and its load state.
typedef HuyaListState = ({List<HuyaVideo> videos, int nextPage, bool hasMore, bool loading, VodFailure? error});

const HuyaListState _emptyList = (videos: <HuyaVideo>[], nextPage: 1, hasMore: true, loading: false, error: null);

/// The browse surface: the station's groups, the listing on screen and the
/// listings already walked (a tab switch keeps what was loaded).
final class HuyaBrowseState {
  /// A browse surface.
  const new({
    this.groups = const <HuyaChannelGroup>[],
    this.groupsLoading = false,
    this.groupId = 0,
    this.channelId = 'all',
    this.setId = 0,
    this.order = HuyaVideoOrder.hot,
    this.lists = const <String, HuyaListState>{},
    this.error,
  });

  /// The station's channel groups, in its own order.
  final List<HuyaChannelGroup> groups;

  /// Whether the groups are being read.
  final bool groupsLoading;

  /// The group the page stands in, whichever channel is picked inside it.
  final int groupId;

  /// The channel on screen.
  final String channelId;

  /// The group on screen.
  final int setId;

  /// The order on screen.
  final HuyaVideoOrder order;

  /// Every listing walked so far, keyed by [HuyaListRequest.key].
  final Map<String, HuyaListState> lists;

  /// The last failure of the groups or of the listing on screen.
  final VodFailure? error;

  /// The listing on screen.
  HuyaListRequest get request => HuyaListRequest(channelId: channelId, setId: setId, order: order);

  /// The listing on screen's state.
  HuyaListState get current => lists[request.key] ?? _emptyList;

  /// A copy with the named fields replaced.
  HuyaBrowseState copyWith({
    List<HuyaChannelGroup>? groups,
    bool? groupsLoading,
    int? groupId,
    String? channelId,
    int? setId,
    HuyaVideoOrder? order,
    Map<String, HuyaListState>? lists,
    VodFailure? error,
    bool clearError = false,
  }) => HuyaBrowseState(
    groups: groups ?? this.groups,
    groupsLoading: groupsLoading ?? this.groupsLoading,
    groupId: groupId ?? this.groupId,
    channelId: channelId ?? this.channelId,
    setId: setId ?? this.setId,
    order: order ?? this.order,
    lists: lists ?? this.lists,
    error: clearError ? null : (error ?? this.error),
  );
}

/// The station's browse page: its groups and the paged listing inside them.
final class HuyaBrowseController extends Notifier<HuyaBrowseState> {
  /// Pages in a row that brought nothing new, per listing key.
  final Map<String, int> _stagnant = {};

  @override
  HuyaBrowseState build() => const HuyaBrowseState();

  /// Loads the groups and the listing on screen when the page arrives.
  Future<void> open() async {
    if (state.groups.isNotEmpty) {
      await openList();
      return;
    }
    if (state.groupsLoading) return;
    state = state.copyWith(groupsLoading: true, clearError: true);
    try {
      final groups = await ref.read(huyaVideoApiProvider).groups();
      if (!ref.mounted) return;
      // A shelf may have walked into a channel before the strip was read:
      // the group that holds it becomes the strip's own now.
      final groupId = state.groupId == 0 && state.channelId != 'all'
          ? groups
                    .where((group) => group.channels.any((channel) => channel.id == state.channelId))
                    .firstOrNull
                    ?.setId ??
                0
          : state.groupId;
      state = state.copyWith(groups: groups, groupsLoading: false, groupId: groupId);
      await openList();
    } on Object catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(groupsLoading: false, error: _failure(failure));
    }
  }

  /// Walks into [group] as a whole.
  Future<void> selectGroup(HuyaChannelGroup group) async {
    if (state.groupId == group.setId && state.channelId == 'all' && state.setId == group.setId) return;
    state = state.copyWith(groupId: group.setId, channelId: 'all', setId: group.setId, clearError: true);
    await openList();
  }

  /// Walks into [channel] of [group]; the group's own 全部 keeps its id.
  Future<void> selectChannel(HuyaChannelGroup group, HuyaChannel channel) async {
    final channelId = channel.id;
    final setId = channelId == 'all' ? group.setId : 0;
    if (state.groupId == group.setId && state.channelId == channelId && state.setId == setId) return;
    state = state.copyWith(groupId: group.setId, channelId: channelId, setId: setId, clearError: true);
    await openList();
  }

  /// Walks into [channelId] from outside the page (a home shelf): the group
  /// that holds it becomes the strip's own, so the page opens where the
  /// channel lives rather than on 全部.
  Future<void> walkInto(String channelId) async {
    final group = state.groups.where((group) => group.channels.any((channel) => channel.id == channelId)).firstOrNull;
    state = state.copyWith(groupId: group?.setId ?? 0, channelId: channelId, setId: 0, clearError: true);
    await openList();
  }

  /// Sorts the listing on screen another way.
  Future<void> selectOrder(HuyaVideoOrder order) async {
    if (state.order == order) return;
    state = state.copyWith(order: order, clearError: true);
    await openList();
  }

  /// Loads the listing on screen's first page when it has none.
  Future<void> openList() async {
    final current = state.current;
    if (current.videos.isNotEmpty || current.loading) return;
    await _load(state.request, 1);
  }

  /// Loads the next page of the listing on screen.
  Future<void> loadMore() async {
    final current = state.current;
    if (current.loading || !current.hasMore) return;
    await _load(state.request, current.nextPage);
  }

  /// Reloads the listing on screen from its first page.
  Future<void> refresh() => _load(state.request, 1);

  Future<void> _load(HuyaListRequest request, int page) async {
    final current = state.lists[request.key] ?? _emptyList;
    if (current.loading) return;
    state = state.copyWith(
      lists: {
        ...state.lists,
        request.key: (
          videos: current.videos,
          nextPage: current.nextPage,
          hasMore: current.hasMore,
          loading: true,
          error: null,
        ),
      },
      clearError: true,
    );
    try {
      final answer = await ref
          .read(huyaVideoApiProvider)
          .list(channelId: request.channelId, setId: request.setId, order: request.order, page: page);
      if (!ref.mounted) return;
      final open = state.lists[request.key];
      if (open == null) return;
      final merged = page == 1 ? [...answer.videos] : [...open.videos];
      if (page > 1) {
        final seen = {for (final video in merged) video.id};
        merged.addAll(answer.videos.where((video) => seen.add(video.id)));
      }
      // The walk ends after two unchanged pages even if the station still
      // claims more, so a listing that ignores its page argument cannot spin
      // the grid's load-more.
      final fresh = page == 1 || merged.length > open.videos.length;
      final stagnant = fresh ? 0 : (_stagnant[request.key] ?? 0) + 1;
      _stagnant[request.key] = stagnant;
      state = state.copyWith(
        lists: {
          ...state.lists,
          request.key: (
            videos: List<HuyaVideo>.unmodifiable(merged),
            nextPage: answer.page + 1,
            hasMore: answer.hasMore && stagnant < 2,
            loading: false,
            error: null,
          ),
        },
      );
    } on Object catch (failure) {
      if (!ref.mounted) return;
      final open = state.lists[request.key];
      if (open == null) return;
      final failureOf = _failure(failure);
      state = state.copyWith(
        lists: {
          ...state.lists,
          request.key: (videos: open.videos, nextPage: open.nextPage, hasMore: false, loading: false, error: failureOf),
        },
        error: failureOf,
      );
    }
  }
}

/// The station's browse page.
final huyaBrowseProvider = NotifierProvider<HuyaBrowseController, HuyaBrowseState>(HuyaBrowseController.new);

/// The boards, the stand on screen and its rows.
final class HuyaRankState {
  /// A rank surface.
  const new({
    this.boards = const <HuyaRankBoard>[],
    this.boardId = 'all',
    this.videos = const <HuyaVideo>[],
    this.nextPage = 1,
    this.hasMore = true,
    this.loading = false,
    this.updatedAt,
    this.error,
  });

  /// The boards the station ranks.
  final List<HuyaRankBoard> boards;

  /// The board on screen.
  final String boardId;

  /// Its rows, best first.
  final List<HuyaVideo> videos;

  /// The next page it asks.
  final int nextPage;

  /// Whether another page follows.
  final bool hasMore;

  /// Whether a page is in flight.
  final bool loading;

  /// When the station last recomputed the board.
  final DateTime? updatedAt;

  /// The last failure.
  final VodFailure? error;

  /// A copy with the named fields replaced.
  HuyaRankState copyWith({
    List<HuyaRankBoard>? boards,
    String? boardId,
    List<HuyaVideo>? videos,
    int? nextPage,
    bool? hasMore,
    bool? loading,
    DateTime? updatedAt,
    VodFailure? error,
    bool clearError = false,
    bool clearUpdatedAt = false,
  }) => HuyaRankState(
    boards: boards ?? this.boards,
    boardId: boardId ?? this.boardId,
    videos: videos ?? this.videos,
    nextPage: nextPage ?? this.nextPage,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    error: clearError ? null : (error ?? this.error),
  );
}

/// The station's ranking surface.
final class HuyaRankController extends Notifier<HuyaRankState> {
  @override
  HuyaRankState build() => const HuyaRankState();

  /// Loads the boards and the board on screen when the page arrives.
  Future<void> open() async {
    if (state.boards.isEmpty) {
      if (state.loading) return;
      state = state.copyWith(loading: true, clearError: true);
      try {
        final boards = await ref.read(huyaVideoApiProvider).boards();
        if (!ref.mounted) return;
        state = state.copyWith(boards: boards, boardId: boards.first.id, loading: false);
      } on Object catch (failure) {
        if (!ref.mounted) return;
        state = state.copyWith(loading: false, hasMore: false, error: _failure(failure));
        return;
      }
    }
    if (state.videos.isEmpty) await _load(1);
  }

  /// Walks onto [boardId], keeping each board's own page walk.
  Future<void> select(String boardId) async {
    if (state.boardId == boardId) return;
    state = state.copyWith(
      boardId: boardId,
      videos: const <HuyaVideo>[],
      nextPage: 1,
      clearUpdatedAt: true,
      clearError: true,
    );
    await _load(1);
  }

  /// Loads the board's next page.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(state.nextPage);
  }

  /// Reloads the board from its first page.
  Future<void> refresh() => _load(1);

  Future<void> _load(int page) async {
    if (state.loading) return;
    final boardId = state.boardId;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final answer = await ref.read(huyaVideoApiProvider).rank(channelId: boardId, page: page);
      if (!ref.mounted || state.boardId != boardId) return;
      final merged = page == 1 ? [...answer.videos] : [...state.videos];
      if (page > 1) {
        final seen = {for (final video in merged) video.id};
        merged.addAll(answer.videos.where((video) => seen.add(video.id)));
      }
      state = state.copyWith(
        videos: List<HuyaVideo>.unmodifiable(merged),
        nextPage: answer.page + 1,
        hasMore: answer.hasMore,
        loading: false,
        updatedAt: answer.updatedAt,
      );
    } on Object catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, hasMore: false, error: _failure(failure));
    }
  }
}

/// The station's ranking surface.
final huyaRankProvider = NotifierProvider<HuyaRankController, HuyaRankState>(HuyaRankController.new);

/// One search answer: the word, its rows, the index's own count and the
/// loading flag. The index walks no pages, so the rows are the whole answer.
final class HuyaSearchState {
  /// A search answer.
  const new({this.query = '', this.videos = const <HuyaVideo>[], this.total = 0, this.loading = false, this.error});

  /// The word the answer belongs to; empty before the first search.
  final String query;

  /// The rows, best match first.
  final List<HuyaVideo> videos;

  /// How many the index says it holds.
  final int total;

  /// Whether the answer is being read.
  final bool loading;

  /// The last failure.
  final VodFailure? error;

  /// Whether a word has been searched.
  bool get ran => query.isNotEmpty;
}

/// The station's search: one answer per word, no paging.
final class HuyaSearchController extends Notifier<HuyaSearchState> {
  @override
  HuyaSearchState build() => const HuyaSearchState();

  /// Searches [word]; the same word already answered is not asked again.
  Future<void> search(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    final current = state;
    if (current.query == trimmed && (current.loading || current.videos.isNotEmpty || current.error == null)) return;
    state = HuyaSearchState(query: trimmed, loading: true);
    try {
      final answer = await ref.read(huyaVideoApiProvider).search(trimmed);
      if (!ref.mounted || state.query != trimmed) return;
      state = HuyaSearchState(query: trimmed, videos: answer.videos, total: answer.total);
    } on Object catch (failure) {
      if (!ref.mounted || state.query != trimmed) return;
      state = HuyaSearchState(query: trimmed, error: _failure(failure));
    }
  }

  /// Forgets the answer, so the page returns to its own content.
  void clear() => state = const HuyaSearchState();
}

/// The station's search answer.
final huyaSearchProvider = NotifierProvider<HuyaSearchController, HuyaSearchState>(HuyaSearchController.new);

/// The word the shell's toolbar search handed to the station's page; the
/// page takes it and shows its answer in place of its own content.
final class HuyaInlineSearchController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Hands [word] to the page on screen.
  void hand(String word) => state = word.trim();

  /// Returns the page to its own content.
  void clear() => state = null;
}

/// The word the station's page should show next.
final huyaInlineSearchProvider = NotifierProvider<HuyaInlineSearchController, String?>(HuyaInlineSearchController.new);

/// One video's own page, read once per id and kept while the player is open.
final FutureProviderFamily<HuyaVideoDetail, String> huyaVideoDetailProvider =
    FutureProvider.family<HuyaVideoDetail, String>((ref, id) => ref.watch(huyaVideoApiProvider).detail(id));

/// The videos the station puts beside one; a refused read is an empty rail,
/// never a failed picture.
final FutureProviderFamily<List<HuyaVideo>, String> huyaRelatedProvider =
    FutureProvider.family<List<HuyaVideo>, String>((ref, id) => ref.watch(huyaVideoApiProvider).related(id));

/// One uploader's page: the owner, their rows and the page walk.
final class HuyaUploaderState {
  /// An uploader page.
  const new({
    this.uid = '',
    this.uploader,
    this.videos = const <HuyaVideo>[],
    this.recommended = const <HuyaVideo>[],
    this.nextPage = 1,
    this.hasMore = true,
    this.loading = false,
    this.error,
  });

  /// The uploader the page belongs to.
  final String uid;

  /// Its owner, once the first page answered.
  final HuyaUploader? uploader;

  /// The rows, newest first.
  final List<HuyaVideo> videos;

  /// The videos the station recommends for the uploader's 主页.
  final List<HuyaVideo> recommended;

  /// The next page the page asks.
  final int nextPage;

  /// Whether another page follows.
  final bool hasMore;

  /// Whether a page is in flight.
  final bool loading;

  /// The last failure.
  final VodFailure? error;
}

/// One uploader's videos, paged.
final class HuyaUploaderController extends Notifier<HuyaUploaderState> {
  @override
  HuyaUploaderState build() => const HuyaUploaderState();

  /// Opens [uid]'s page; another uid starts it over.
  Future<void> open(String uid) async {
    if (state.uid == uid && (state.uploader != null || state.loading)) return;
    state = HuyaUploaderState(uid: uid);
    await _load(1);
  }

  /// Loads the next page.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(state.nextPage);
  }

  /// Reads the page again from its first page.
  Future<void> refresh() => _load(1);

  Future<void> _load(int page) async {
    if (state.loading) return;
    final uid = state.uid;
    state = HuyaUploaderState(
      uid: uid,
      uploader: state.uploader,
      videos: state.videos,
      recommended: state.recommended,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
    );
    try {
      final answer = await ref.read(huyaVideoApiProvider).uploader(uid, page: page);
      if (!ref.mounted || state.uid != uid) return;
      final merged = page == 1 ? [...answer.videos] : [...state.videos];
      if (page > 1) {
        final seen = {for (final video in merged) video.id};
        merged.addAll(answer.videos.where((video) => seen.add(video.id)));
      }
      state = HuyaUploaderState(
        uid: uid,
        uploader: answer.uploader,
        videos: List<HuyaVideo>.unmodifiable(merged),
        recommended: page == 1 ? List<HuyaVideo>.unmodifiable(answer.recommended) : state.recommended,
        nextPage: answer.page + 1,
        hasMore: answer.hasMore,
      );
    } on Object catch (failure) {
      if (!ref.mounted || state.uid != uid) return;
      state = HuyaUploaderState(
        uid: uid,
        uploader: state.uploader,
        videos: state.videos,
        recommended: state.recommended,
        nextPage: state.nextPage,
        hasMore: false,
        error: _failure(failure),
      );
    }
  }
}

/// One uploader's page.
final huyaUploaderProvider = NotifierProvider<HuyaUploaderController, HuyaUploaderState>(HuyaUploaderController.new);

/// The station's live-record archive, over the same shared transport: the
/// uploader page's 直播回放 tab reads it, and a replay opens through the
/// video player the same way an uploaded video does.
final huyaArchiveApiProvider = Provider<HuyaArchiveApi>((ref) {
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  return HuyaArchiveApi(http);
});

/// One uploader's live replays, paged apart from their uploaded videos.
final class HuyaReplayState {
  /// A replay page.
  const new({
    this.uid = '',
    this.videos = const <HuyaArchiveVideo>[],
    this.page = 0,
    this.hasMore = false,
    this.loaded = false,
    this.loading = false,
    this.error,
  });

  /// The uploader the replays belong to.
  final String uid;

  /// The recordings, newest first.
  final List<HuyaArchiveVideo> videos;

  /// The last page read.
  final int page;

  /// Whether another page follows.
  final bool hasMore;

  /// Whether the first page answered.
  final bool loaded;

  /// Whether a page is in flight.
  final bool loading;

  /// The last failure.
  final VodFailure? error;
}

/// One uploader's live replays.
final class HuyaReplayController extends Notifier<HuyaReplayState> {
  @override
  HuyaReplayState build() => const HuyaReplayState();

  /// Opens [uid]'s replays; another uid starts them over.
  Future<void> open(String uid) async {
    if (state.uid == uid && (state.loaded || state.loading)) return;
    state = HuyaReplayState(uid: uid, loading: true);
    await _load(uid, 1);
  }

  /// Reads the next page.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(state.uid, state.page + 1);
  }

  Future<void> _load(String uid, int page) async {
    try {
      final answer = await ref.read(huyaArchiveApiProvider).list(uid, page: page);
      if (!ref.mounted || state.uid != uid) return;
      final List<HuyaArchiveVideo> merged;
      if (page == 1) {
        merged = [...answer.videos];
      } else {
        merged = [...state.videos];
        final seen = {for (final video in merged) video.id};
        merged.addAll(answer.videos.where((video) => seen.add(video.id)));
      }
      state = HuyaReplayState(
        uid: uid,
        videos: List<HuyaArchiveVideo>.unmodifiable(merged),
        page: page,
        hasMore: answer.hasMore,
        loaded: true,
      );
    } on Object catch (failure) {
      if (!ref.mounted || state.uid != uid) return;
      state = HuyaReplayState(uid: uid, videos: state.videos, page: state.page, loaded: true, error: _failure(failure));
    }
  }
}

/// One uploader's live replays.
final huyaReplayProvider = NotifierProvider<HuyaReplayController, HuyaReplayState>(HuyaReplayController.new);

/// The words the station completes a search to, read once per partial word.
final FutureProviderFamily<List<String>, String> huyaSearchSuggestProvider = FutureProvider.family<List<String>, String>(
  (ref, word) => ref.watch(huyaVideoApiProvider).suggest(word),
);

/// One fresh batch of a game's hot videos, for the home's 换一批. The station's
/// own 换一批 rides its WebSocket recommendation service, which an anonymous
/// HTTP client cannot reach; the same effect is drawn from the game's hot
/// listing, one page per batch, wrapping to the first page at the end.
final class HuyaBatchState {
  /// A batch.
  const new({this.channelId = '', this.videos = const <HuyaVideo>[], this.page = 0, this.loading = false, this.error});

  /// The channel the batch belongs to.
  final String channelId;

  /// The videos in the batch.
  final List<HuyaVideo> videos;

  /// The listing page the batch came from; 0 before the first exchange.
  final int page;

  /// Whether an exchange is in flight.
  final bool loading;

  /// The last failure.
  final VodFailure? error;
}

/// Exchanges one game's home feed for a fresh batch of its hot videos.
final class HuyaBatchController extends Notifier<HuyaBatchState> {
  @override
  HuyaBatchState build() => const HuyaBatchState();

  /// Reads the next batch for [channelId]; another channel starts at page one.
  Future<void> exchange({required String channelId, required int setId}) async {
    if (channelId.isEmpty || state.loading) return;
    final sameChannel = state.channelId == channelId;
    final kept = sameChannel ? state.videos : const <HuyaVideo>[];
    final keptPage = sameChannel ? state.page : 0;
    final start = keptPage + 1;
    state = HuyaBatchState(channelId: channelId, videos: kept, page: keptPage, loading: true);
    try {
      final api = ref.read(huyaVideoApiProvider);
      var answer = await api.list(channelId: channelId, setId: setId, page: start);
      if (answer.videos.isEmpty && start > 1) {
        answer = await api.list(channelId: channelId, setId: setId);
      }
      if (!ref.mounted || state.channelId != channelId) return;
      state = HuyaBatchState(
        channelId: channelId,
        videos: List<HuyaVideo>.unmodifiable(answer.videos),
        page: answer.page,
      );
    } on Object catch (failure) {
      if (!ref.mounted || state.channelId != channelId) return;
      state = HuyaBatchState(channelId: channelId, videos: kept, page: keptPage, error: _failure(failure));
    }
  }
}

/// The home's current exchanged batch.
final huyaBatchProvider = NotifierProvider<HuyaBatchController, HuyaBatchState>(HuyaBatchController.new);
