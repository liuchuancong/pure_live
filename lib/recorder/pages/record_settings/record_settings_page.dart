import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecordSettingsPage extends GetView<RecordSettingsController> {
  const RecordSettingsPage({super.key});

  bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(i18n("record_settings")), centerTitle: true, elevation: 0),
      body: Obx(
        () => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader(i18n("basic_config")),
            context.buildModernCard([
              _buildTile(
                theme,
                Icons.high_quality_rounded,
                i18n("default_record_quality"),
                controller.defaultQuality.value,
                _showQualityDialog,
              ),
              _buildSwitchTile(
                Icons.translate_rounded,
                i18n("use_pinyin_folder"),
                i18n("use_pinyin_folder_desc"),
                controller.usePinyinForFolder.value,
                (val) => controller.updateUsePinyinForFolder(val),
              ),
            ]),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(i18n("cache_management")),
                Padding(
                  padding: EdgeInsetsGeometry.only(right: 8),
                  child: TextButton.icon(
                    onPressed: () => FileUtils.openFileOrUrl(controller.recordSavePath.value),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: theme.colorScheme.primary, // 保持主题色
                    ),
                    icon: const Icon(Remix.folder_open_line, size: 18),
                    label: Text(
                      i18n("recorder_open_folder"),
                      style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),

            context.buildModernCard([
              _buildTile(
                theme,
                Icons.folder_rounded,
                i18n("storage_directory"),
                controller.recordSavePath.value,
                controller.pickRecordDir,
                isLong: true,
              ),

              _buildSwitchTile(
                Icons.all_inbox_rounded,
                i18n("enable_cache_limit"),
                i18n("enable_cache_limit_desc"),
                controller.enableCacheLimit.value,
                controller.updateEnableCacheLimit,
              ),

              if (controller.enableCacheLimit.value)
                _buildTile(
                  theme,
                  Icons.storage_rounded,
                  i18n("cache_limit"),
                  "${controller.maxCacheMB.value} MB",
                  _showCacheDialog,
                ),

              Obx(() {
                final size = controller.cacheSizeMB.value;

                return _buildTile(
                  theme,
                  Icons.sd_storage_rounded,
                  i18n("current_cache_size"),
                  "${size.toStringAsFixed(2)} MB",
                  () {},
                  showRightRounded: false,
                );
              }),

              _buildTile(
                theme,
                Icons.cleaning_services_rounded,
                i18n("clear_all_cache"),
                i18n("clear_all_cache_desc"),
                () async {
                  final ok = await Get.dialog<bool>(
                    AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: Text(i18n("confirm_clear_cache"), style: const TextStyle(fontWeight: FontWeight.bold)),
                      content: Text(i18n("confirm_clear_cache_desc")),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(Get.context!).pop(false), child: Text(i18n("cancel"))),
                        ElevatedButton(
                          onPressed: () => Navigator.of(Get.context!).pop(true),
                          child: Text(i18n("clear")),
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    await controller.clearCache();

                    Get.snackbar(i18n("done"), i18n("cache_cleared"), snackPosition: SnackPosition.bottom);
                  }
                },
              ),
            ]),

            _buildSectionHeader(i18n("record_performance_quality")),
            context.buildModernCard([
              _buildSwitchTile(
                Icons.hd_rounded,
                i18n("prefer_best_stream"),
                i18n("prefer_best_stream_desc"),
                controller.preferBestStream.value,
                controller.updatePreferBestStream,
              ),

              _buildTile(
                theme,
                Icons.timer_outlined,
                i18n("rw_timeout"),
                "${controller.rwTimeout.value}s",
                _showRwTimeoutDialog,
              ),

              _buildTile(
                theme,
                Icons.speed_rounded,
                i18n("queue_size"),
                "${controller.threadQueueSize.value}",
                _showQueueSizeDialog,
              ),

              _buildSliderTile(
                theme,
                icon: Icons.video_settings_rounded,
                title: i18n("segment_duration"),
                value: controller.segmentTime.value.toDouble(),
                min: 60,
                max: 3600,
                displayValue: _formatDuration(controller.segmentTime.value),
                onChanged: (v) => controller.updateSegmentTime(v.toInt()),
              ),

              _buildTile(
                theme,
                Icons.task_alt_rounded,
                i18n("max_record_tasks"),
                "${controller.maxTaskCount.value}",
                _showMaxTaskDialog,
              ),
            ]),

            _buildSectionHeader(i18n("auto_reconnect")),
            context.buildModernCard([
              _buildSwitchTile(
                Icons.refresh_rounded,
                i18n("auto_reconnect_switch"),
                i18n("auto_reconnect_desc"),
                controller.autoReconnect.value,
                controller.updateAutoReconnect,
              ),

              if (controller.autoReconnect.value)
                _buildSliderTile(
                  theme,
                  icon: Icons.repeat_rounded,
                  title: i18n("max_retry_count"),
                  value: controller.maxRetryCount.value.toDouble(),
                  min: 1,
                  max: 20,
                  displayValue: "${controller.maxRetryCount.value}",
                  onChanged: (v) => controller.updateMaxRetryCount(v.toInt()),
                ),

              _buildSliderTile(
                theme,
                icon: Icons.timer_rounded,
                title: i18n("retry_delay"),
                value: controller.retryDelay.value.toDouble(),
                min: 5,
                max: 120,
                displayValue: "${controller.retryDelay.value}s",
                onChanged: (v) => controller.updateRetryDelay(v.toInt()),
              ),
            ]),

            _buildSectionHeader(i18n("polling_detection")),
            context.buildModernCard([
              _buildSwitchTile(
                Icons.radar_rounded,
                i18n("enable_polling"),
                i18n("enable_polling_desc"),
                controller.enablePolling.value,
                controller.updateEnablePolling,
              ),

              if (controller.enablePolling.value) ...[
                _buildSliderTile(
                  theme,
                  icon: Icons.schedule_rounded,
                  title: i18n("check_interval"),
                  value: controller.liveCheckInterval.value.toDouble(),
                  min: 10,
                  max: 300,
                  displayValue: "${controller.liveCheckInterval.value}s",
                  onChanged: (v) => controller.updateLiveCheckInterval(v.toInt()),
                ),

                _buildSwitchTile(
                  Icons.trending_up_rounded,
                  i18n("enable_backoff"),
                  i18n("enable_backoff_desc"),
                  controller.enableBackoff.value,
                  controller.updateEnableBackoff,
                ),

                if (controller.enableBackoff.value)
                  _buildSliderTile(
                    theme,
                    icon: Icons.hourglass_bottom_rounded,
                    title: i18n("max_check_interval"),
                    value: controller.maxCheckInterval.value.toDouble(),
                    min: 300,
                    max: 3600,
                    displayValue: _formatDuration(controller.maxCheckInterval.value),
                    onChanged: (v) => controller.updateMaxCheckInterval(v.toInt()),
                  ),

                _buildSwitchTile(
                  Icons.power_settings_new_rounded,
                  i18n("auto_start_boot"),
                  i18n("auto_start_boot_desc"),
                  controller.autoStartOnBoot.value,
                  controller.updateAutoStartOnBoot,
                ),
              ],
            ]),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, top: 24),
      child: Text(
        title,
        style: AppTextStyles.t15.copyWith(
          fontWeight: FontWeight.bold,
          color: Get.theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTile(
    ThemeData theme,
    IconData icon,
    String title,
    String val,
    VoidCallback onTap, {
    bool isLong = false,
    bool showRightRounded = true,
  }) {
    bool compat = Get.width >= 680;
    return ListTile(
      leading: Icon(icon, size: 24, color: theme.colorScheme.primary),
      title: Text(title, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: compat ? 400 : 100),
            child: Text(
              val,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          showRightRounded ? const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.grey) : const SizedBox(),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSliderTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Icon(icon, size: 24, color: theme.colorScheme.primary)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayValue,
                        style: AppTextStyles.t13.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: SfSlider(
                      min: min,
                      max: max,
                      value: value,
                      activeColor: theme.colorScheme.primary,
                      inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      onChanged: (dynamic v) => onChanged(v as double),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String sub, bool val, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      secondary: Icon(icon, size: 24, color: Get.theme.colorScheme.primary),
      title: Text(title, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: AppTextStyles.t13.copyWith(color: Colors.grey)),
      activeThumbColor: Get.theme.colorScheme.primary,
      value: val,
      onChanged: onChanged,
    );
  }

  void _showRwTimeoutDialog() {
    final theme = Get.theme;

    final Map<int, String> timeoutOptions = {
      15: i18n("timeout_fast"),
      30: i18n("timeout_balanced"),
      60: i18n("timeout_safe"),
    };

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(i18n("rw_timeout"), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: RadioGroup<int>(
          groupValue: controller.rwTimeout.value,
          onChanged: (v) {
            if (v != null) {
              controller.updateRwTimeout(v);
            }

            Navigator.pop(Get.context!);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: timeoutOptions.entries.map((entry) {
              return RadioListTile<int>(
                title: Text("${entry.key}s", style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(entry.value, style: AppTextStyles.t12),
                value: entry.key,
                activeColor: theme.colorScheme.primary,
                selected: controller.rwTimeout.value == entry.key,
                selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showQueueSizeDialog() {
    final theme = Get.theme;

    final List<int> queueOptions = [512, 1024, 2048, 4096, 8192];

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(i18n("queue_size"), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: RadioGroup<int>(
          groupValue: controller.threadQueueSize.value,
          onChanged: (v) {
            if (v != null) {
              controller.updateThreadQueueSize(v);
            }

            Navigator.pop(Get.context!);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: queueOptions.map((value) {
              String subTitle = "";

              if (value <= 512) {
                subTitle = i18n("power_saving_mode");
              } else if (value == 1024) {
                subTitle = i18n("hd_recommend");
              } else if (value == 2048) {
                subTitle = i18n("fhd_recommend");
              } else {
                subTitle = i18n("extreme_performance");
              }

              return RadioListTile<int>(
                title: Text("$value", style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(subTitle, style: AppTextStyles.t12),
                value: value,
                activeColor: theme.colorScheme.primary,
                selected: controller.threadQueueSize.value == value,
                selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showMaxTaskDialog() {
    final theme = Get.theme;

    final textController = TextEditingController(text: controller.maxTaskCount.value.toString());

    final options = List.generate(10, (i) => i + 1);

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(i18n("max_record_tasks"), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n("manual_input"),
                    hintText: i18n("input_range"),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(i18n("quick_select"), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((v) {
                      final selected = int.tryParse(textController.text) == v;

                      return ChoiceChip(
                        label: Text("$v"),
                        selected: selected,
                        onSelected: (_) {
                          textController.text = "$v";
                          setState(() {});
                        },
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(Get.context!).pop(), child: Text(i18n("cancel"))),
              ElevatedButton(
                onPressed: () {
                  final val = int.tryParse(textController.text);

                  if (val == null || val < 1) return;

                  controller.updateMaxTask(val);

                  Navigator.of(Get.context!).pop();
                },
                child: Text(i18n("confirm")),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQualityDialog() {
    final theme = Get.theme;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(i18n("default_record_quality"), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: RadioGroup<String>(
          groupValue: controller.defaultQuality.value,
          onChanged: (v) {
            if (v != null) {
              controller.updateDefaultQuality(v);
            }

            Navigator.pop(Get.context!);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlayerConsts.resolutions.map((e) {
              return RadioListTile<String>(
                title: Text(e, style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w500)),
                value: e,
                activeColor: theme.colorScheme.primary,
                selected: controller.defaultQuality.value == e,
                selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.05),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showCacheDialog() {
    final textController = TextEditingController(text: controller.maxCacheMB.value.toString());

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(i18n("set_max_cache"), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          style: AppTextStyles.t18,
          decoration: InputDecoration(
            hintText: i18n("please_input_number"),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Get.theme.colorScheme.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(Get.context!),
            child: Text(i18n("cancel"), style: AppTextStyles.t16),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(textController.text);

              if (val != null) {
                controller.updateMaxCache(val);
              }

              Navigator.pop(Get.context!);
            },
            child: Text(i18n("confirm"), style: AppTextStyles.t16),
          ),
        ],
      ),
    );
  }
}
