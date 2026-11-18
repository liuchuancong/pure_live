import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_vod/live_vod.dart' show HuyaMaterialApi, HuyaMaterialChannel, HuyaVideo, VodFailure;
import 'package:pure_live/app/app.dart';

/// The material library's client over the shared transport.
///
/// The library's pages are server-rendered like the video site's, so they ask
/// as the same desktop browser over the same `api` profile, and the proxy
/// story stays the app shell's business. Nothing there asks for a login.
final huyaMaterialApiProvider = Provider<HuyaMaterialApi>((ref) {
  // The transport is the process's own: [DioFactory.create] hands the same
  // instance to every `api` caller, so closing it here would kill the next
  // request of the whole app.
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  return HuyaMaterialApi(http);
});

/// A readable failure from anything a controller caught.
VodFailure _materialFailure(Object failure) => failure is VodFailure ? failure : VodFailure('$failure');

/// What the material page holds: the stands, the shelf on stage and its rows.
///
/// The library walks no pages and its pool is what its one page renders, so a
/// shelf's rows are the whole answer — the state carries no paging, only the
/// word a search is answering, because a search and a stand share the stage.
final class HuyaMaterialState {
  /// A material page.
  const new({
    this.channels = const <HuyaMaterialChannel>[],
    this.channelId = '',
    this.word = '',
    this.videos = const <HuyaVideo>[],
    this.loading = false,
    this.error,
  });

  /// The stands, in the library's own order; empty until first read.
  final List<HuyaMaterialChannel> channels;

  /// The stand on stage; `''` is the library's landing page, the week's picks.
  final String channelId;

  /// The word the rows answer; non-empty while a search holds the stage.
  final String word;

  /// The rows on stage, in the library's own order.
  final List<HuyaVideo> videos;

  /// Whether a shelf is in flight.
  final bool loading;

  /// The last failure.
  final VodFailure? error;

  /// Copies with the fields a load replaces.
  HuyaMaterialState withShelf({required List<HuyaVideo> videos, required bool loading, VodFailure? error}) =>
      HuyaMaterialState(
        channels: channels,
        channelId: channelId,
        word: word,
        videos: videos,
        loading: loading,
        error: error,
      );
}

/// The material library: its landing page, one stand at a time, and its own
/// search. Every shelf is one server-rendered page read whole.
final class HuyaMaterialController extends Notifier<HuyaMaterialState> {
  @override
  HuyaMaterialState build() => const HuyaMaterialState();

  /// Loads the stands and the landing page when the page arrives without them.
  Future<void> open() async {
    if (state.loading || state.videos.isNotEmpty) return;
    await _stands();
    if (state.channelId.isEmpty && state.word.isEmpty) await _shelf();
  }

  /// Reads the stands once; a failure there never takes the page down — the
  /// landing page and the search still answer.
  Future<void> _stands() async {
    if (state.channels.isNotEmpty) return;
    try {
      final channels = await ref.read(huyaMaterialApiProvider).channels();
      if (!ref.mounted) return;
      state = HuyaMaterialState(channels: channels, channelId: state.channelId, word: state.word, videos: state.videos);
    } on Object {
      // The strip simply stays empty; the page keeps its shelf.
    }
  }

  /// Puts [channel] on stage, leaving any search behind.
  Future<void> select(HuyaMaterialChannel channel) async {
    state = HuyaMaterialState(channels: state.channels, channelId: channel.id);
    await _shelf();
  }

  /// Returns to the landing page.
  Future<void> backToHot() async {
    state = HuyaMaterialState(channels: state.channels);
    await _shelf();
  }

  /// Searches [word] over the library's own index; the stand stays chosen so
  /// leaving the answer returns where the search began.
  Future<void> search(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    state = HuyaMaterialState(channels: state.channels, channelId: state.channelId, word: trimmed);
    await _shelf();
  }

  /// Reads the shelf on stage again.
  Future<void> retry() => _shelf();

  Future<void> _shelf() async {
    final word = state.word;
    final channelId = state.channelId;
    state = state.withShelf(videos: const <HuyaVideo>[], loading: true);
    final api = ref.read(huyaMaterialApiProvider);
    try {
      final videos = switch ((word, channelId)) {
        ('', '') => await api.hot(),
        ('', final id) => await api.channel(id),
        (final w, _) => await api.search(w),
      };
      if (!ref.mounted || state.word != word || state.channelId != channelId) return;
      state = state.withShelf(videos: videos, loading: false);
    } on Object catch (failure) {
      if (!ref.mounted || state.word != word || state.channelId != channelId) return;
      state = state.withShelf(videos: const <HuyaVideo>[], loading: false, error: _materialFailure(failure));
    }
  }
}

/// The material library's page.
final huyaMaterialProvider = NotifierProvider<HuyaMaterialController, HuyaMaterialState>(HuyaMaterialController.new);
