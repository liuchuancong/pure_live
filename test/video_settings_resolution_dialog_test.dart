import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/video_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-video-settings-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
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
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('resolution preferences localize stable values and keep whole options tappable', (tester) async {
    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.windows,
    );

    await tester.scrollUntilVisible(find.text('Desktop Default Volume'), 120, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    final volumeTitle = tester.getRect(find.text('Desktop Default Volume'));
    final volumeValue = tester.getRect(find.text('100%'));
    expect(volumeValue.top, greaterThanOrEqualTo(volumeTitle.bottom));
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Resolution Preference'), 180, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsNWidgets(2));
    expect(find.text('原画'), findsNothing);

    await tester.tap(find.text('Resolution Preference'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    for (final label in ['Original', 'Blu-ray 8 Mbps', 'Blu-ray 4 Mbps', 'Super HD', 'Smooth']) {
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(label)), findsOneWidget);
    }
    expect(find.text('原画'), findsNothing);
    expect(tester.takeException(), isNull);

    final smoothOption = find.widgetWithText(SimpleDialogOption, 'Smooth');
    await tester.ensureVisible(smoothOption);
    await tester.pumpAndSettle();
    await tester.tap(smoothOption);
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.preferResolution.value, '流畅');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Smooth'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Mobile Network Quality'), 120, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile Network Quality'));
    await tester.pumpAndSettle();
    final cellularOption = find.widgetWithText(SimpleDialogOption, 'Blu-ray 4 Mbps');
    await tester.ensureVisible(cellularOption);
    await tester.pumpAndSettle();
    await tester.tap(cellularOption);
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.preferResolutionCellular.value, '蓝光4M');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Blu-ray 4 Mbps'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !Platform.isWindows);

  testWidgets('unknown resolution values render and select through the canonical default', (tester) async {
    SettingsService.to.player.preferResolution.value = 'retired-wifi-quality';
    SettingsService.to.player.preferResolutionCellular.value = 'retired-cellular-quality';

    await _pumpVideoSettings(tester, english: english, size: const Size(420, 800), platform: TargetPlatform.windows);

    await tester.scrollUntilVisible(find.text('Resolution Preference'), 180, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsNWidgets(2));
    expect(find.text('retired-wifi-quality'), findsNothing);
    expect(find.text('retired-cellular-quality'), findsNothing);
    expect(SettingsService.to.player.preferResolution.value, 'retired-wifi-quality');

    await tester.tap(find.text('Resolution Preference'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<String>>(find.descendant(of: dialog, matching: find.byType(RadioGroup<String>)))
          .groupValue,
      '原画',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Original'));
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.preferResolution.value, '原画');
    expect(dialog, findsNothing);
  }, skip: !Platform.isWindows);

  testWidgets('resolution selectors share one responsive route and commit only its returned choice', (tester) async {
    final player = SettingsService.to.player;
    player.preferResolution.value = '高清';
    player.preferResolutionCellular.value = '超清';

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.windows,
    );

    final wifiEntry = find.ancestor(of: find.text('Resolution Preference'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, wifiEntry);
    final wifiTap = tester.widget<ListTile>(wifiEntry).onTap!;
    final cellularEntry = find.ancestor(of: find.text('Mobile Network Quality'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, cellularEntry);
    final cellularTap = tester.widget<ListTile>(cellularEntry).onTap!;

    wifiTap();
    cellularTap();
    await _pumpRouteTransition(tester);

    final dialog = find.byKey(const ValueKey('resolution-preference-dialog'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(dialog, findsOneWidget);
    expect(player.preferResolution.value, '高清');
    expect(player.preferResolutionCellular.value, '超清');
    final cancel = find.widgetWithText(TextButton, 'Cancel').hitTestable();
    expect(cancel, findsOneWidget);
    expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(dialog).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(dialog).bottom, lessThanOrEqualTo(480));

    await tester.tap(cancel);
    await _pumpRouteTransition(tester);
    expect(dialog, findsNothing);
    expect(player.preferResolution.value, '高清');
    expect(player.preferResolutionCellular.value, '超清');

    cellularTap();
    await _pumpRouteTransition(tester);
    expect(dialog, findsOneWidget);
    final cellularOption = find.widgetWithText(SimpleDialogOption, 'Blu-ray 4 Mbps');
    await tester.ensureVisible(cellularOption);
    await tester.pump();
    await tester.tap(cellularOption);
    await _pumpRouteTransition(tester);

    expect(dialog, findsNothing);
    expect(player.preferResolution.value, '高清');
    expect(player.preferResolutionCellular.value, '蓝光4M');
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('disposed video settings ignores a captured resolution action', (tester) async {
    await _pumpVideoSettings(tester, english: english, size: const Size(420, 800), platform: TargetPlatform.windows);

    final wifiEntry = find.ancestor(of: find.text('Resolution Preference'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, wifiEntry);
    final wifiTap = tester.widget<ListTile>(wifiEntry).onTap!;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(wifiTap, returnsNormally);
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('covered video settings does not place a stale resolution dialog over the current route', (tester) async {
    await _pumpVideoSettings(tester, english: english, size: const Size(420, 800), platform: TargetPlatform.windows);

    final wifiEntry = find.ancestor(of: find.text('Resolution Preference'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, wifiEntry);
    final wifiTap = tester.widget<ListTile>(wifiEntry).onTap!;
    final navigator = Navigator.of(tester.element(wifiEntry));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Current route'))));
    await _pumpRouteTransition(tester);

    wifiTap();
    await _pumpRouteTransition(tester);

    expect(find.text('Current route'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('Windows PiP reset coalesces confirmation and preserves or clears the whole saved geometry', (
    tester,
  ) async {
    final window = SettingsService.to.window;
    window.windowsPip.update(const Size(640, 360), const Offset(120, 80), 'DISPLAY-1');

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.windows,
    );

    final resetEntry = find.ancestor(of: find.text('Reset PiP position and size'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, resetEntry);
    final resetTap = tester.widget<ListTile>(resetEntry).onTap!;

    resetTap();
    resetTap();
    await _pumpRouteTransition(tester);

    final dialog = find.byKey(const ValueKey('windows-pip-reset-dialog'));
    expect(dialog, findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(window.windowsPip.displayId.value, 'DISPLAY-1');
    expect(window.windowsPip.size, const Size(640, 360));
    expect(window.windowsPip.position, const Offset(120, 80));

    final cancel = find.widgetWithText(TextButton, 'Cancel').hitTestable();
    final reset = find.widgetWithText(FilledButton, 'Reset').hitTestable();
    expect(cancel, findsOneWidget);
    expect(reset, findsOneWidget);
    expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(reset).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(reset).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(dialog).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(dialog).bottom, lessThanOrEqualTo(480));

    await tester.tap(cancel);
    await _pumpRouteTransition(tester);
    expect(dialog, findsNothing);
    expect(window.windowsPip.displayId.value, 'DISPLAY-1');
    expect(window.windowsPip.size, const Size(640, 360));
    expect(window.windowsPip.position, const Offset(120, 80));

    resetTap();
    await _pumpRouteTransition(tester);
    expect(dialog, findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset').hitTestable());
    await _pumpRouteTransition(tester);

    expect(dialog, findsNothing);
    expect(window.windowsPip.displayId.value, isEmpty);
    expect(window.windowsPip.size, Size.zero);
    expect(window.windowsPip.position, Offset.zero);
    expect(window.windowsPip.isValid, isFalse);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('Windows PiP always-on-top serializes native updates and commits only after success', (tester) async {
    final player = SettingsService.to.player;
    player.windowsPipAlwaysOnTop.value = false;
    final enableAttempt = Completer<void>();
    final disableAttempt = Completer<void>();
    final requests = <bool>[];

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(420, 800),
      platform: TargetPlatform.windows,
      pipAlwaysOnTopSetterOverride: (enabled) {
        requests.add(enabled);
        return switch (requests.length) {
          1 => enableAttempt.future,
          2 || 3 => Future<void>.value(),
          4 => disableAttempt.future,
          _ => throw StateError('unexpected native update'),
        };
      },
    );

    final pinEntry = find.ancestor(
      of: find.text('Keep Windows mini player on top'),
      matching: find.byType(SwitchListTile),
    );
    await _scrollPageUntilHitTestable(tester, pinEntry);
    final enable = tester.widget<SwitchListTile>(pinEntry).onChanged!;
    enable(true);
    enable(true);
    await tester.pump();

    expect(requests, [true]);
    expect(player.windowsPipAlwaysOnTop.value, isFalse);
    expect(tester.widget<SwitchListTile>(pinEntry).onChanged, isNull);

    enableAttempt.completeError(StateError('fixture failure'));
    await tester.pumpAndSettle();

    expect(requests, [true, false]);
    expect(player.windowsPipAlwaysOnTop.value, isFalse);
    expect(find.text('Could not update mini player stacking. Try again.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(pinEntry).onChanged, isNotNull);

    tester.widget<SwitchListTile>(pinEntry).onChanged!(true);
    await tester.pumpAndSettle();

    expect(requests, [true, false, true]);
    expect(player.windowsPipAlwaysOnTop.value, isTrue);

    final disable = tester.widget<SwitchListTile>(pinEntry).onChanged!;
    disable(false);
    disable(false);
    await tester.pump();

    expect(requests, [true, false, true, false]);
    expect(player.windowsPipAlwaysOnTop.value, isTrue);
    expect(tester.widget<SwitchListTile>(pinEntry).onChanged, isNull);

    disableAttempt.complete();
    await tester.pumpAndSettle();

    expect(requests, [true, false, true, false]);
    expect(player.windowsPipAlwaysOnTop.value, isFalse);
    expect(tester.widget<SwitchListTile>(pinEntry).onChanged, isNotNull);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR timer owns one responsive route and releases it after cancellation', (tester) async {
    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.android,
    );

    final timerEntry = find.ancestor(of: find.text('Auto sleep playback duration'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, timerEntry);
    final openTimer = tester.widget<ListTile>(timerEntry).onTap!;

    openTimer();
    openTimer();
    await _pumpRouteTransition(tester);

    final dialog = find.byKey(const ValueKey('asmr-sleep-timer-dialog'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(dialog, findsOneWidget);
    final cancel = find.widgetWithText(TextButton, 'Cancel').hitTestable();
    expect(cancel, findsOneWidget);
    expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(dialog).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(dialog).bottom, lessThanOrEqualTo(480));

    await tester.tap(cancel);
    await _pumpRouteTransition(tester);
    expect(dialog, findsNothing);

    openTimer();
    await _pumpRouteTransition(tester);
    expect(dialog, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').hitTestable());
    await _pumpRouteTransition(tester);
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR timer keeps every preset and action reachable in narrow very-large text', (tester) async {
    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.android,
    );

    final timerEntry = find.ancestor(of: find.text('Auto sleep playback duration'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, timerEntry);
    await tester.tap(timerEntry.hitTestable());
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.byType(ActionChip)), findsNWidgets(10));
    expect(find.descendant(of: dialog, matching: find.text('Custom playback duration')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    for (final label in ['15 min', '30 min', '45 min', '1 h', '90 min', '2 h', '4 h', '8 h', '12 h', '1 d']) {
      expect(find.descendant(of: dialog, matching: find.text(label)), findsOneWidget);
    }
    final lastPreset = find.descendant(of: dialog, matching: find.byType(ActionChip)).last;
    await tester.ensureVisible(lastPreset);
    await tester.pumpAndSettle();
    expect(tester.getRect(lastPreset).bottom, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR timer keeps a focused custom input alive through route dismissal', (tester) async {
    await _pumpVideoSettings(tester, english: english, size: const Size(420, 800), platform: TargetPlatform.android);

    final timerEntry = find.ancestor(of: find.text('Auto sleep playback duration'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, timerEntry);
    await tester.tap(timerEntry.hitTestable());
    await tester.pumpAndSettle();
    final customInput = find.byType(TextField);
    await tester.ensureVisible(customInput);
    await tester.pumpAndSettle();
    await tester.enterText(customInput, '7');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(SettingsService.to.app.asmrSleepMinutes.value, 7);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !Platform.isWindows);

  testWidgets('ASMR timer validates inline and serializes a failing save before retry', (tester) async {
    final app = SettingsService.to.app;
    app.asmrSleepMinutes.value = 60;
    final firstAttempt = Completer<void>();
    var calls = 0;

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(420, 800),
      platform: TargetPlatform.android,
      sleepTimerConfiguratorOverride: ({required enabled, required minutes}) {
        calls++;
        return calls == 1 ? firstAttempt.future : Future<void>.value();
      },
    );

    final timerEntry = find.ancestor(of: find.text('Auto sleep playback duration'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, timerEntry);
    await tester.tap(timerEntry.hitTestable());
    await _pumpRouteTransition(tester);

    final dialog = find.byKey(const ValueKey('asmr-sleep-timer-dialog'));
    final customInput = find.descendant(of: dialog, matching: find.byType(TextField));
    await tester.enterText(customInput, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(app.asmrSleepMinutes.value, 60);
    expect(find.text('Enter 1 minute to 365 days'), findsOneWidget);

    await tester.enterText(customInput, '7');
    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    save.onPressed!();
    save.onPressed!();
    await tester.pump();

    expect(calls, 1);
    expect(app.asmrSleepMinutes.value, 60);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widget<TextField>(customInput).enabled, isFalse);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);

    firstAttempt.completeError(StateError('fixture failure'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(dialog, findsOneWidget);
    expect(app.asmrSleepMinutes.value, 60);
    expect(find.text('Could not update the sleep timer. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(customInput).enabled, isTrue);

    await tester.enterText(customInput, '8');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpRouteTransition(tester);

    expect(calls, 2);
    expect(app.asmrSleepMinutes.value, 8);
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR mode serializes disable work and commits only after the timer service succeeds', (tester) async {
    final app = SettingsService.to.app;
    app.enableAsmrSleepMode.value = true;
    app.asmrSleepMinutes.value = 60;
    final disableAttempt = Completer<void>();
    var calls = 0;

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(420, 800),
      platform: TargetPlatform.android,
      sleepTimerConfiguratorOverride: ({required enabled, required minutes}) {
        calls++;
        expect(enabled, isFalse);
        expect(minutes, 60);
        return calls == 1 ? disableAttempt.future : Future<void>.value();
      },
    );

    final modeEntry = find.ancestor(
      of: find.text('Auto-start sleep audio for new rooms'),
      matching: find.byType(SwitchListTile),
    );
    await _scrollPageUntilHitTestable(tester, modeEntry);
    final disable = tester.widget<SwitchListTile>(modeEntry).onChanged!;
    disable(false);
    disable(false);
    await tester.pump();

    expect(calls, 1);
    expect(app.enableAsmrSleepMode.value, isTrue);
    expect(tester.widget<SwitchListTile>(modeEntry).onChanged, isNull);

    disableAttempt.completeError(StateError('fixture failure'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(app.enableAsmrSleepMode.value, isTrue);
    expect(find.text('Could not update auto sleep. Try again.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(modeEntry).onChanged, isNotNull);

    tester.widget<SwitchListTile>(modeEntry).onChanged!(false);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(app.enableAsmrSleepMode.value, isFalse);
    expect(tester.widget<SwitchListTile>(modeEntry).onChanged, isNotNull);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR mode commits enable only after permission is granted', (tester) async {
    final app = SettingsService.to.app;
    app.enableAsmrSleepMode.value = false;
    var permissionCalls = 0;

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(420, 800),
      platform: TargetPlatform.android,
      sleepPermissionRequesterOverride: () async {
        permissionCalls++;
        return permissionCalls > 1;
      },
    );

    final modeEntry = find.ancestor(
      of: find.text('Auto-start sleep audio for new rooms'),
      matching: find.byType(SwitchListTile),
    );
    await _scrollPageUntilHitTestable(tester, modeEntry);

    tester.widget<SwitchListTile>(modeEntry).onChanged!(true);
    await tester.pumpAndSettle();
    expect(permissionCalls, 1);
    expect(app.enableAsmrSleepMode.value, isFalse);

    tester.widget<SwitchListTile>(modeEntry).onChanged!(true);
    await tester.pumpAndSettle();
    expect(permissionCalls, 2);
    expect(app.enableAsmrSleepMode.value, isTrue);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('background playback owns one permission transaction and delays preference commit', (tester) async {
    final app = SettingsService.to.app;
    app.enableBackgroundPlay.value = false;
    final permissionAttempt = Completer<bool>();
    final disableAttempt = Completer<void>();
    var permissionCalls = 0;
    var configureCalls = 0;
    final tasks = <Future<void>>[];

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(420, 800),
      platform: TargetPlatform.android,
      sleepPermissionRequesterOverride: () {
        permissionCalls++;
        return permissionAttempt.future;
      },
      backgroundPlaybackConfiguratorOverride: ({required enabled}) {
        configureCalls++;
        expect(enabled, configureCalls <= 2);
        if (configureCalls == 1) throw StateError('fixture failure');
        if (configureCalls == 2) return Future<void>.value();
        return disableAttempt.future;
      },
      backgroundPlaybackTaskObserver: tasks.add,
    );

    final backgroundEntry = find.ancestor(of: find.text('Play Background'), matching: find.byType(SwitchListTile));
    await _scrollPageUntilHitTestable(tester, backgroundEntry);
    final enable = tester.widget<SwitchListTile>(backgroundEntry).onChanged!;
    enable(true);
    enable(true);
    await tester.pump();

    expect(tasks, hasLength(2));
    expect(permissionCalls, 1);
    expect(configureCalls, 0);
    expect(app.enableBackgroundPlay.value, isFalse);
    expect(tester.widget<SwitchListTile>(backgroundEntry).onChanged, isNull);

    permissionAttempt.complete(true);
    await tasks.first;
    await tester.pumpAndSettle();

    expect(permissionCalls, 1);
    expect(configureCalls, 1);
    expect(app.enableBackgroundPlay.value, isFalse);
    expect(find.text('Could not update background playback. Try again.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(backgroundEntry).onChanged, isNotNull);

    tester.widget<SwitchListTile>(backgroundEntry).onChanged!(true);
    expect(tasks, hasLength(3));
    await tasks.last;
    await tester.pumpAndSettle();

    expect(permissionCalls, 2);
    expect(configureCalls, 2);
    expect(app.enableBackgroundPlay.value, isTrue);

    final disable = tester.widget<SwitchListTile>(backgroundEntry).onChanged!;
    disable(false);
    disable(false);
    await tester.pump();

    expect(tasks, hasLength(5));
    expect(configureCalls, 3);
    expect(app.enableBackgroundPlay.value, isTrue);
    expect(tester.widget<SwitchListTile>(backgroundEntry).onChanged, isNull);

    disableAttempt.complete();
    await tasks[3];
    await tester.pumpAndSettle();

    expect(configureCalls, 3);
    expect(app.enableBackgroundPlay.value, isFalse);
    expect(tester.widget<SwitchListTile>(backgroundEntry).onChanged, isNotNull);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);
}

Future<void> _pumpVideoSettings(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  required Size size,
  double textScale = 1,
  required TargetPlatform platform,
  SleepTimerConfigurator? sleepTimerConfiguratorOverride,
  SleepPermissionRequester? sleepPermissionRequesterOverride,
  BackgroundPlaybackConfigurator? backgroundPlaybackConfiguratorOverride,
  ValueChanged<Future<void>>? backgroundPlaybackTaskObserver,
  PipAlwaysOnTopSetter? pipAlwaysOnTopSetterOverride,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Translations(english),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: VideoSettingsPage(
            platformOverride: platform,
            sleepTimerConfiguratorOverride: sleepTimerConfiguratorOverride,
            sleepPermissionRequesterOverride: sleepPermissionRequesterOverride,
            backgroundPlaybackConfiguratorOverride: backgroundPlaybackConfiguratorOverride,
            backgroundPlaybackTaskObserver: backgroundPlaybackTaskObserver,
            pipAlwaysOnTopSetterOverride: pipAlwaysOnTopSetterOverride,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _pageScrollable() {
  return find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
}

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(_pageScrollable());
  for (var attempt = 0; attempt < 30; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final next = position.pixels + position.viewportDimension * 0.75;
    position.jumpTo(next > position.maxScrollExtent ? position.maxScrollExtent : next);
    await tester.pump();
  }
  fail('Target did not become hit-testable after bounded page scrolling.');
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestSettingsService extends SettingsService {
  final AppSettingsController _app = AppSettingsController();
  final DanmakuSettingsController _danmaku = DanmakuSettingsController();
  final FontSettingsController _font = FontSettingsController();
  final PlayerSettingsController _player = PlayerSettingsController();
  final VolumeSettingsController _volume = VolumeSettingsController();
  final WindowSizeController _window = WindowSizeController();

  @override
  AppSettingsController get app => _app;

  @override
  DanmakuSettingsController get danmaku => _danmaku;

  @override
  FontSettingsController get font => _font;

  @override
  PlayerSettingsController get player => _player;

  @override
  VolumeSettingsController get vol => _volume;

  @override
  WindowSizeController get window => _window;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
