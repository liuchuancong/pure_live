import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/core/iptv/local/epg_channel_identity.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/plugins/db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Database db;
  late _Settings settings;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('iptv-mapping-');
    db = _Database(NativeDatabase(File('${directory.path}/test.sqlite')));
    Get.testMode = true;
    Get.put(DbService()..db = db);
    settings = Get.put<SettingsService>(_Settings()) as _Settings;
    settings.iptv.selectedSourceId.value = 'A';
    for (final provider in ['provider', 'other']) {
      await db.upsertProvider(ProvidersCompanion.insert(id: provider, name: provider, type: 'm3u'));
    }
    for (final source in ['A', 'B', 'empty']) {
      await db.upsertEpgSource(
        EpgSourcesCompanion.insert(id: source, name: source, url: 'https://fixture/$source.xml'),
      );
      if (source != 'empty') {
        await db.upsertEpgChannels([
          EpgChannelsCompanion.insert(
            id: epgChannelKey(source, 'news'),
            sourceId: source,
            channelId: 'news',
            displayName: 'News',
          ),
        ]);
      }
    }
    await db.upsertChannels([
      ChannelsCompanion.insert(
        id: 'room',
        providerId: 'provider',
        name: 'News',
        tvgId: const drift.Value('news'),
        streamUrl: 'https://fixture/live.m3u8',
      ),
    ]);
  });
  tearDown(() async {
    Get.reset();
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<void> seed({
    String channel = 'room',
    String provider = 'provider',
    String source = 'auto',
    bool locked = false,
    String epg = 'B',
  }) => db.upsertMapping(
    EpgMappingsCompanion.insert(
      channelId: channel,
      providerId: provider,
      epgChannelId: epgChannelKey(epg, 'news'),
      epgSourceId: epg,
      source: drift.Value(source),
      locked: drift.Value(locked),
      confidence: const drift.Value(0.92),
      updatedAt: drift.Value(DateTime.utc(2020)),
    ),
  );
  Future<String> snapshot() async => jsonEncode((await db.getAllMappings()).map((m) => m.toJson()).toList());
  Future<void> run() => IptvImportManager().runAutoEpgMapping(providerId: 'provider');
  Future<void> reopen() async {
    await db.close();
    Get.delete<DbService>(force: true);
    db = _Database(NativeDatabase(File('${directory.path}/test.sqlite')));
    Get.put(DbService()..db = db);
  }

  for (final state in [(true, 'auto'), (false, 'manual'), (false, 'suggested')]) {
    test('automatic rebuild preserves ${state.$2} mapping locked=${state.$1}', () async {
      await seed(locked: state.$1, source: state.$2);
      final before = await snapshot();
      await run();
      await reopen();
      expect(await snapshot(), before);
    });
  }
  test('an empty selected source does not erase previous mappings', () async {
    await seed();
    final before = await snapshot();
    settings.iptv.selectedSourceId.value = 'empty';
    await run();
    expect(await snapshot(), before);
  });
  test('failed replacement keeps all durable mappings', () async {
    await seed();
    await seed(provider: 'other');
    final before = await snapshot();
    await db.customStatement(
      "CREATE TRIGGER fail_mapping BEFORE INSERT ON epg_mappings WHEN NEW.provider_id = 'provider' BEGIN SELECT RAISE(ABORT, 'mapping fixture failure'); END",
    );
    try {
      await run();
    } catch (_) {}
    await reopen();
    expect(await snapshot(), before);
  });
  test('selection changed during source read prevents obsolete commit', () async {
    await seed();
    final before = await snapshot();
    db.afterEpgRead = () async {
      settings.iptv.selectedSourceId.value = 'B';
    };
    await run();
    expect(await snapshot(), before);
  });
  test('blank normalized channel name never matches an arbitrary EPG row', () async {
    await (db.update(db.channels)..where((t) => t.id.equals('room'))).write(
      const ChannelsCompanion(name: drift.Value('!!!'), tvgId: drift.Value(null)),
    );
    await run();
    expect(await db.getAllMappings(), isEmpty);
  });
  test('ambiguous raw TVG ID is not resolved by input row order', () async {
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'historical-duplicate', sourceId: 'A', channelId: 'NEWS', displayName: 'News'),
    ]);
    await run();
    expect(await db.getAllMappings(), isEmpty);
  });
  for (final provenance in ['imported', 'custom']) {
    test('automatic rebuild preserves $provenance provenance without a lock', () async {
      await seed(source: provenance);
      final before = await snapshot();
      await run();
      expect(await snapshot(), before);
    });
  }
  test('no selection or no playlist channels leaves saved mappings unchanged', () async {
    await seed();
    final before = await snapshot();
    settings.iptv.selectedSourceId.value = '';
    await run();
    expect(await snapshot(), before);
    settings.iptv.selectedSourceId.value = 'A';
    await db.delete(db.channels).go();
    await run();
    expect(await snapshot(), before);
  });
  test('a removed provider does not recreate orphaned mappings', () async {
    await seed();
    await db.deleteProvider('provider');
    expect(await db.getAllMappings(), isEmpty, reason: 'provider deletion cascades its mappings');
    await run();
    expect(await db.getAllMappings(), isEmpty);
  });
  test('eligible auto mapping follows current source but another provider is untouched', () async {
    await seed();
    await seed(provider: 'other', source: 'manual');
    final other = (await db.getAllMappings()).singleWhere((m) => m.providerId == 'other');
    await run();
    await reopen();
    final all = await db.getAllMappings();
    expect(all.singleWhere((m) => m.providerId == 'provider').epgChannelId, epgChannelKey('A', 'news'));
    expect(all.singleWhere((m) => m.providerId == 'other'), other);
  });
  test('unchanged mapping preserves confidence and update time across repeated runs', () async {
    await seed(epg: 'A');
    final before = await snapshot();
    await run();
    await run();
    expect(await snapshot(), before);
  });
  test('raw TVG match takes priority over legacy channel ID and normalizes case', () async {
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'legacy', sourceId: 'A', channelId: 'room', displayName: 'Other'),
    ]);
    await (db.update(
      db.channels,
    )..where((t) => t.id.equals('room'))).write(const ChannelsCompanion(tvgId: drift.Value(' NEWS ')));
    await run();
    expect((await db.getAllMappings()).single.epgChannelId, epgChannelKey('A', 'news'));
  });
  test('legacy channel ID matching remains supported', () async {
    await (db.update(db.channels)..where((t) => t.id.equals('room'))).write(
      const ChannelsCompanion(tvgId: drift.Value(null), name: drift.Value('Unrelated')),
    );
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'legacy', sourceId: 'A', channelId: 'room', displayName: 'Legacy'),
    ]);
    await run();
    expect((await db.getAllMappings()).single.epgChannelId, 'legacy');
  });
  test('exact normalized name beats a containing name', () async {
    await (db.update(db.channels)..where((t) => t.id.equals('room'))).write(
      const ChannelsCompanion(tvgId: drift.Value(null), name: drift.Value('N-e-w-s')),
    );
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'extended', sourceId: 'A', channelId: 'extended', displayName: 'News Extra'),
    ]);
    await run();
    expect((await db.getAllMappings()).single.epgChannelId, epgChannelKey('A', 'news'));
  });
  test('unique containment succeeds but multiple containing names stay unmapped', () async {
    await (db.update(db.channels)..where((t) => t.id.equals('room'))).write(
      const ChannelsCompanion(tvgId: drift.Value(null), name: drift.Value('News HD')),
    );
    await run();
    expect((await db.getAllMappings()).single.epgChannelId, epgChannelKey('A', 'news'));
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'ambiguous', sourceId: 'A', channelId: 'ambiguous', displayName: 'News HD Plus'),
    ]);
    await run();
    expect(await db.getAllMappings(), isEmpty);
  });
  test('empty normalized EPG names do not become universal matches', () async {
    await (db.update(db.channels)..where((t) => t.id.equals('room'))).write(
      const ChannelsCompanion(tvgId: drift.Value(null), name: drift.Value('Unrelated')),
    );
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'punctuation', sourceId: 'A', channelId: 'punctuation', displayName: '!!!'),
    ]);
    await run();
    expect(await db.getAllMappings(), isEmpty);
  });
  test('duplicate normalized names never depend on row order', () async {
    await (db.update(
      db.channels,
    )..where((t) => t.id.equals('room'))).write(const ChannelsCompanion(tvgId: drift.Value(null)));
    await db.upsertEpgChannels([
      EpgChannelsCompanion.insert(id: 'duplicate', sourceId: 'A', channelId: 'duplicate', displayName: 'N-e-w-s'),
    ]);
    await run();
    expect(await db.getAllMappings(), isEmpty);
  });
  test('unmatched automatic rows are pruned but locked orphan rows remain', () async {
    await seed(channel: 'removed');
    await seed(channel: 'locked-orphan', locked: true);
    final locked = (await db.getAllMappings()).singleWhere((m) => m.locked);
    await run();
    final all = await db.getAllMappings();
    expect(all, hasLength(2));
    expect(all.singleWhere((m) => m.locked), locked);
    expect(all.any((m) => m.channelId == 'removed'), isFalse);
  });
  test('A to B to A selection changes invalidate the original work', () async {
    await seed();
    final before = await snapshot();
    db.afterEpgRead = () async {
      settings.iptv.selectedSourceId.value = 'B';
      settings.iptv.selectedSourceId.value = 'A';
    };
    final listeners = settings.iptv.selectedSourceId.listenersLength;
    await run();
    expect(await snapshot(), before);
    expect(settings.iptv.selectedSourceId.listenersLength, listeners);
  });
  test('selection change during write rolls back the whole mapping snapshot', () async {
    await seed();
    await seed(channel: 'removed');
    final before = await snapshot();
    db.afterMappingWrite = () async {
      settings.iptv.selectedSourceId.value = 'B';
    };
    await run();
    await reopen();
    expect(await snapshot(), before);
  });
  test('database errors reach the caller and release the source listener and lock', () async {
    await seed();
    final before = await snapshot();
    final listeners = settings.iptv.selectedSourceId.listenersLength;
    await db.customStatement(
      "CREATE TRIGGER fail_mapping BEFORE INSERT ON epg_mappings BEGIN SELECT RAISE(ABORT, 'mapping fixture failure'); END",
    );
    await expectLater(run(), throwsA(predicate<Object>((e) => e.toString().contains('mapping fixture failure'))));
    expect(await snapshot(), before);
    expect(settings.iptv.selectedSourceId.listenersLength, listeners);
    await db.customStatement('DROP TRIGGER fail_mapping');
    await run();
    expect((await db.getAllMappings()).single.epgSourceId, 'A');
    expect(settings.iptv.selectedSourceId.listenersLength, listeners);
  });
  test('late multi-row insertion failure rolls back earlier deletions and updates', () async {
    for (var i = 0; i < 12; i++) {
      await db.upsertChannels([
        ChannelsCompanion.insert(
          id: 'room-$i',
          providerId: 'provider',
          name: 'News',
          tvgId: const drift.Value('news'),
          streamUrl: 'https://fixture/$i',
        ),
      ]);
      await seed(channel: 'room-$i');
    }
    await seed(channel: 'removed');
    final before = await snapshot();
    await db.customStatement(
      "CREATE TRIGGER fail_mapping BEFORE INSERT ON epg_mappings WHEN NEW.channel_id = 'room-11' BEGIN SELECT RAISE(ABORT, 'late mapping failure'); END",
    );
    await expectLater(run(), throwsA(predicate<Object>((e) => e.toString().contains('late mapping failure'))));
    await reopen();
    expect(await snapshot(), before);
  });
  test('a queued rebuild reads the new source after stale work releases its lock', () async {
    await seed();
    final entered = Completer<void>();
    final release = Completer<void>();
    var reads = 0;
    db.afterEpgRead = () async {
      reads++;
      if (reads == 1) {
        entered.complete();
        await release.future;
      }
    };
    final first = run();
    await entered.future.timeout(const Duration(seconds: 5));
    final second = run();
    settings.iptv.selectedSourceId.value = 'B';
    release.complete();
    await Future.wait([first, second]);
    expect(reads, 2);
    expect((await db.getAllMappings()).single.epgSourceId, 'B');
  });
}

class _Settings extends SettingsService {
  @override
  final iptv = _IptvSettings();
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _IptvSettings implements IptvSettingsController {
  @override
  final selectedSourceId = ''.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Database extends AppDatabase {
  _Database(super.executor) : super.forTesting();
  Future<void> Function()? afterEpgRead;
  Future<void> Function()? afterMappingWrite;
  @override
  Future<void> upsertMappings(List<EpgMappingsCompanion> entries) async {
    await super.upsertMappings(entries);
    await afterMappingWrite?.call();
  }

  @override
  Future<List<EpgChannel>> getEpgChannelsForSource(String sourceId) async {
    final result = await super.getEpgChannelsForSource(sourceId);
    await afterEpgRead?.call();
    return result;
  }
}
