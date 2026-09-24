import 'dart:async';

import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecordSettingsPage extends GetView<RecordSettingsController> {
  const RecordSettingsPage({super.key});

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return "${seconds}s";
    } else if (seconds < 3600) {
      final minutes = seconds / 60;
      return "${minutes.toStringAsFixed(minutes.truncateToDouble() == minutes ? 0 : 1)}m";
    } else {
      final hours = seconds / 3600;
      return "${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)}h";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("record_settings"))),
      body: Obx(
        () => ListView(
          physics: const PureLiveScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          children: [
            context.buildGroupTitle(i18n("basic_config")),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.hd_line,
                title: i18n("default_record_quality"),
                subtitle: _resolutionLabel(controller.defaultQuality.value),
                onTap: () => _showQualityDialog(context),
              ),
              context.buildSwitchTile(
                icon: Remix.translate_2,
                title: i18n("use_pinyin_folder"),
                subtitle: i18n("use_pinyin_folder_desc"),
                value: controller.usePinyinForFolder,
              ),
            ]),
            const SizedBox(height: 20),
            _buildCacheHeader(context, theme),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.folder_video_line,
                title: i18n("storage_directory"),
                subtitle: controller.managedRecordPath.value.isEmpty
                    ? controller.recordSavePath.value
                    : controller.managedRecordPath.value,
                trailing: controller.selectingRecordDirectory.value
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: i18n('record_storage_checking'),
                        ),
                      )
                    : null,
                onTap: controller.selectingRecordDirectory.value ? null : controller.pickRecordDir,
              ),
              context.buildSwitchTile(
                icon: Remix.exchange_box_line,
                title: i18n("enable_cache_limit"),
                subtitle: i18n("enable_cache_limit_desc"),
                value: controller.enableCacheLimit,
                onChanged: (value) => unawaited(_updateCacheLimit(value)),
              ),
              if (controller.enableCacheLimit.value)
                context.buildTile(
                  icon: Remix.database_2_line,
                  title: i18n("cache_limit"),
                  subtitle: "${controller.maxCacheMB.value} MB",
                  onTap: () => _showCacheDialog(context),
                ),
              Obx(() {
                final size = controller.cacheSizeMB.value;
                return context.buildTile(
                  icon: Remix.custom_size,
                  title: i18n("current_cache_size"),
                  subtitle: "${size.toStringAsFixed(2)} MB",
                );
              }),
              context.buildTile(
                icon: Remix.delete_bin_4_line,
                title: i18n("clear_all_cache"),
                subtitle: i18n("clear_all_cache_desc"),
                trailing: controller.cacheClearPending.value
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: i18n('clear_all_cache')),
                      )
                    : null,
                onTap: controller.cacheClearPending.value || controller.cacheClearPromptOpen.value
                    ? null
                    : () => _clearCache(context),
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("record_performance_quality")),
            context.buildModernCard([
              context.buildSwitchTile(
                icon: Remix.video_download_line,
                title: i18n("prefer_best_stream"),
                subtitle: i18n("prefer_best_stream_desc"),
                value: controller.preferBestStream,
              ),
              context.buildTile(
                icon: Remix.timer_flash_line,
                title: i18n("rw_timeout"),
                subtitle: "${controller.rwTimeout.value}s",
                onTap: () => _showRwTimeoutDialog(context),
              ),
              context.buildTile(
                icon: Remix.speed_mini_line,
                title: i18n("queue_size"),
                subtitle: "${controller.threadQueueSize.value}",
                onTap: () => _showQueueSizeDialog(context),
              ),
              context.buildSliderTile(
                context,
                icon: Remix.film_line,
                title: i18n("segment_duration"),
                value: controller.segmentTime.value.toDouble(),
                min: RecorderConfig.minSegmentTime.toDouble(),
                max: RecorderConfig.maxSegmentTime.toDouble(),
                displayValue: _formatDuration(controller.segmentTime.value),
                onChanged: (v) => controller.updateSegmentTime(v.toInt()),
              ),
              context.buildTile(
                icon: Remix.task_line,
                title: i18n("max_record_tasks"),
                subtitle: "${controller.maxTaskCount.value}",
                onTap: () => _showMaxTaskDialog(context),
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("auto_reconnect")),
            context.buildModernCard([
              context.buildSwitchTile(
                icon: Remix.refresh_line,
                title: i18n("auto_reconnect_switch"),
                subtitle: i18n("auto_reconnect_desc"),
                value: controller.autoReconnect,
              ),
              if (controller.autoReconnect.value)
                context.buildSliderTile(
                  context,
                  icon: Remix.loop_left_line,
                  title: i18n("max_retry_count"),
                  value: controller.maxRetryCount.value.toDouble(),
                  min: RecorderConfig.minMaxRetryCount.toDouble(),
                  max: RecorderConfig.maxMaxRetryCount.toDouble(),
                  displayValue: "${controller.maxRetryCount.value}",
                  onChanged: (v) => controller.updateMaxRetryCount(v.toInt()),
                ),
              context.buildSliderTile(
                context,
                icon: Remix.time_line,
                title: i18n("retry_delay"),
                value: controller.retryDelay.value.toDouble(),
                min: RecorderConfig.minRetryDelay.toDouble(),
                max: RecorderConfig.maxRetryDelay.toDouble(),
                displayValue: "${controller.retryDelay.value}s",
                onChanged: (v) => controller.updateRetryDelay(v.toInt()),
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("polling_detection")),
            context.buildModernCard([
              context.buildSwitchTile(
                icon: Remix.radar_line,
                title: i18n("enable_polling"),
                subtitle: i18n("enable_polling_desc"),
                value: controller.enablePolling,
              ),
              if (controller.enablePolling.value) ...[
                context.buildSliderTile(
                  context,
                  icon: Remix.time_line,
                  title: i18n("check_interval"),
                  value: controller.liveCheckInterval.value.toDouble(),
                  min: RecorderConfig.minLiveCheckInterval.toDouble(),
                  max: RecorderConfig.maxLiveCheckInterval.toDouble(),
                  displayValue: "${controller.liveCheckInterval.value}s",
                  onChanged: (v) => controller.updateLiveCheckInterval(v.toInt()),
                ),
                context.buildSwitchTile(
                  icon: Remix.line_chart_line,
                  title: i18n("enable_backoff"),
                  subtitle: i18n("enable_backoff_desc"),
                  value: controller.enableBackoff,
                ),
                if (controller.enableBackoff.value)
                  context.buildSliderTile(
                    context,
                    icon: Remix.hourglass_2_line,
                    title: i18n("max_check_interval"),
                    value: controller.maxCheckInterval.value.toDouble(),
                    min: RecorderConfig.minMaxCheckInterval.toDouble(),
                    max: RecorderConfig.maxMaxCheckInterval.toDouble(),
                    displayValue: _formatDuration(controller.maxCheckInterval.value),
                    onChanged: (v) => controller.updateMaxCheckInterval(v.toInt()),
                  ),
              ],
              context.buildSwitchTile(
                icon: Remix.restart_line,
                title: i18n("auto_start_boot"),
                subtitle: i18n("auto_start_boot_desc"),
                value: controller.autoStartOnBoot,
                isLong: true,
              ),
            ]),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    if (controller.cacheClearPending.value || controller.cacheClearPromptOpen.value) return;
    controller.cacheClearPromptOpen.value = true;

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(i18n("confirm_clear_cache"), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(i18n("confirm_clear_cache_desc")),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n("cancel"))),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n("clear"))),
          ],
        ),
      );

      if (!controller.isClosed) controller.cacheClearPromptOpen.value = false;
      if (ok != true || controller.isClosed) return;
      controller.cacheClearPending.value = true;
      await controller.clearCache();
      if (!context.mounted) return;
      Get.snackbar(i18n("done"), i18n("cache_cleared"), snackPosition: SnackPosition.bottom);
    } catch (error) {
      debugPrint('Recorder cache clear failed: $error');
      if (context.mounted) ToastUtil.show(i18n('cache_operation_failed'));
    } finally {
      if (!controller.isClosed) {
        controller.cacheClearPromptOpen.value = false;
        controller.cacheClearPending.value = false;
      }
    }
  }

  Widget _buildCacheHeader(BuildContext context, ThemeData theme) {
    final title = context.buildGroupTitle(i18n("cache_management"));
    final action = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: controller.openRecordDir,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: theme.colorScheme.primary,
        ),
        icon: const Icon(Remix.folder_open_line, size: 18),
        label: Text(i18n("recorder_open_folder"), style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 420 || MediaQuery.textScalerOf(context).scale(14) > 20;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              Align(alignment: Alignment.centerRight, child: action),
              const SizedBox(height: 8),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }

  String _resolutionLabel(String value) {
    final key = PlayerConsts.resolutionLabelKey(value);
    return key == null ? value : i18n(key);
  }

  Future<void> _updateCacheLimit(bool value) async {
    try {
      await controller.updateEnableCacheLimit(value);
    } catch (error) {
      debugPrint('Recorder cache limit update failed: $error');
      ToastUtil.show(i18n('cache_operation_failed'));
    }
  }

  void _showRwTimeoutDialog(BuildContext context) {
    final Map<int, String> timeoutOptions = {
      15: i18n("timeout_fast"),
      30: i18n("timeout_balanced"),
      60: i18n("timeout_safe"),
    };
    _showRadioDialog<int>(
      context: context,
      title: i18n("rw_timeout"),
      selected: controller.rwTimeout.value,
      options: timeoutOptions.entries
          .map((entry) => _RecordOption(value: entry.key, label: '${entry.key}s', description: entry.value))
          .toList(growable: false),
      onSelected: controller.updateRwTimeout,
    );
  }

  void _showQueueSizeDialog(BuildContext context) {
    final queueOptions = RecorderConfig.supportedThreadQueueSizes;
    _showRadioDialog<int>(
      context: context,
      title: i18n("queue_size"),
      selected: controller.threadQueueSize.value,
      options: queueOptions
          .map(
            (value) => _RecordOption(
              value: value,
              label: '$value',
              description: switch (value) {
                <= 512 => i18n("power_saving_mode"),
                1024 => i18n("hd_recommend"),
                2048 => i18n("fhd_recommend"),
                _ => i18n("extreme_performance"),
              },
            ),
          )
          .toList(growable: false),
      onSelected: controller.updateThreadQueueSize,
    );
  }

  void _showMaxTaskDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _RecordIntegerDialog(
        title: i18n("max_record_tasks"),
        fieldKey: 'record-max-tasks',
        initialValue: controller.maxTaskCount.value,
        minimum: RecorderConfig.minMaxTaskCount,
        maximum: RecorderConfig.maxMaxTaskCount,
        hintText: i18n("input_range"),
        errorText: i18n('record_max_tasks_invalid'),
        quickValues: List.generate(
          RecorderConfig.maxMaxTaskCount - RecorderConfig.minMaxTaskCount + 1,
          (index) => RecorderConfig.minMaxTaskCount + index,
        ),
        onSubmitted: controller.updateMaxTask,
      ),
    );
  }

  void _showQualityDialog(BuildContext context) {
    _showRadioDialog<String>(
      context: context,
      title: i18n("default_record_quality"),
      selected: controller.defaultQuality.value,
      options: PlayerConsts.resolutions
          .map((value) => _RecordOption(value: value, label: _resolutionLabel(value)))
          .toList(growable: false),
      onSelected: controller.updateDefaultQuality,
    );
  }

  void _showCacheDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _RecordIntegerDialog(
        title: i18n("set_max_cache"),
        fieldKey: 'record-cache-limit',
        initialValue: controller.maxCacheMB.value,
        minimum: RecorderConfig.minMaxCacheMB,
        hintText: i18n("please_input_number"),
        errorText: i18n('record_cache_limit_invalid'),
        onSubmitted: controller.updateMaxCache,
      ),
    );
  }

  void _showRadioDialog<T>({
    required BuildContext context,
    required String title,
    required T selected,
    required List<_RecordOption<T>> options,
    required Future<void> Function(T) onSelected,
  }) {
    var selectionPending = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          content: RadioGroup<T>(
            groupValue: selected,
            onChanged: (value) async {
              if (value == null || selectionPending) return;
              selectionPending = true;
              try {
                await onSelected(value);
                if (dialogContext.mounted && ModalRoute.of(dialogContext)?.isCurrent == true) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (error) {
                selectionPending = false;
                debugPrint('Recorder setting update failed: $error');
                if (dialogContext.mounted) ToastUtil.show(i18n('record_settings_apply_failed'));
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (option) => RadioListTile<T>(
                      value: option.value,
                      activeColor: theme.colorScheme.primary,
                      selected: option.value == selected,
                      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(option.label, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: option.description == null ? null : Text(option.description!, style: AppTextStyles.t12),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }
}

class _RecordOption<T> {
  const _RecordOption({required this.value, required this.label, this.description});

  final T value;
  final String label;
  final String? description;
}

class _RecordIntegerDialog extends StatefulWidget {
  const _RecordIntegerDialog({
    required this.title,
    required this.fieldKey,
    required this.initialValue,
    required this.minimum,
    required this.hintText,
    required this.errorText,
    required this.onSubmitted,
    this.maximum,
    this.quickValues = const <int>[],
  });

  final String title;
  final String fieldKey;
  final int initialValue;
  final int minimum;
  final int? maximum;
  final String hintText;
  final String errorText;
  final Future<void> Function(int) onSubmitted;
  final List<int> quickValues;

  @override
  State<_RecordIntegerDialog> createState() => _RecordIntegerDialogState();
}

class _RecordIntegerDialogState extends State<_RecordIntegerDialog> {
  late final TextEditingController _controller;
  bool _invalid = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _parse(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < widget.minimum) return null;
    final maximum = widget.maximum;
    if (maximum != null && parsed > maximum) return null;
    return parsed;
  }

  void _validate(String value) {
    final invalid = _parse(value) == null;
    if (invalid != _invalid) setState(() => _invalid = invalid);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final value = _parse(_controller.text);
    if (value == null) {
      if (!_invalid) setState(() => _invalid = true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmitted(value);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('${widget.fieldKey}-input'),
            controller: _controller,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.t18,
            decoration: InputDecoration(
              labelText: i18n("manual_input"),
              hintText: widget.hintText,
              errorText: _invalid ? widget.errorText : null,
              errorMaxLines: 3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            onChanged: _validate,
            onSubmitted: (_) => _submit(),
          ),
          if (widget.quickValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(i18n("quick_select"), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.quickValues
                  .map(
                    (value) => ChoiceChip(
                      label: Text('$value'),
                      selected: int.tryParse(_controller.text) == value,
                      onSelected: _submitting
                          ? null
                          : (_) {
                              _controller.text = '$value';
                              setState(() => _invalid = false);
                            },
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: Text(i18n("cancel"))),
        FilledButton(onPressed: _submitting ? null : _submit, child: Text(i18n("confirm"))),
      ],
    );
  }
}
