// Module: test/ticket_swap_test.dart
// Purpose: Verify a ticket replacement reopens, lands back at the position and respects the user's pause.
// Author: liuchuancong
// Created: 2026-10-09
//
// Runs on media_core's own fake engine through the real kernel, so the assertion is about the order the
// platform asks the kernel for - not about whether the replacement was perceptually seamless.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart' as core;
import 'package:media_core/testing/library.dart' as doubles;
import 'package:pure_live_media/pure_live_media.dart';
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'support/fake_engine.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

platform.MediaTicket _ticket(String url, {String id = 'ticket-1'}) => platform.MediaTicket(
  id: id,
  uri: Uri.parse(url),
  kind: platform.MediaKind.vod,
  protocol: platform.MediaProtocol.hls,
  createdAt: _t0,
);

void main() {
  late List<doubles.FakePlayerAdapter> created;
  late core.PlayerKernel kernel;

  setUp(() {
    created = <doubles.FakePlayerAdapter>[];
    kernel = fakeEngineKernel(created: created);
  });

  tearDown(() async {
    await kernel.dispose();
  });

  Future<core.PlayerHandle> playingHandle(String url) async {
    final handle = await kernel.createFromMedia(toCoreSource(_ticket(url)), preferredBackend: 'fake');
    await handle.play();
    return handle;
  }

  test('test_swap_reopensTheNewTicketAndGoesBackToWhereTheViewerWas', () async {
    final handle = await playingHandle('https://example.test/old.m3u8');
    await handle.seek(const Duration(seconds: 45));
    created.single.seeks.clear();

    var replacements = 0;
    final swapper = TicketSwapper(
      handle: handle,
      ticket: _ticket('https://example.test/old.m3u8'),
      replace: (reason) async {
        replacements++;
        return _ticket('https://example.test/new.m3u8', id: 'ticket-2');
      },
    );

    final swapped = await swapper.swap(platform.RefreshReason.expiring);

    expect(replacements, 1);
    expect(swapped.id, 'ticket-2');
    expect(swapper.currentTicket?.id, 'ticket-2');
    final adapter = created.single;
    // The engine is handed the url from the new ticket, not a re-derivation of the old one.
    expect(adapter.openedSources.last.uri, Uri.parse('https://example.test/new.m3u8'));
    expect(adapter.seeks, contains(const Duration(seconds: 45)), reason: 'the viewer stays where they were');
    // open -> seek -> play: the resume comes after the reposition, or the first frames are from the old spot.
    expect(adapter.calls.indexOf('open'), lessThan(adapter.calls.lastIndexOf('seek')));
    expect(adapter.calls.last, 'play');
    expect(handle.isPlaying, isTrue);

    await handle.dispose();
  });

  test('test_swap_keepsAPausedViewerPaused', () async {
    // The user pressed pause. A refresh that resumes playback answers a question nobody asked, and on TV the
    // viewer often has stepped away precisely because they paused.
    final handle = await playingHandle('https://example.test/old.m3u8');
    await handle.seek(const Duration(seconds: 30));
    await handle.pause();

    final swapper = TicketSwapper(handle: handle, replace: (reason) async => _ticket('https://example.test/new.m3u8'));

    await swapper.swap(platform.RefreshReason.expired);

    expect(created.single.openedSources.last.uri, Uri.parse('https://example.test/new.m3u8'));
    expect(handle.isPlaying, isFalse);

    await handle.dispose();
  });

  test('test_swap_atTheLiveEdge_doesNotSeekBackToZero', () async {
    final handle = await kernel.createFromMedia(
      toCoreSource(_ticket('https://example.test/live.m3u8')),
      preferredBackend: 'fake',
    );
    await handle.play();

    final swapper = TicketSwapper(
      handle: handle,
      replace: (reason) async => _ticket('https://example.test/live-2.m3u8'),
    );

    await swapper.swap(platform.RefreshReason.http403);

    // A stream with no position concept must not be dragged to 0 by a generic "restore position" step.
    expect(created.single.seeks, isEmpty);
    expect(handle.isPlaying, isTrue);

    await handle.dispose();
  });

  test('test_swap_whenTheRefresherFails_opensNothingAndReports', () async {
    final handle = await playingHandle('https://example.test/old.m3u8');
    final opensBefore = created.single.openedSources.length;

    final swapper = TicketSwapper(
      handle: handle,
      ticket: _ticket('https://example.test/old.m3u8'),
      replace: (reason) async => throw FormatException('the source gave back nothing'),
    );

    await expectLater(swapper.swap(platform.RefreshReason.networkError), throwsA(isA<FormatException>()));

    expect(created.single.openedSources, hasLength(opensBefore), reason: 'a failed fetch must not interrupt playback');
    expect(swapper.currentTicket?.id, 'ticket-1');
    expect(swapper.isSwapping, isFalse);

    await handle.dispose();
  });

  test('test_swap_twoCallersAtOnce_fetchOnceAndOpenOnce', () async {
    // Prefetch and a user-initiated refresh can fire in the same instant; two opens back to back would have
    // the second replace the row the first just installed.
    final handle = await playingHandle('https://example.test/old.m3u8');
    var replacements = 0;
    final gate = Completer<void>();
    final swapper = TicketSwapper(
      handle: handle,
      replace: (reason) async {
        replacements++;
        await gate.future;
        return _ticket('https://example.test/new.m3u8');
      },
    );

    final first = swapper.swap(platform.RefreshReason.expiring);
    final second = swapper.swap(platform.RefreshReason.manual);
    gate.complete();
    final tickets = await Future.wait<platform.MediaTicket>(<Future<platform.MediaTicket>>[first, second]);

    expect(replacements, 1);
    expect(tickets[0], same(tickets[1]));
    expect(created.single.openedSources, hasLength(2));

    await handle.dispose();
  });
}
