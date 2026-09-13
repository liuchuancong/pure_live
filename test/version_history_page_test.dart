import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/release_model.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/about/version_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-version-history-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService());
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('narrow 3x text keeps release details and every action reachable', (tester) async {
    final opened = <Uri>[];
    final downloads = <String>[];
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pumpPage(
      tester,
      size: const Size(320, 480),
      textScale: 3,
      loader: () async => [_release('3.2.0', fileUrl: '  https://Example.TEST/PureLive-3.2.0-portable.zip  ')],
      openExternalUrl: (uri) async {
        opened.add(uri);
        return true;
      },
      downloadRelease: (url, {fileName}) async => downloads.add('$fileName|$url'),
    );

    expect(find.byKey(const ValueKey('release-history-mobile-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('release-history-mobile-stacked-3.2.0')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 152);
    await tester.tap(find.byKey(const ValueKey('release-history-mobile-3.2.0')));
    await tester.pumpAndSettle();

    final detailsScroll = find
        .descendant(of: find.byKey(const ValueKey('release-history-detail-scroll')), matching: find.byType(Scrollable))
        .first;
    final releaseAction = find.byKey(const ValueKey('release-history-open-release'));
    await tester.scrollUntilVisible(releaseAction, 100, scrollable: detailsScroll, maxScrolls: 10);
    expect(releaseAction.hitTestable(), findsOneWidget);
    await tester.tap(releaseAction);
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://example.test/releases/3.2.0')]);

    final copyAction = find.byTooltip('Copy Link');
    await tester.scrollUntilVisible(copyAction, 200, scrollable: detailsScroll, maxScrolls: 30);
    await tester.tap(copyAction);
    await tester.pumpAndSettle();
    expect(clipboardText, 'https://example.test/PureLive-3.2.0-portable.zip');
    expect(find.text('Copied to clipboard'), findsOneWidget);

    final downloadAction = find.byTooltip('Download');
    await tester.scrollUntilVisible(downloadAction, 120, scrollable: detailsScroll, maxScrolls: 10);
    await tester.tap(downloadAction);
    await tester.pumpAndSettle();
    expect(find.text('Download "PureLive-3.2.0-portable.zip"?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download').hitTestable(), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Download'));
    await tester.pumpAndSettle();
    expect(downloads, ['PureLive-3.2.0-portable.zip|https://example.test/PureLive-3.2.0-portable.zip']);

    final close = find.byKey(const ValueKey('release-history-close-details'));
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('release-history-detail-scroll')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('download confirmation coalesces route and active download work', (tester) async {
    final downloadGate = Completer<void>();
    var downloadCalls = 0;
    await _pumpPage(
      tester,
      loader: () async => [_release('3.2.0')],
      downloadRelease: (url, {fileName}) {
        downloadCalls++;
        return downloadGate.future;
      },
    );

    await tester.tap(find.byKey(const ValueKey('release-history-mobile-3.2.0')));
    await tester.pumpAndSettle();
    final detailsScroll = find
        .descendant(of: find.byKey(const ValueKey('release-history-detail-scroll')), matching: find.byType(Scrollable))
        .first;
    final downloadAction = find.byTooltip('Download');
    await tester.scrollUntilVisible(downloadAction, 120, scrollable: detailsScroll, maxScrolls: 10);
    final button = tester.widget<IconButton>(find.ancestor(of: downloadAction, matching: find.byType(IconButton)));
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Download "PureLive-3.2.0-portable.zip"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Download'));
    await tester.pumpAndSettle();
    expect(downloadCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);

    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(downloadCalls, 1);

    downloadGate.complete();
    await tester.pumpAndSettle();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(downloadCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout switches details without rebuilding a mobile dialog', (tester) async {
    await _pumpPage(tester, size: const Size(1000, 700), loader: () async => [_release('3.2.0'), _release('3.1.9')]);

    expect(find.byKey(const ValueKey('release-history-desktop-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('release-history-detail-3.2.0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('release-history-desktop-3.1.9')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('release-history-detail-3.1.9')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh keeps cached releases visible and reports the failure', (tester) async {
    final refresh = Completer<List<ReleaseModel>>();
    var calls = 0;
    await _pumpPage(
      tester,
      loader: () {
        calls++;
        return calls == 1 ? Future.value([_release('3.2.0')]) : refresh.future;
      },
    );

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(find.byKey(const ValueKey('release-history-mobile-3.2.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('release-history-refresh-progress')), findsOneWidget);

    refresh.completeError(StateError('fixture refresh failure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('release-history-mobile-3.2.0')), findsOneWidget);
    expect(
      find.text('The release history could not be refreshed. Existing entries are still available.'),
      findsOneWidget,
    );
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful refresh preserves the selected version after reordering', (tester) async {
    var calls = 0;
    await _pumpPage(
      tester,
      size: const Size(1000, 700),
      loader: () async {
        calls++;
        return calls == 1 ? [_release('3.2.0'), _release('3.1.9')] : [_release('3.1.9'), _release('3.2.0')];
      },
    );

    await tester.tap(find.byKey(const ValueKey('release-history-desktop-3.1.9')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('release-history-detail-3.1.9')), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('release-history-detail-3.1.9')), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  Size size = const Size(600, 700),
  double textScale = 1,
  required ReleaseHistoryLoader loader,
  ReleaseHistoryExternalLauncher? openExternalUrl,
  ReleaseHistoryDownloadHandler? downloadRelease,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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
          home: VersionHistoryPage(
            releaseLoader: loader,
            openExternalUrl: openExternalUrl,
            downloadRelease: downloadRelease,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ReleaseModel _release(String version, {String? fileUrl}) {
  return ReleaseModel(
    version: version,
    title: 'Pure Live $version',
    date: '2026-09-11',
    github: 'https://example.test/releases/$version',
    author: AuthorModel(name: 'Maintainer', avatar: '', profile: ''),
    changelog: '# Changes\n\nA focused release history fixture with enough content to exercise scrolling.',
    files: [
      ReleaseFileModel(
        name: 'PureLive-$version-portable.zip',
        size: '64 MB',
        downloads: 17,
        url: fileUrl ?? 'https://example.test/PureLive-$version-portable.zip',
      ),
    ],
  );
}

class _Translations extends AssetLoader {
  const _Translations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => const {
    'version_history_desc': 'Version history',
    'refresh': 'Refresh',
    'version_file_size': 'File size: {size}',
    'version_published_at': 'Published at {date}',
    'version_history_open_release': 'Open release page',
    'download_files': 'Download files',
    'version_downloads_count': '{size} · {count} downloads',
    'copy_link': 'Copy Link',
    'download': 'Download',
    'copied_to_clipboard': 'Copied to clipboard',
    'close': 'Close',
    'tip': 'Tip',
    'cancel': 'Cancel',
    'open_download_confirm': 'Open this download?',
    'open_download_confirm_named': 'Download "{name}"?',
    'external_browser_not_opened': 'The system browser did not open.',
    'version_history_download_failed': 'The download could not be started. Please try again.',
    'version_history_load_failed': 'The release history could not be refreshed. Existing entries are still available.',
    'version_history_unnamed_file': 'Unnamed file',
    'status_error_title': 'Something went wrong',
    'status_error_subtitle': 'Try again.',
    'status_retry_button': 'Retry',
    'status_empty_title': 'No data',
    'status_empty_subtitle': 'Nothing here yet.',
  };
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService() : _theme = ThemeSettingsController();

  final ThemeSettingsController _theme;

  @override
  ThemeSettingsController get theme => _theme;

  @override
  // Test fixture intentionally skips production service registrations.
  // ignore: must_call_super
  void onInit() {}
}
