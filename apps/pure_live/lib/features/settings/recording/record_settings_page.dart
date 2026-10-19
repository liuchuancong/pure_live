import 'dart:async';
import 'dart:io' show Directory;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:pure_live/features/recorder/record_storage_cleaner.dart';
import 'package:pure_live/features/recorder/recorder_preferences.dart';
import 'package:pure_live/features/recorder/recorder_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The recording settings page — the reference's `RecordSettingsPage`
/// (`features/record_settings/record_settings_page.dart`), group for group:
/// 录制默认 (quality, folder naming, the saved chat), 录制文件 (directory,
/// size cap, used space, clear), 性能与画质 (stream mapping, FFmpeg timeouts
/// and queue, segment length, concurrent tasks), 自动重连, 开播检测.
///
/// Every row writes a [RecorderPreferences] field the recording engine reads
/// as it works: the policy object and the naming style are rewritten live,
/// the FFmpeg trio is read at each capture's opening, and the quality line
/// is honoured when the room's address is resolved. A capture that is
/// already running keeps the config it opened with — the same next-open
/// semantics the player's tuning row spells out.
final class RecordSettingsPage extends ConsumerStatefulWidget {
  /// The recording settings page.
  const new({super.key});

  @override
  ConsumerState<RecordSettingsPage> createState() => _RecordSettingsPageState();
}

class _RecordSettingsPageState extends ConsumerState<RecordSettingsPage> {
  double? _sizeMB;
  bool _measuring = false;
  bool _clearing = false;
  bool _choosingDirectory = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStorage());
  }

  Future<void> _write(RecorderPreferences Function(RecorderPreferences preferences) transform) =>
      updateRecorderPreferences(() => ref.read(recorderPreferencesStoreProvider.future), transform);

  /// The managed folder and its size (3.x `refreshStorageInfo`).
  Future<void> _refreshStorage() async {
    if (_measuring) {
      return;
    }
    setState(() => _measuring = true);
    double? size;
    try {
      final root = await ref.read(recorderRootProvider.future);
      size = await RecordStorage.usedBytes(root) / (1024 * 1024);
    } on Object {
      size = null;
    }
    if (mounted) {
      setState(() {
        _sizeMB = size;
        _measuring = false;
      });
    }
  }

  Future<void> _clearAll() async {
    if (_clearing) {
      return;
    }
    setState(() => _clearing = true);
    final t = context.t;
    final root = await ref.read(recorderRootProvider.future);
    final freed = await RecordStorage.clearAll(root: root);
    if (mounted) {
      setState(() => _clearing = false);
      PureToast.show(
        context,
        t.recorder.clearFreed(mb: (freed / (1024 * 1024)).toStringAsFixed(1)),
        type: PureToastType.success,
      );
    }
    await _refreshStorage();
  }

  Future<void> _chooseDirectory(RecorderPreferences preferences) async {
    if (_choosingDirectory) {
      return;
    }
    setState(() => _choosingDirectory = true);
    final t = context.t;
    final current = preferences.outputDirectory;
    try {
      final selected = await FilePickerPlatform.instance.getDirectoryPath(
        dialogTitle: t.recorder.chooseDirectory,
        initialDirectory: current.isEmpty ? null : current,
      );
      if (selected != null && selected != current) {
        await _write((value) => value.copyWith(outputDirectory: selected));
      }
    } finally {
      if (mounted) {
        setState(() => _choosingDirectory = false);
      }
    }
  }

  Future<void> _openFolder(String root) async {
    final t = context.t;
    try {
      final result = await OpenFile.open(root.isEmpty ? Directory.systemTemp.path : root);
      if (result.type != ResultType.done && mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, t.recorder.folderNotOpened, type: PureToastType.error);
      }
    }
  }

  Future<void> _choose<T>(
    BuildContext context, {
    required String title,
    required T current,
    required List<(T, String)> options,
    required Future<void> Function(T value) apply,
  }) async {
    final picked = await showSettingsChooser<T>(context, title: title, current: current, options: options);
    if (picked != null) {
      await apply(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final preferences = ref.watch(recorderPreferencesProvider).value ?? RecorderPreferences();
    final root = ref.watch(recorderRootProvider).value ?? preferences.outputDirectory;

    return SettingsChrome(
      title: t.settings.recordingTitle,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.recorder.groupDefaults),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('record-quality'),
                leading: const Icon(Icons.high_quality_outlined),
                title: Text(t.recorder.defaultQuality),
                description: Text(t.recorder.defaultQualityDesc),
                value: Text(preferences.defaultQuality),
                onPressed: (_) => unawaited(
                  _choose<String>(
                    context,
                    title: t.recorder.defaultQuality,
                    current: preferences.defaultQuality,
                    options: [for (final quality in recordQualityChoices) (quality, quality)],
                    apply: (value) => _write((p) => p.copyWith(defaultQuality: value)),
                  ),
                ),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('record-pinyin'),
                leading: const Icon(Icons.abc_outlined),
                title: Text(t.recorder.usePinyinFolder),
                description: Text(t.recorder.usePinyinFolderDesc),
                initialValue: preferences.pinyinFolders,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(pinyinFolders: value))),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('record-danmaku'),
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(t.recorder.recordDanmaku),
                description: Text(t.recorder.recordDanmakuDesc),
                initialValue: preferences.recordDanmaku,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(recordDanmaku: value))),
              ),
              // H01.8: always on hand — the chat file gains gift and super
              // chat entries while it is being saved at all.
              SettingsTile.switchTile(
                key: const ValueKey('record-danmaku-gifts'),
                leading: const Icon(Icons.card_giftcard_outlined),
                title: Text(t.recorder.recordDanmakuGifts),
                description: Text(t.recorder.recordDanmakuGiftsDesc),
                initialValue: preferences.recordDanmakuGifts,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(recordDanmakuGifts: value))),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.recorder.groupFiles),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('record-directory'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(t.recorder.outputDirectory),
                description: Text(root.isEmpty ? t.recorder.outputDirectoryDefault : root),
                enabled: !_choosingDirectory,
                trailing: PureIconButton(
                  key: const ValueKey('record-open-folder'),
                  icon: Icons.folder_open_outlined,
                  tooltip: t.recorder.openFolder,
                  onPressed: () => unawaited(_openFolder(root)),
                ),
                onPressed: (_) => unawaited(_chooseDirectory(preferences)),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('record-size-limit'),
                leading: const Icon(Icons.data_usage_outlined),
                title: Text(t.recorder.recordSizeLimit),
                description: Text(t.recorder.recordSizeLimitDesc),
                initialValue: preferences.enableCacheLimit,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(enableCacheLimit: value))),
              ),
              SettingsTile.navigation(
                key: const ValueKey('record-size-cap'),
                leading: const Icon(Icons.straighten_outlined),
                title: Text(t.recorder.recordSizeCap),
                value: Text(t.recorder.mbValue(count: preferences.maxCacheMB)),
                enabled: preferences.enableCacheLimit,
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    title: t.recorder.recordSizeCap,
                    current: preferences.maxCacheMB,
                    options: [
                      for (final mb in const [512, 1024, 2048, 4096, 8192, 16384, 32768]) (
                        mb,
                        t.recorder.mbValue(count: mb),
                      ),
                    ],
                    apply: (value) => _write((p) => p.copyWith(maxCacheMB: value)),
                  ),
                ),
              ),
              SettingsTile(
                key: const ValueKey('record-used-space'),
                leading: Icon(_measuring ? Icons.autorenew_outlined : Icons.storage_outlined),
                title: Text(t.recorder.recordUsedSpace),
                description: Text(t.recorder.recordUsedSpaceDesc),
                trailing: _measuring
                    ? const PureSpinner()
                    : Text(
                        _sizeMB == null ? '--' : t.recorder.mbValue(count: _sizeMB!.toStringAsFixed(1)),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                onPressed: (_) => unawaited(_refreshStorage()),
              ),
              SettingsTile(
                key: const ValueKey('record-clear'),
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(t.recorder.clearAllCache),
                description: Text(t.recorder.clearAllCacheDesc),
                trailing: _clearing ? const PureSpinner() : null,
                onPressed: _clearing ? null : (_) => unawaited(_clearAll()),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.recorder.groupPerformance),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('record-best-stream'),
                leading: const Icon(Icons.layers_outlined),
                title: Text(t.recorder.preferBestStream),
                description: Text(t.recorder.preferBestStreamDesc),
                initialValue: preferences.preferBestStream,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(preferBestStream: value))),
              ),
              SettingsTile.navigation(
                key: const ValueKey('record-timeout'),
                leading: const Icon(Icons.timer_outlined),
                title: Text(t.recorder.rwTimeout),
                description: Text(t.recorder.rwTimeoutDesc),
                value: Text(t.recorder.secondsValue(count: preferences.rwTimeout)),
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    title: t.recorder.rwTimeout,
                    current: preferences.rwTimeout,
                    options: [
                      for (final seconds in RecorderPreferences.supportedRwTimeouts) (
                        seconds,
                        t.recorder.secondsValue(count: seconds),
                      ),
                    ],
                    apply: (value) => _write((p) => p.copyWith(rwTimeout: value)),
                  ),
                ),
              ),
              SettingsTile.navigation(
                key: const ValueKey('record-queue'),
                leading: const Icon(Icons.view_agenda_outlined),
                title: Text(t.recorder.queueSize),
                description: Text(t.recorder.queueSizeDesc),
                value: Text('${preferences.threadQueueSize}'),
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    title: t.recorder.queueSize,
                    current: preferences.threadQueueSize,
                    options: [for (final size in RecorderPreferences.supportedThreadQueueSizes) (size, '$size')],
                    apply: (value) => _write((p) => p.copyWith(threadQueueSize: value)),
                  ),
                ),
              ),
              _sliderTile(
                key: 'record-segment',
                icon: Icons.content_cut_outlined,
                title: t.recorder.segmentLength,
                description: t.recorder.segmentLengthDesc,
                value: preferences.segmentMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                label: t.recorder.minutesValue(minutes: preferences.segmentMinutes),
                onChanged: (minutes) =>
                    unawaited(_write((p) => p.copyWith(segmentMinutes: minutes.round().clamp(1, 60)))),
              ),
              _counterTile(
                key: 'record-max-tasks',
                icon: Icons.playlist_play_outlined,
                title: t.recorder.maxRecordTasks,
                description: t.recorder.maxRecordTasksDesc,
                value: preferences.maxTaskCount,
                min: 1,
                max: 10,
                onChanged: (value) => unawaited(_write((p) => p.copyWith(maxTaskCount: value))),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.recorder.groupReconnect),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('record-reconnect'),
                leading: const Icon(Icons.refresh_outlined),
                title: Text(t.recorder.autoReconnectSwitch),
                description: Text(t.recorder.autoReconnectDesc),
                initialValue: preferences.autoReconnect,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(autoReconnect: value))),
              ),
              _sliderTile(
                key: 'record-retries',
                icon: Icons.replay_outlined,
                title: t.recorder.maxRetryCount,
                value: preferences.maxRetryCount.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                enabled: preferences.autoReconnect,
                label: t.recorder.timesValue(count: preferences.maxRetryCount),
                onChanged: (value) =>
                    unawaited(_write((p) => p.copyWith(maxRetryCount: value.round().clamp(1, 20)))),
              ),
              _sliderTile(
                key: 'record-retry-delay',
                icon: Icons.hourglass_bottom_outlined,
                title: t.recorder.retryDelay,
                value: preferences.retryDelaySeconds.toDouble(),
                min: 5,
                max: 120,
                divisions: 115,
                enabled: preferences.autoReconnect,
                label: t.recorder.secondsValue(count: preferences.retryDelaySeconds),
                onChanged: (value) =>
                    unawaited(_write((p) => p.copyWith(retryDelaySeconds: value.round().clamp(5, 120)))),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.recorder.groupLiveCheck),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('record-polling'),
                leading: const Icon(Icons.radar_outlined),
                title: Text(t.recorder.enablePolling),
                description: Text(t.recorder.enablePollingDesc),
                initialValue: preferences.enablePolling,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(enablePolling: value))),
              ),
              _sliderTile(
                key: 'record-check-interval',
                icon: Icons.timelapse_outlined,
                title: t.recorder.checkInterval,
                value: preferences.liveCheckInterval.toDouble(),
                min: 10,
                max: 300,
                divisions: 29,
                enabled: preferences.enablePolling,
                label: t.recorder.secondsValue(count: preferences.liveCheckInterval),
                onChanged: (value) =>
                    unawaited(_write((p) => p.copyWith(liveCheckInterval: value.round().clamp(10, 300)))),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('record-backoff'),
                leading: const Icon(Icons.trending_up_outlined),
                title: Text(t.recorder.enableBackoff),
                description: Text(t.recorder.enableBackoffDesc),
                initialValue: preferences.enableBackoff,
                enabled: preferences.enablePolling,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(enableBackoff: value))),
              ),
              _sliderTile(
                key: 'record-max-check-interval',
                icon: Icons.vertical_align_bottom_outlined,
                title: t.recorder.maxCheckInterval,
                value: preferences.maxCheckInterval / 60,
                min: 5,
                max: 60,
                divisions: 55,
                enabled: preferences.enablePolling && preferences.enableBackoff,
                label: t.recorder.minutesValue(minutes: (preferences.maxCheckInterval / 60).round()),
                onChanged: (minutes) => unawaited(
                  _write((p) => p.copyWith(maxCheckInterval: (minutes.round() * 60).clamp(300, 3600))),
                ),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('record-auto-start-boot'),
                leading: const Icon(Icons.power_outlined),
                title: Text(t.recorder.autoStartBoot),
                description: Text(t.recorder.autoStartBootDesc),
                initialValue: preferences.autoStartOnBoot,
                onToggle: (value) => unawaited(_write((p) => p.copyWith(autoStartOnBoot: value))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A tile whose control is a slider beside the title (the reference's
  /// `_SliderSetting`); a disabled row greys out rather than vanishing. The
  /// kit's own [PureSlider], not a Material one — these pages render under
  /// every design language, and a bare `Slider` asserts where there is no
  /// Material ancestor.
  SettingsTile _sliderTile({
    required String key,
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
    String? description,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return SettingsTile(
      key: ValueKey(key),
      leading: Icon(icon),
      title: Text(title),
      description: description == null ? null : Text(description),
      value: Text(label, style: theme.textTheme.bodyMedium),
      enabled: enabled,
      trailing: SizedBox(
        width: 160,
        child: PureSlider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          enabled: enabled,
          // The reference's stepped slider: quantise on the way out so the
          // stored answer always lands on one of its `divisions` steps.
          onChanged: (next) {
            final step = (max - min) / divisions;
            onChanged((min + ((next - min) / step).roundToDouble() * step).clamp(min, max));
          },
        ),
      ),
    );
  }

  /// A −/+ counter tile (the reference's `SettingsCounterRow` for the task
  /// cap).
  SettingsTile _counterTile({
    required String key,
    required IconData icon,
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    String? description,
  }) {
    final t = context.t;
    return SettingsTile(
      key: ValueKey(key),
      leading: Icon(icon),
      title: Text(title),
      description: description == null ? null : Text(description),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PureIconButton(
            key: ValueKey('$key-decrease'),
            icon: Icons.remove_circle_outline,
            tooltip: t.recorder.decrease,
            size: ControlSize.sm,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ),
          PureIconButton(
            key: ValueKey('$key-increase'),
            icon: Icons.add_circle_outline,
            tooltip: t.recorder.increase,
            size: ControlSize.sm,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
