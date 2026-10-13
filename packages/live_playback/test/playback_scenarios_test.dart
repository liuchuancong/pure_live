import 'package:flutter_test/flutter_test.dart';
import 'package:live_playback/live_playback.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core/testing/library.dart';

/// End-to-end walks through the playback states a viewer actually produces:
/// backgrounding with and without PiP, a live room displaced by a recorded
/// video and resumed, a page handed to a small window, and a feed previewed
/// and promoted. Everything runs on the kernel's fake backend, so these are
/// real sessions and a real coordinator, not stubs of them.
void main() {
  PlayerKernel fakeKernel() {
    return PlayerKernel()..registerBackend(
      PlayerAdapterRegistration(
        id: 'fake',
        capabilities: const PlayerAdapterCapabilities(),
        factory: TestPlayerFactory.fakeAdapterFactory(),
      ),
    );
  }

  PlayerSource source(String url) => PlayerSource(id: SourceId(url), uri: Uri.parse(url));

  /// A service on a fake kernel, with a presentation adapter that reports the
  /// platform abilities the test wants.
  ///
  /// The adapter is the host's seam: what it reports is what the service is
  /// allowed to do, so "this platform has no PiP" is expressed here rather than
  /// by faking the state machine.
  PlaybackService serviceWith({
    PlayerKernel? kernel,
    bool pip = true,
    bool floating = true,
    PlaybackConfig config = PlaybackConfig.defaults,
  }) {
    return PlaybackService(
      kernel: kernel ?? fakeKernel(),
      presentationAdapter: InPlacePresentationAdapter(
        initialCapabilities: PresentationCapabilities(pip: pip, floating: floating),
      ),
      config: config,
    );
  }

  Future<PlaybackSession> openLive(PlaybackService service, String id) {
    return service.openLive(id: id, source: source('https://example.com/$id.m3u8'));
  }

  Future<PlaybackSession> openRecorded(PlaybackService service, String id) {
    return service.openRecorded(id: id, source: source('https://example.com/$id.mp4'));
  }

  group('backgrounding', () {
    test('enters PiP when the viewer allows PiP and background playback', () async {
      final service = serviceWith();
      final session = await openLive(service, 'room-1');

      await service.setVisible(isVisible: false);

      expect(service.state.isBackgrounded, isTrue);
      expect(service.state.presentationMode, PresentationMode.pip);
      expect(session.isPlaying, isTrue, reason: 'PiP is for watching, so it keeps playing');
      expect(service.state.primary!.danmakuEnabled, isFalse, reason: 'a PiP thumbnail shows no chat');
    });

    test('keeps only the sound when the platform has no PiP', () async {
      final service = serviceWith(pip: false);
      final session = await openLive(service, 'room-1');

      await service.setVisible(isVisible: false);

      expect(service.state.presentationMode, PresentationMode.normal);
      expect(session.isPlaying, isTrue, reason: 'audio-only background playback');
    });

    test('keeps only the sound when the viewer turned PiP off', () async {
      final service = serviceWith(config: const PlaybackConfig(allowPictureInPicture: false));
      final session = await openLive(service, 'room-1');

      await service.setVisible(isVisible: false);

      expect(service.state.presentationMode, PresentationMode.normal);
      expect(session.isPlaying, isTrue);
    });

    test('pauses when neither background playback nor PiP is allowed', () async {
      final service = serviceWith(
        config: const PlaybackConfig(allowBackgroundPlayback: false, allowPictureInPicture: false),
      );
      final session = await openLive(service, 'room-1');

      await service.setVisible(isVisible: false);

      expect(session.isPlaying, isFalse);
    });

    test('returns from the background by closing the PiP it opened', () async {
      final service = serviceWith();
      await openLive(service, 'room-1');

      await service.setVisible(isVisible: false);
      expect(service.state.presentationMode, PresentationMode.pip);

      await service.setVisible(isVisible: true);

      expect(service.state.isBackgrounded, isFalse);
      expect(service.state.presentationMode, PresentationMode.normal);
      expect(service.state.primary!.danmakuEnabled, isTrue, reason: 'chat comes back with the page');
    });
  });

  group('live room displaced by a recorded video', () {
    test('parks the room, then returns to it refreshed', () async {
      final service = serviceWith();
      final live = await openLive(service, 'room-1');

      final recorded = await openRecorded(service, 'video-1');

      expect(live.currentState.phase, PlaybackPhase.paused, reason: 'the room waits, it is not closed');
      expect(service.coordinator.contains('room-1'), isTrue);
      expect(service.suspendedSessionId, 'room-1');
      expect(recorded.isPlaying, isTrue);
      expect(service.state.primarySessionId, 'video-1');

      final liveAdapter = live.handle.adapter as FakePlayerAdapter;
      expect(liveAdapter.openedSources, hasLength(1));

      await service.returnToSuspendedLive();

      expect(service.state.primarySessionId, 'room-1');
      expect(live.currentState.phase, PlaybackPhase.playing);
      expect(service.suspendedSessionId, isNull);
      expect(
        liveAdapter.openedSources,
        hasLength(2),
        reason: 'a live room re-syncs by reopening its line, so it comes back at the live edge',
      );
      expect(service.coordinator.contains('video-1'), isFalse, reason: 'the recorded page was left for good');
    });

    test('keeps the recorded video when it was handed to a small window', () async {
      final service = serviceWith();
      final live = await openLive(service, 'room-1');
      final recorded = await openRecorded(service, 'video-1');

      await service.handOffToOverlay(id: 'video-1');

      expect(service.state.presentationMode, PresentationMode.floating);
      expect(service.state.overlaySessionId, 'video-1');
      expect(service.state.overlay!.danmakuEnabled, isFalse, reason: 'a thumbnail shows no chat');
      expect(recorded.muted, isFalse);

      await service.returnToSuspendedLive();

      expect(service.state.primarySessionId, 'room-1');
      expect(live.muted, isFalse, reason: 'the page the viewer is looking at is what they hear');
      expect(service.coordinator.contains('video-1'), isTrue, reason: 'the small window outlives the page');
      expect(recorded.isPlaying, isTrue, reason: 'it keeps playing, just without the sound');
      expect(recorded.muted, isTrue);
    });

    test('opening another live room closes the previous one', () async {
      final service = serviceWith();
      await openLive(service, 'room-1');

      await openLive(service, 'room-2');

      expect(service.coordinator.contains('room-1'), isFalse);
      expect(service.state.primarySessionId, 'room-2');
    });

    test('opening content leaves a small window playing', () async {
      final service = serviceWith();
      await openLive(service, 'room-1');
      await service.handOffToOverlay(id: 'room-1');

      final recorded = await openRecorded(service, 'video-1');

      expect(service.coordinator.contains('room-1'), isTrue, reason: 'the small window is not the page');
      expect(service.state.snapshotFor('room-1')!.isPlaying, isTrue);
      expect(service.state.snapshotFor('room-1')!.muted, isTrue);
      expect(recorded.muted, isFalse);
      expect(service.state.primarySessionId, 'video-1');
    });
  });

  group('overlay hand-off', () {
    test('refuses an overlay the configuration does not allow', () async {
      final service = serviceWith(config: const PlaybackConfig(allowFloatingWindow: false));
      await openLive(service, 'room-1');

      await service.handOffToOverlay(id: 'room-1');

      expect(service.state.presentationMode, PresentationMode.normal);
      expect(service.overlaySessionId, isNull);
    });

    test('exiting an overlay returns the picture and the chat', () async {
      final service = serviceWith();
      await openLive(service, 'room-1');
      await service.handOffToOverlay(id: 'room-1');

      await service.exitOverlay();

      expect(service.state.presentationMode, PresentationMode.normal);
      expect(service.overlaySessionId, isNull);
      expect(service.state.primary!.danmakuEnabled, isTrue);
    });

    test('a handed-off PiP survives, and the background policy takes it over', () async {
      final service = serviceWith();
      await openLive(service, 'room-1');
      await service.handOffToOverlay(id: 'room-1', surface: WindowSurface.pip);

      await service.setVisible(isVisible: false);

      expect(service.state.presentationMode, PresentationMode.pip, reason: 'already PiP; one transition, not two');
      expect(service.state.primarySessionId, 'room-1');
    });
  });

  group('feed preview and detail', () {
    Future<FeedEntry> entry(int index) async =>
        FeedEntry(id: 'v-$index', source: source('https://example.com/v$index.mp4'), contentType: ContentType.recorded);

    test('a preview feed stays silent until the detail page opens', () async {
      final service = serviceWith();
      await service.feed.setMode(FeedPlaybackMode.preview);

      final session = await service.feed.scrollToIndex(0, entry);

      expect(session.muted, isTrue, reason: 'a tile is a preview, not playback');
      expect(service.state.primarySessionId, isNull, reason: 'the channel is given up, not held muted');

      await service.feed.openDetail(0, entry);

      expect(service.state.primarySessionId, 'v-0');
      expect(session.muted, isFalse);

      await service.feed.closeDetail();

      expect(service.state.primarySessionId, isNull);
      expect(session.muted, isTrue);
      expect(service.feed.mode, FeedPlaybackMode.preview);
    });

    test('the detail step works on the item already on screen', () async {
      final service = serviceWith();
      await service.feed.setMode(FeedPlaybackMode.preview);
      final session = await service.feed.scrollToIndex(0, entry);

      // The page settles on the same item; a `PageView` does this constantly.
      await service.feed.openDetail(0, entry);

      expect(session.muted, isFalse);
      expect(service.state.primarySessionId, 'v-0');
    });

    test('an immersive feed is audible as it scrolls', () async {
      final service = serviceWith();

      final first = await service.feed.scrollToIndex(0, entry);
      expect(service.state.primarySessionId, 'v-0');
      expect(first.muted, isFalse);

      final second = await service.feed.scrollToIndex(1, entry);
      expect(service.state.primarySessionId, 'v-1');
      expect(second.muted, isFalse);
      expect(first.muted, isTrue, reason: 'one audible item at a time');
      expect(first.isPlaying, isFalse, reason: 'the item scrolled away is parked');
    });

    test('a handed-off item survives the scroll window and the page closing', () async {
      final service = serviceWith();
      final session = await service.feed.openDetail(0, entry);

      await service.feed.closeDetail(keepInOverlay: true);

      expect(service.feed.pinnedSessionIds, contains('v-0'));
      expect(session.muted, isFalse, reason: 'the overlay is what the viewer hears');

      // Scroll far enough that the preload window no longer contains index 0.
      await service.feed.scrollToIndex(3, entry);
      expect(service.coordinator.contains('v-0'), isTrue, reason: 'a pinned session is not recycled');

      await service.feed.dispose();
      expect(service.coordinator.contains('v-0'), isTrue, reason: 'and not stopped with the list page');
    });

    test('scrolling away from a non-pinned item recycles it', () async {
      final service = serviceWith();
      await service.feed.scrollToIndex(0, entry);

      await service.feed.scrollToIndex(3, entry);

      expect(service.coordinator.contains('v-0'), isFalse);
    });
  });

  group('multi-view', () {
    Future<PlaybackSession> openWindow(PlaybackService service, String id) {
      return service.coordinator.startSession(id: id, source: source('https://example.com/$id.m3u8'), autoPlay: false);
    }

    test('the first tile is the one you hear, the rest open quiet', () async {
      final service = serviceWith();
      final first = await openWindow(service, 'room-1');
      final second = await openWindow(service, 'room-2');

      await service.multiView.addSlot(const MultiViewSlot(id: 'room-1'));
      await service.multiView.addSlot(const MultiViewSlot(id: 'room-2'));

      expect(first.muted, isFalse, reason: 'the first tile on screen is the audible one');
      expect(second.muted, isTrue);
      expect(service.multiView.slotIds, <String>['room-1', 'room-2']);
    });

    test('focusing a tile moves the sound, not the layout', () async {
      final service = serviceWith();
      final first = await openWindow(service, 'room-1');
      final second = await openWindow(service, 'room-2');
      await service.multiView.addSlot(const MultiViewSlot(id: 'room-1'));
      await service.multiView.addSlot(const MultiViewSlot(id: 'room-2'));

      await service.multiView.focusSlot('room-2');

      expect(second.muted, isFalse);
      expect(first.muted, isTrue);
      expect(service.multiView.slotIds, <String>['room-1', 'room-2'], reason: 'the grid does not reorder');
      expect(service.state.primarySessionId, 'room-2');
    });

    test('closing the audible tile hands the sound to the next one', () async {
      final service = serviceWith();
      await openWindow(service, 'room-1');
      final second = await openWindow(service, 'room-2');
      await service.multiView.addSlot(const MultiViewSlot(id: 'room-1'));
      await service.multiView.addSlot(const MultiViewSlot(id: 'room-2'));

      await service.multiView.removeSlot('room-1');

      expect(second.muted, isFalse, reason: 'a grid must not go silent because the wrong tile closed');
      expect(service.multiView.slotIds, <String>['room-2']);
    });

    test('a tile handed to a small window keeps playing while the grid pauses', () async {
      final service = serviceWith();
      final tile = await openWindow(service, 'room-1');
      await service.multiView.addSlot(const MultiViewSlot(id: 'room-1'));

      await service.handOffToOverlay(id: 'room-1');

      expect(service.state.overlaySessionId, 'room-1');
      expect(tile.muted, isFalse);
      expect(service.state.presentationMode, PresentationMode.floating);

      await service.multiView.pauseAll();
      expect(tile.isPlaying, isFalse);

      await service.exitOverlay();
      expect(service.state.overlaySessionId, isNull);
    });
  });

  group('one audio channel', () {
    /// Opens a window without making it the page's content — what a multi-view
    /// grid does for every tile but the first.
    Future<PlaybackSession> openWindow(PlaybackService service, String id) {
      return service.coordinator.startSession(id: id, source: source('https://example.com/$id.m3u8'), autoPlay: false);
    }

    test('claiming the channel for a window mutes the other', () async {
      final service = serviceWith();
      final first = await openWindow(service, 'room-1');
      final second = await openWindow(service, 'room-2');

      await service.coordinator.claimAudio('room-2');

      expect(first.muted, isTrue);
      expect(second.muted, isFalse);
      expect(service.state.primarySessionId, 'room-2');
      expect(service.state.allMuted, isFalse);
    });

    test('the global mute silences everything and unmute restores the owner', () async {
      final service = serviceWith();
      final first = await openWindow(service, 'room-1');
      final second = await openWindow(service, 'room-2');
      await service.coordinator.claimAudio('room-2');

      await service.setMuted(muted: true);

      expect(first.muted, isTrue);
      expect(second.muted, isTrue);
      expect(service.state.allMuted, isTrue);

      await service.setMuted(muted: false);

      expect(second.muted, isFalse, reason: 'the owner comes back audible');
      expect(first.muted, isTrue, reason: 'and the other window stays quiet');
    });

    test('the global chat switch reaches every window', () async {
      final service = serviceWith();
      final first = await openWindow(service, 'room-1');
      final second = await openWindow(service, 'room-2');

      await service.setDanmakuEnabled(enabled: false);

      expect(first.danmakuEnabled, isFalse);
      expect(second.danmakuEnabled, isFalse);
      expect(service.state.allDanmakuDisabled, isTrue);
    });
  });
}
