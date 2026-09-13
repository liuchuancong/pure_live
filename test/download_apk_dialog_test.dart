import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pure_live/common/widgets/download_apk_dialog.dart';
import 'package:pure_live/get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory downloadDirectory;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    downloadDirectory = await Directory.systemTemp.createTemp('pure-live-download-dialog-test-');
  });

  tearDown(() {
    Get.reset();
    if (downloadDirectory.existsSync()) downloadDirectory.deleteSync(recursive: true);
  });

  test('download file names stay inside the managed directory', () {
    expect(safeDownloadFileName('https://example.test/releases/PureLive.apk?token=fixture'), 'PureLive.apk');
    expect(
      safeDownloadFileName('https://example.test/releases/app.apk', suggestedName: '../../outside.apk'),
      'outside.apk',
    );
    expect(safeDownloadFileName('https://example.test/releases/%2e%2e%2fescape.apk'), 'escape.apk');
    expect(safeDownloadFileName('https://example.test/'), 'PureLive-download');
  });

  test('long Unicode download names fit staging limits and remain collision resistant', () {
    final sharedPrefix = List.filled(80, '直播更新包').join();
    final first = safeDownloadFileName(
      'https://example.test/releases/app.apk',
      suggestedName: '$sharedPrefix-first.apk',
    );
    final second = safeDownloadFileName(
      'https://example.test/releases/app.apk',
      suggestedName: '$sharedPrefix-second.apk',
    );

    expect(first, endsWith('.apk'));
    expect(second, endsWith('.apk'));
    expect(first, isNot(second));
    expect(utf8.encode('$first.previous'), hasLength(lessThanOrEqualTo(255)));
    expect(utf8.encode('$second.previous'), hasLength(lessThanOrEqualTo(255)));
  });

  test('Unicode truncation keeps complete scalar values', () {
    final result = safeDownloadFileName(
      'https://example.test/releases/app.apk',
      suggestedName: 'a${List.filled(120, '😀').join()}.apk',
    );

    expect(utf8.decode(utf8.encode(result)), result);
    expect(result, endsWith('.apk'));
  });

  testWidgets('Android completion stages atomically and opens the downloaded file', (tester) async {
    String? transferPath;
    String? openedPath;
    final dialog = DownloadApkDialog(
      apkUrl: 'https://example.test/PureLive.apk?token=fixture',
      fileName: '../../PureLive-fixture.apk',
      runtimePlatform: DownloadRuntimePlatform.android,
      completionDelay: Duration.zero,
      downloadDirectoryProvider: () async => downloadDirectory,
      transfer: ({required url, required destinationPath, required cancelToken, required onProgress}) async {
        transferPath = destinationPath;
        File(destinationPath).writeAsStringSync('fixture-apk');
        onProgress(11, 11);
      },
      fileOpener: (filePath) async {
        openedPath = filePath;
        return const DownloadedFileOpenResult.opened();
      },
    );

    final expectedPath = path.join(downloadDirectory.path, 'PureLive-fixture.apk');
    File(expectedPath).writeAsStringSync('previous-apk');

    await _openDialog(tester, dialog);
    await _waitFor(tester, () => transferPath != null);
    await _waitFor(tester, () => openedPath != null);
    await tester.pumpAndSettle();

    expect(transferPath, '$expectedPath.part');
    expect(openedPath, expectedPath);
    expect(File(expectedPath).readAsStringSync(), 'fixture-apk');
    expect(File('$expectedPath.part').existsSync(), isFalse);
    expect(File('$expectedPath.previous').existsSync(), isFalse);
    expect(find.byType(DownloadApkDialog), findsNothing);
  });

  testWidgets('open failure keeps the completed file and offers an open retry', (tester) async {
    var transferCalls = 0;
    var openCalls = 0;
    final dialog = DownloadApkDialog(
      apkUrl: 'https://example.test/PureLive-portable.zip',
      runtimePlatform: DownloadRuntimePlatform.desktop,
      completionDelay: Duration.zero,
      downloadDirectoryProvider: () async => downloadDirectory,
      transfer: ({required url, required destinationPath, required cancelToken, required onProgress}) async {
        transferCalls++;
        File(destinationPath).writeAsStringSync('fixture-zip');
        onProgress(5, 5);
      },
      fileOpener: (filePath) async {
        openCalls++;
        return openCalls == 1
            ? const DownloadedFileOpenResult.failed('fixture shell error')
            : const DownloadedFileOpenResult.opened();
      },
    );

    await _openDialog(tester, dialog, size: const Size(320, 480), textScale: 3);
    await _waitFor(tester, () => transferCalls == 1);
    await _waitFor(tester, () => openCalls == 1);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('The file was downloaded. Opening it failed: fixture shell error'), findsOneWidget);
    final retry = find.byKey(const ValueKey('download-open-again'));
    final scroll = find
        .descendant(of: find.byKey(const ValueKey('download-dialog-scroll')), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(retry, -100, scrollable: scroll, maxScrolls: 10);
    await tester.pump(const Duration(milliseconds: 300));
    expect(retry.hitTestable(), findsOneWidget);
    expect(File(path.join(downloadDirectory.path, 'PureLive-portable.zip')).existsSync(), isTrue);

    await tester.tap(retry);
    await _waitFor(tester, () => openCalls == 2);
    await tester.pumpAndSettle();

    expect(transferCalls, 1);
    expect(openCalls, 2);
    expect(find.byType(DownloadApkDialog), findsNothing);
  });

  testWidgets('cancel removes the staged partial file without opening it', (tester) async {
    final transferDone = Completer<void>();
    var openCalls = 0;
    final dialog = DownloadApkDialog(
      apkUrl: 'https://example.test/PureLive-cancel.apk',
      completionDelay: Duration.zero,
      downloadDirectoryProvider: () async => downloadDirectory,
      transfer: ({required url, required destinationPath, required cancelToken, required onProgress}) {
        File(destinationPath).writeAsStringSync('partial-apk');
        cancelToken.whenCancel.then((_) {
          if (!transferDone.isCompleted) transferDone.complete();
        });
        return transferDone.future;
      },
      fileOpener: (filePath) async {
        openCalls++;
        return const DownloadedFileOpenResult.opened();
      },
    );

    await _openDialog(tester, dialog);
    final partialPath = path.join(downloadDirectory.path, 'PureLive-cancel.apk.part');
    await _waitFor(tester, () => File(partialPath).existsSync());
    await tester.tap(find.byKey(const ValueKey('download-cancel')));
    await _waitFor(tester, () => !File(partialPath).existsSync());
    await tester.pumpAndSettle();

    expect(openCalls, 0);
    expect(find.byType(DownloadApkDialog), findsNothing);
  });

  testWidgets('transfer failure removes the staged partial file', (tester) async {
    var transferFailed = false;
    final dialog = DownloadApkDialog(
      apkUrl: 'https://example.test/PureLive-failed.apk',
      completionDelay: Duration.zero,
      downloadDirectoryProvider: () async => downloadDirectory,
      transfer: ({required url, required destinationPath, required cancelToken, required onProgress}) async {
        File(destinationPath).writeAsStringSync('partial-apk');
        transferFailed = true;
        throw StateError('fixture transfer failure');
      },
    );

    await _openDialog(tester, dialog);
    final partialPath = path.join(downloadDirectory.path, 'PureLive-failed.apk.part');
    await _waitFor(tester, () => transferFailed && !File(partialPath).existsSync());
    await tester.pumpAndSettle();

    expect(File(partialPath).existsSync(), isFalse);
    expect(File(path.join(downloadDirectory.path, 'PureLive-failed.apk')).existsSync(), isFalse);
    expect(find.byType(DownloadApkDialog), findsNothing);
  });

  testWidgets('download dialog actions remain reachable at 320x480 with 3x text', (tester) async {
    final dialog = DownloadApkDialog(
      apkUrl: 'https://example.test/PureLive.apk',
      fileName: 'PureLive-a-very-long-accessible-download-name-arm64-v8a-release.apk',
      startAutomatically: false,
    );

    await _openDialog(tester, dialog, size: const Size(320, 480), textScale: 3);

    final cancel = find.byKey(const ValueKey('download-cancel'));
    final scroll = find
        .descendant(of: find.byKey(const ValueKey('download-dialog-scroll')), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(cancel, -100, scrollable: scroll, maxScrolls: 10);
    await tester.pump(const Duration(milliseconds: 300));
    expect(cancel.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('download completion source does not terminate the running desktop process', () {
    final source = File('lib/common/widgets/download_apk_dialog.dart').readAsStringSync();
    expect(source, isNot(contains('exit(0)')));
    expect(source, isNot(contains('setPreventClose(false)')));
  });

  test('download completion feedback is translated in both locales', () {
    final english = jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
    final chinese = jsonDecode(File('assets/translations/zh.json').readAsStringSync()) as Map<String, dynamic>;
    const keys = {
      'download_complete_opening',
      'download_open_again',
      'download_open_failed',
      'download_open_failed_detail',
    };
    for (final key in keys) {
      expect(english[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
      expect(chinese[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
    }
  });
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 300 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
  expect(condition(), isTrue);
}

Future<void> _openDialog(
  WidgetTester tester,
  DownloadApkDialog dialog, {
  Size size = const Size(800, 600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Translations(),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const ValueKey('show-download-dialog'),
                  onPressed: () =>
                      showDialog<void>(context: context, barrierDismissible: false, builder: (_) => dialog),
                  child: const Text('Show download'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('show-download-dialog')));
  await tester.pump();
}

class _Translations extends AssetLoader {
  const _Translations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => const {
    'cancel': 'Cancel',
    'close': 'Close',
    'download_complete_opening': 'Download complete. Opening file...',
    'download_failed': 'Download failed. Please try again.',
    'download_open_again': 'Open again',
    'download_open_failed': 'The file was downloaded, but opening failed.',
    'download_open_failed_detail': 'The file was downloaded. Opening it failed: {message}',
    'download_preparing': 'Preparing...',
    'downloaded_mb': 'Downloaded: {mb} MB',
    'downloading_app': 'Downloading {app}...',
    'downloading_version': 'Downloading v{version}...',
    'install_tip': 'Continue in the system installer.',
  };
}
