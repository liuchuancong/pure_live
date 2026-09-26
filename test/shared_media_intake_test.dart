import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/shared_live_link_opener.dart';
import 'package:pure_live/common/utils/shared_media_intake.dart';
import 'package:share_handler/share_handler.dart';

void main() {
  test('a room command takes precedence over file attachments and is handled once', () async {
    final commands = <String>[];
    final files = <String>[];
    final released = <String>[];
    final unsupported = <String>[];
    final intake = SharedMediaIntake(
      isRoomCommand: (text) => text == 'room-command',
      consumeRoomCommand: (text) async {
        commands.add(text);
        return true;
      },
      importPlaylist: (path) async {
        files.add(path);
        return true;
      },
      importEpg: (path) async {
        files.add(path);
        return true;
      },
      releaseAttachment: (path) async => released.add(path),
      notifyUnsupported: unsupported.add,
    );

    final result = await intake.ingest(
      SharedMedia(content: ' room-command ', attachments: [_attachment('/cache/ignored.m3u')]),
    );

    expect(result.kind, SharedMediaIntakeKind.roomCommand);
    expect(result.attemptedCount, 1);
    expect(result.acceptedCount, 1);
    expect(commands, ['room-command']);
    expect(files, isEmpty);
    expect(released, ['/cache/ignored.m3u']);
    expect(unsupported, isEmpty);
  });

  test('Android attachment paths are deduplicated and routed by supported extension', () async {
    final operations = <String>[];
    final released = <String>[];
    final intake = _intake(
      importPlaylist: (path) async {
        operations.add('playlist:$path');
        return true;
      },
      importEpg: (path) async {
        operations.add('epg:$path');
        return true;
      },
      releaseAttachment: (path) async => released.add(path),
    );

    final result = await intake.ingest(
      SharedMedia(
        attachments: [
          _attachment('/cache/Fixture.M3U'),
          _attachment('/cache/guide.XML'),
          _attachment('/cache/Fixture.M3U'),
          null,
          _attachment('/cache/poster.png'),
        ],
      ),
    );

    expect(result.kind, SharedMediaIntakeKind.files);
    expect(result.attemptedCount, 2);
    expect(result.acceptedCount, 2);
    expect(operations, ['playlist:/cache/Fixture.M3U', 'epg:/cache/guide.XML']);
    expect(released, ['/cache/Fixture.M3U', '/cache/guide.XML', '/cache/poster.png']);
  });

  test('legacy content paths retain file URI decoding and query-safe extension matching', () async {
    final operations = <String>[];
    final intake = _intake(
      importPlaylist: (path) async {
        operations.add(path);
        return true;
      },
    );

    final first = await intake.ingest(SharedMedia(content: 'file:///cache/Fixture.M3U8'));
    final second = await intake.ingest(SharedMedia(content: '/cache/second.txt?source=share'));

    expect(first.kind, SharedMediaIntakeKind.files);
    expect(second.kind, SharedMediaIntakeKind.files);
    expect(operations, ['file:///cache/Fixture.M3U8', '/cache/second.txt?source=share']);
  });

  test('unsupported and empty shares emit one localized feedback each', () async {
    final unsupported = <String>[];
    final intake = _intake(notifyUnsupported: unsupported.add);

    final first = await intake.ingest(SharedMedia(content: 'ordinary shared text'));
    final second = await intake.ingest(SharedMedia(attachments: [_attachment('/cache/poster.png')]));
    final third = await intake.ingest(SharedMedia());

    expect([first.kind, second.kind, third.kind], everyElement(SharedMediaIntakeKind.unsupported));
    expect(unsupported, List.filled(3, 'unsupported_file_format'));
  });

  test('a failing queued import is contained and a later share still runs', () async {
    final errors = <Object>[];
    final operations = <String>[];
    final released = <String>[];
    final intake = _intake(
      importPlaylist: (_) async => throw StateError('fixture playlist failure'),
      importEpg: (path) async {
        operations.add(path);
        return true;
      },
      releaseAttachment: (path) async => released.add(path),
      reportError: (error, _) => errors.add(error),
    );

    final failed = intake.ingest(
      SharedMedia(attachments: [_attachment('/cache/list.m3u'), _attachment('/cache/not-reached.json')]),
    );
    final recovered = intake.ingest(SharedMedia(attachments: [_attachment('/cache/guide.json')]));

    expect((await failed).kind, SharedMediaIntakeKind.failed);
    expect((await recovered).kind, SharedMediaIntakeKind.files);
    expect(operations, ['/cache/guide.json']);
    expect(released, ['/cache/list.m3u', '/cache/not-reached.json', '/cache/guide.json']);
    expect(errors, hasLength(1));
  });

  test('attachment release failures are reported and do not skip later cleanup', () async {
    final errors = <Object>[];
    final released = <String>[];
    final intake = _intake(
      releaseAttachment: (path) async {
        released.add(path);
        if (path.endsWith('first.bin')) throw StateError('fixture release failure');
      },
      reportError: (error, _) => errors.add(error),
    );

    final result = await intake.ingest(
      SharedMedia(attachments: [_attachment('/cache/first.bin'), _attachment('/cache/second.bin')]),
    );

    expect(result.kind, SharedMediaIntakeKind.unsupported);
    expect(released, ['/cache/first.bin', '/cache/second.bin']);
    expect(errors.single, isA<StateError>());
  });

  test('receiver subscribes before awaiting cold-start media, consumes it and resets it', () async {
    final initial = Completer<SharedMedia?>();
    final stream = StreamController<SharedMedia>();
    final operations = <String>[];
    var resets = 0;
    final liveHandled = Completer<void>();
    final intake = _intake(
      consumeRoomCommand: (text) async {
        operations.add('command:$text');
        return true;
      },
      isRoomCommand: (text) => text == 'cold-command',
      importEpg: (path) async {
        operations.add('epg:$path');
        liveHandled.complete();
        return true;
      },
    );
    final receiver = SharedMediaReceiver(
      readInitialMedia: () => initial.future,
      resetInitialMedia: () async => resets++,
      mediaStream: stream.stream,
      intake: intake,
    );

    final start = receiver.start();
    expect(identical(start, receiver.start()), isTrue);
    stream.add(SharedMedia(attachments: [_attachment('/cache/live.xml')]));
    await liveHandled.future;
    initial.complete(SharedMedia(content: 'cold-command'));
    await start;

    expect(operations, ['epg:/cache/live.xml', 'command:cold-command']);
    expect(resets, 1);
    await receiver.dispose();
    await stream.close();
  });

  test('receiver resets unsupported cold-start media and reports source errors without escaping', () async {
    final errors = <Object>[];
    final unsupported = <String>[];
    var resets = 0;
    final receiver = SharedMediaReceiver(
      readInitialMedia: () async => SharedMedia(content: 'unsupported cold text'),
      resetInitialMedia: () async => resets++,
      mediaStream: const Stream<SharedMedia>.empty(),
      intake: _intake(notifyUnsupported: unsupported.add),
      reportError: (error, _) => errors.add(error),
    );

    await receiver.start();
    await receiver.dispose();

    expect(unsupported, ['unsupported_file_format']);
    expect(resets, 1);
    expect(errors, isEmpty);
  });

  test('receiver contains asynchronous media stream errors and remains disposable', () async {
    final errors = <Object>[];
    final stream = StreamController<SharedMedia>();
    final errorObserved = Completer<void>();
    final receiver = SharedMediaReceiver(
      readInitialMedia: () async => null,
      resetInitialMedia: () async {},
      mediaStream: stream.stream,
      intake: _intake(),
      reportError: (error, _) {
        errors.add(error);
        errorObserved.complete();
      },
    );

    await receiver.start();
    stream.addError(StateError('fixture stream failure'), StackTrace.current);
    await errorObserved.future;
    await receiver.dispose();
    await stream.close();

    expect(errors.single, isA<StateError>());
  });

  test('Android share declarations are scoped to supported content and use the real target', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final debugManifest = File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
    final targets = File('android/app/src/main/res/xml/share_targets.xml').readAsStringSync();
    final probe = File('android/app/src/debug/kotlin/com/mystyle/pure_live/ShareIntentProbeReceiver.kt')
        .readAsStringSync();
    final probeProvider = File('android/app/src/debug/kotlin/com/mystyle/pure_live/ShareIntentProbeProvider.kt')
        .readAsStringSync();

    expect(manifest, contains('android.intent.action.SEND'));
    expect(manifest, contains('android.intent.action.SEND_MULTIPLE'));
    expect(manifest, isNot(contains('android:mimeType="*/*"')));
    expect(targets, contains('com.mystyle.purelive.MainActivity'));
    expect(targets, contains('com.mystyle.purelive.dynamic_share_target'));
    expect(targets, isNot(contains('{your.package.identifier}')));
    expect(manifest, isNot(contains('ShareIntentProbeReceiver')));
    expect(manifest, isNot(contains('ShareIntentProbeProvider')));
    expect(debugManifest, contains('android:name=".ShareIntentProbeReceiver"'));
    expect(debugManifest, contains('android:permission="android.permission.DUMP"'));
    expect(debugManifest, contains('android:name=".ShareIntentProbeProvider"'));
    expect(debugManifest, contains('android:exported="false"'));
    expect(probe, contains('Intent.ACTION_SEND_MULTIPLE'));
    expect(probe, contains('putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)'));
    expect(probe, contains('File(context.cacheDir, "share_probe").canonicalFile'));
    expect(probe, contains('validatedFiles(context, request, 1..MAX_ATTACHMENTS)'));
    expect(probe, contains('ShareIntentProbeProvider.MODE_TYPE_ERROR'));
    expect(probe, contains('ShareIntentProbeProvider.MODE_QUERY_ERROR'));
    expect(probe, contains('ShareIntentProbeProvider.MODE_LONG_NAME'));
    expect(probeProvider, contains('intentional debug provider type failure'));
    expect(probeProvider, contains('intentional debug provider query failure'));
    expect(probeProvider, contains('LONG_DISPLAY_NAME'));
    expect(probeProvider, contains('ParcelFileDescriptor.MODE_READ_ONLY'));
    expect(probeProvider, contains('file.isWithin(root)'));
  });

  test('app-owned navigator defers cold share presentation until splash has finished', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final windowSource = File('lib/common/global/platform/desktop_manager.dart').readAsStringSync();

    expect(mainSource, contains('navigatorKey: appNavigatorKey'));
    expect(mainSource, contains('releaseAttachment: (path) async'));
    expect(mainSource, contains('FileUtils.cleanupOwnedSharedMediaFile(File(path))'));
    expect(windowSource, contains('appNavigatorKey.currentContext'));
    expect(windowSource, contains('currentRoute != RoutePath.kSplash'));
    expect(windowSource, contains('ShareCommandImportDialog.show(context: navigatorContext'));
    expect(windowSource, isNot(contains('ShareCommandImportDialog.show(context: context')));

    final androidPlugin = File(
      'plugins/built_in_kotlin/share_handler_android/android/src/main/kotlin/com/shoutsocial/share_handler/ShareHandlerPlugin.kt',
    ).readAsStringSync();
    expect(androidPlugin, contains('uri.scheme.equals("file", ignoreCase = true)'));
    expect(androidPlugin, contains('File(applicationContext.cacheDir, "share_handler")'));
    expect(androidPlugin, contains('File(directory, safeName)'));
    expect(androidPlugin, contains('UUID.randomUUID().toString()'));
    expect(androidPlugin, contains('MAX_ATTACHMENT_NAME_BYTES = 180'));
    expect(androidPlugin, contains('candidate.toByteArray(Charsets.UTF_8).size'));
    expect(androidPlugin, contains('private fun truncateUtf8'));
    expect(androidPlugin, contains('character.code < 0x20 || character.code == 0x7f'));
    expect(androidPlugin, contains('Shared URI attachment failed'));
    expect(androidPlugin, contains('directory.deleteRecursively()'));
    expect(androidPlugin, contains('contentResolver.openInputStream(uri) ?: return false'));
    expect(androidPlugin, isNot(contains('FileDirectory.getAbsolutePath(applicationContext, uri)')));
  });

  test('text shared from a platform app opens the linked live room', () async {
    const shared = '快来看直播 https://live.bilibili.com/6 分享自哔哩哔哩';
    final opened = <String>[];
    var unsupported = 0;
    final intake = _intake(
      isLiveLink: SharedLiveLinkOpener.containsLiveLink,
      openLiveLink: (text) async {
        opened.add(text);
        return true;
      },
      notifyUnsupported: (_) => unsupported++,
    );
    final result = await intake.ingest(SharedMedia(content: shared));
    expect(result.kind, SharedMediaIntakeKind.liveLink);
    expect(result.handled, isTrue);
    expect(opened, [shared]);
    expect(unsupported, 0);

    final prose = await intake.ingest(SharedMedia(content: 'just some words'));
    expect(prose.kind, SharedMediaIntakeKind.unsupported);
    expect(unsupported, 1);
  });

  test('the live link opener resolves the room and does not wait for the room route', () async {
    final routeClosed = Completer<void>();
    final notices = <String>[];
    LiveRoom? openedRoom;
    var waits = 0;
    final opener = SharedLiveLinkOpener(
      parse: (text) async => text.contains('/6') ? ['6', 'bilibili'] : const <String>[],
      open: (room) {
        openedRoom = room;
        return routeClosed.future;
      },
      waitForNavigator: () async => waits++,
      notify: notices.add,
    );
    expect(await opener.open('https://live.bilibili.com/6'), isTrue);
    expect(waits, 1);
    expect(openedRoom?.roomId, '6');
    expect(openedRoom?.platform, 'bilibili');
    expect(await opener.open('https://example.com/none'), isFalse);
    expect(notices, ['toolbox_parse_failed']);
    routeClosed.complete();
  });
}

SharedAttachment _attachment(String path) => SharedAttachment(path: path, type: SharedAttachmentType.file);

SharedMediaIntake _intake({
  SharedRoomCommandPredicate? isRoomCommand,
  SharedRoomCommandConsumer? consumeRoomCommand,
  SharedFileImporter? importPlaylist,
  SharedFileImporter? importEpg,
  SharedAttachmentReleaser? releaseAttachment,
  SharedMediaFeedback? notifyUnsupported,
  SharedMediaErrorReporter? reportError,
  SharedRoomCommandPredicate? isLiveLink,
  SharedRoomCommandConsumer? openLiveLink,
}) {
  return SharedMediaIntake(
    isLiveLink: isLiveLink,
    openLiveLink: openLiveLink,
    isRoomCommand: isRoomCommand ?? (_) => false,
    consumeRoomCommand: consumeRoomCommand ?? (_) async => true,
    importPlaylist: importPlaylist ?? (_) async => true,
    importEpg: importEpg ?? (_) async => true,
    releaseAttachment: releaseAttachment ?? (_) async {},
    notifyUnsupported: notifyUnsupported ?? (_) {},
    reportError: reportError,
  );
}
