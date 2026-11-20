import 'dart:async' show Completer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart'
    show iptvImporterProvider, iptvLibraryProvider, iptvPlaylistIsRemote;
import 'package:pure_live/modules/iptv/controllers/iptv_import_flow.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';

/// The playlist sources manager and the import flow over the real library
/// on the in-memory store, with only the network fetch faked: what a
/// preview answers, what a commit writes, what a sync keeps, the busy
/// guards, the sync-all round, and the page flow's steps and asks.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  /// The text each address answers; a missing address throws.
  final answers = <String, String>{};

  /// When set, the fetch throws what it returns.
  Exception? Function()? fetchThrow;

  /// When set, the fetch waits for it — the busy-guard's slow source.
  Completer<void>? gate;

  /// The real importer over the real library; only the download seam is
  /// the test's table.
  IptvImporter? importerOf(Ref ref) {
    final library = ref.watch(iptvLibraryProvider).value;
    if (library == null) return null;
    return IptvImporter(
      library: library,
      fetch: (url, {headers = const {}}) async {
        if (gate != null) await gate!.future;
        final thrown = fetchThrow?.call();
        if (thrown != null) throw thrown;
        final text = answers[url.toString()];
        if (text == null) throw StateError('no answer for $url');
        return text;
      },
    );
  }

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer(overrides: [iptvImporterProvider.overrideWith(importerOf)]);
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  IptvSourcesState sources() => container.read(iptvSourcesProvider);
  IptvSourcesController sourcesNotifier() => container.read(iptvSourcesProvider.notifier);
  IptvLibrary library() => container.read(iptvLibraryProvider).value!;

  const v1 =
      '#EXTM3U\n'
      '#PLAYLIST:PLName\n'
      '#EXTINF:-1 tvg-id="one.tv" group-title="G1",Channel One\n'
      'http://stream/1\n'
      '#EXTINF:-1 tvg-id="two.tv" group-title="G2",Channel Two\n'
      'http://stream/2\n';

  const v2 =
      '#EXTM3U\n'
      '#PLAYLIST:PLName\n'
      '#EXTINF:-1 tvg-id="three.tv" group-title="G1",Channel Three\n'
      'http://stream/3\n';

  /// The v1 lines under other addresses, so a replace changes the channels.
  const other =
      '#EXTM3U\n'
      '#PLAYLIST:Other\n'
      '#EXTINF:-1 tvg-id="nine.tv" group-title="G9",Channel Nine\n'
      'http://stream/9\n';

  /// Imports [text] as a commit under [name] through the manager itself.
  Future<IptvImportResult> commitText(String text, String name) async {
    final preview = await sourcesNotifier().previewText(text);
    return await sourcesNotifier().commitPreview(preview, name: name);
  }

  test('the manager mirrors the library once it opens and follows its changes', () async {
    expect(sources().ready, isFalse);

    await container.read(iptvLibraryProvider.future);
    expect(sources().ready, isTrue);
    expect(sources().playlists, isEmpty);
    expect(sources().channelCount, 0);

    await commitText(v1, 'Mine');
    await pumpEventQueue(); // the library's change broadcast reaches the mirror
    expect(sources().playlists.length, 1);
    expect(sources().channelCount, 2);
  });

  test('a preview judges, a commit writes, a name clash is asked, a replace lands', () async {
    final preview = await sourcesNotifier().previewText(v1);
    expect(preview.isReadable, isTrue);
    expect(preview.channels, 2);
    expect(preview.suggestedName, 'PLName');

    final written = await sourcesNotifier().commitPreview(preview, name: 'Mine');
    expect(written.isImported, isTrue);
    expect(library().playlists.single.name, 'Mine');

    // The same name without the replace word is refused, not overwritten.
    final clash = await sourcesNotifier().commitPreview(preview, name: 'Mine');
    expect(clash.isImported, isFalse);
    expect(clash.failure, IptvImportFailure.nameTaken);
    expect(library().playlists.length, 1);

    // The replace word takes the same name over.
    final replaced = await sourcesNotifier().commitPreview(preview, name: 'Mine', replaceId: clash.id);
    expect(replaced.isImported, isTrue);
    expect(library().playlists.length, 1);
    expect(library().channels.length, 2);
  });

  test('a sync re-downloads, keeps the favourites, and reconciles the line-up', () async {
    answers['http://x/list.m3u'] = v1;
    final preview = await sourcesNotifier().previewUrl(Uri.parse('http://x/list.m3u'));
    final result = await sourcesNotifier().commitPreview(preview, name: 'Net');
    expect(result.isImported, isTrue);
    final playlist = library().playlists.single;
    expect(iptvPlaylistIsRemote(playlist), isTrue);

    final one = library().channels.singleWhere((channel) => channel.entry.url == 'http://stream/1');
    await library().toggleFavorite(one.id);
    await pumpEventQueue();
    expect(library().channelById(one.id)!.favorite, isTrue);

    // The source drops Channel Two and adds Channel Three.
    answers['http://x/list.m3u'] = v2;
    final synced = await sourcesNotifier().syncPlaylist(playlist);
    expect(synced!.isImported, isTrue);
    expect(synced.added, 1);
    expect(synced.removed, 1);
    await pumpEventQueue();

    // The favourite rode the address match; the dropped channel left.
    expect(library().channelById(one.id)!.favorite, isTrue);
    expect(library().channels.any((channel) => channel.entry.url == 'http://stream/2'), isFalse);
    expect(library().channels.any((channel) => channel.entry.url == 'http://stream/3'), isTrue);
    // The record keeps its id: rooms pointing at a channel keep working.
    expect(library().playlists.single.id, playlist.id);
  });

  test('a busy source refuses the second ask and clears when done', () async {
    answers['http://x/list.m3u'] = v1;
    final preview = await sourcesNotifier().previewUrl(Uri.parse('http://x/list.m3u'));
    await sourcesNotifier().commitPreview(preview, name: 'Net');
    final playlist = library().playlists.single;

    gate = Completer<void>();
    final doing = sourcesNotifier().syncPlaylist(playlist);
    await pumpEventQueue();
    expect(sources().busy, {'p:${playlist.id}'});
    expect(await sourcesNotifier().syncPlaylist(playlist), isNull);

    gate!.complete();
    expect((await doing)!.isImported, isTrue);
    await pumpEventQueue();
    expect(sources().busy, isEmpty);
    gate = null;
  });

  test('a delete reports its impact and takes the channels with it', () async {
    final result = await commitText(v1, 'Mine');
    final playlist = library().playlistNamed('Mine')!;
    final one = library().channels.first;
    await library().toggleFavorite(one.id);

    expect(sourcesNotifier().deletionImpact(playlist), (channels: 2, favourites: 1));
    expect(await sourcesNotifier().deletePlaylist(playlist), isTrue);
    await pumpEventQueue();
    expect(library().playlists, isEmpty);
    expect(library().channels, isEmpty);
    expect(sources().channelCount, 0);
    expect(result.channels, 2);
  });

  test('sync-all walks the remote sources only and counts the failures', () async {
    await commitText(v1, 'Local'); // pasted text records no address
    answers['http://x/list.m3u'] = v1;
    final preview = await sourcesNotifier().previewUrl(Uri.parse('http://x/list.m3u'));
    await sourcesNotifier().commitPreview(preview, name: 'Net');

    // The remote source answers nothing: the round counts the failure.
    fetchThrow = () => Exception('down');
    var round = await sourcesNotifier().syncAll();
    expect(round, (total: 1, failed: 1));
    expect(sources().syncAll, isNull); // the round's progress left with it

    // A healthy round walks the same one remote source.
    fetchThrow = null;
    round = await sourcesNotifier().syncAll();
    expect(round, (total: 1, failed: 0));
  });

  test('the flow walks source, preview with the playlist name, and done', () async {
    final flow = container.read(iptvImportFlowProvider.notifier);
    expect(container.read(iptvImportFlowProvider).step, IptvImportStep.source);

    await flow.previewText(v1, fallbackName: 'fb');
    var state = container.read(iptvImportFlowProvider);
    expect(state.step, IptvImportStep.preview);
    expect(state.name, 'PLName'); // the playlist's own name, not the fallback

    // An empty name writes nothing and says so by staying.
    flow.setName('  ');
    await flow.commit();
    expect(container.read(iptvImportFlowProvider).step, IptvImportStep.preview);
    expect(container.read(iptvImportFlowProvider).result, isNull);

    // A hidden group rides the commit into the library.
    flow
      ..setName('Mine')
      ..toggleGroup('G1', shown: false);
    expect(container.read(iptvImportFlowProvider).hiddenGroups, {'G1'});
    await flow.commit();
    state = container.read(iptvImportFlowProvider);
    expect(state.step, IptvImportStep.done);
    expect(state.result!.isImported, isTrue);
    await pumpEventQueue();
    expect(library().playlists.single.name, 'Mine');
    expect(library().isGroupHidden('G1'), isTrue);
    expect(library().isGroupHidden('G2'), isFalse);
  });

  test('a name clash parks the commit on the preview until the replace word', () async {
    final flow = container.read(iptvImportFlowProvider.notifier);
    await flow.previewText(v1, fallbackName: 'fb');
    flow.setName('Mine');
    await flow.commit();
    expect(container.read(iptvImportFlowProvider).step, IptvImportStep.done);

    // Another list under the taken name: the commit asks instead of writing.
    flow.backToSource();
    expect(container.read(iptvImportFlowProvider).step, IptvImportStep.source);
    await flow.previewText(other, fallbackName: 'fb');
    flow.setName('Mine');
    await flow.commit();
    var state = container.read(iptvImportFlowProvider);
    expect(state.step, IptvImportStep.preview);
    expect(state.result, isNull);
    // Nothing was written under the ask.
    expect(library().playlists.single.name, 'Mine');
    expect(library().channels.any((channel) => channel.entry.url == 'http://stream/9'), isFalse);

    // A free name sits beside the taken one.
    expect(flow.freeNameFor('Mine'), 'Mine (2)');

    // The replace word answers the ask: the same name, the new channels.
    flow.setReplaceNamed(value: true);
    await flow.commit();
    state = container.read(iptvImportFlowProvider);
    expect(state.step, IptvImportStep.done);
    await pumpEventQueue();
    expect(library().playlists.length, 1);
    expect(library().channels.any((channel) => channel.entry.url == 'http://stream/9'), isTrue);
    expect(library().channels.any((channel) => channel.entry.url == 'http://stream/1'), isFalse);
  });

  test('re-reading the same address updates its playlist in place, without asking', () async {
    final flow = container.read(iptvImportFlowProvider.notifier);
    answers['http://x/list.m3u'] = v1;
    await flow.previewLink('http://x/list.m3u');
    flow.setName('First');
    await flow.commit();
    expect(container.read(iptvImportFlowProvider).step, IptvImportStep.done);
    final first = library().playlists.single;

    // The same address again: the preview names the stored playlist, and the
    // commit is an update, not a second copy.
    flow.backToSource();
    answers['http://x/list.m3u'] = other;
    await flow.previewLink('http://x/list.m3u');
    final state = container.read(iptvImportFlowProvider);
    expect(state.playlist!.urlClash!.id, first.id);
    expect(state.name, 'First');
    await flow.commit();
    expect(container.read(iptvImportFlowProvider).step, IptvImportStep.done);
    await pumpEventQueue();
    expect(library().playlists.length, 1);
    expect(library().playlists.single.id, first.id);
    expect(library().channels.single.entry.url, 'http://stream/9');
  });

  test('switching kind or origin resets the draft and keeps the name', () async {
    final flow = container.read(iptvImportFlowProvider.notifier);
    await flow.previewText(v1, fallbackName: 'fb');
    flow
      ..setName('Keep')
      ..setOrigin(IptvImportOrigin.text);
    var state = container.read(iptvImportFlowProvider);
    expect(state.step, IptvImportStep.source);
    expect(state.playlist, isNull);
    expect(state.name, 'Keep');

    // A guide takes no pasted text: the origin moves to a link.
    flow.setKind(IptvImportKind.guide);
    state = container.read(iptvImportFlowProvider);
    expect(state.kind, IptvImportKind.guide);
    expect(state.origin, IptvImportOrigin.link);
    expect(state.step, IptvImportStep.source);
    expect(state.name, 'Keep');

    // The same kind again changes nothing.
    flow.setKind(IptvImportKind.guide);
    expect(container.read(iptvImportFlowProvider).kind, IptvImportKind.guide);
  });

  test('the source order mirrors its preference', () async {
    final order = container.read(iptvSourceOrderProvider.notifier);
    expect(container.read(iptvSourceOrderProvider), isEmpty);
    expect(await order.save(['b', 'a']), isTrue);
    expect(container.read(iptvSourceOrderProvider), ['b', 'a']);

    final next = ProviderContainer();
    addTearDown(next.dispose);
    expect(next.read(iptvSourceOrderProvider), ['b', 'a']);
  });
}
