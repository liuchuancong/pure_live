import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
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
      appBar: AppBar(title: Text(i18n("record_settings")), centerTitle: true, elevation: 0),
      body: Obx(
        () => ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
          children: [
            _buildSectionHeader(i18n("basic_config")),
            context.buildModernCard([
              context.buildTile(
                icon: Icons.high_quality_rounded,
                title: i18n("default_record_quality"),
                subtitle: controller.defaultQuality.value,
                onTap: _showQualityDialog,
              ),

              context.buildSwitchTile(
                icon: Icons.translate_rounded,
                title: i18n("use_pinyin_folder"),
                subtitle: i18n("use_pinyin_folder_desc"),
                value: controller.usePinyinForFolder,
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
              context.buildTile(
                icon: Icons.folder_rounded,
                title: i18n("storage_directory"),
                subtitle: controller.recordSavePath.value,
                onTap: controller.pickRecordDir,
              ),

              context.buildSwitchTile(
                icon: Icons.all_inbox_rounded,
                title: i18n("enable_cache_limit"),
                subtitle: i18n("enable_cache_limit_desc"),
                value: controller.enableCacheLimit,
              ),

              if (controller.enableCacheLimit.value)
                context.buildTile(
                  icon: Icons.storage_rounded,
                  title: i18n("cache_limit"),
                  subtitle: "${controller.maxCacheMB.value} MB",
                  onTap: _showCacheDialog,
                ),

              Obx(() {
                final size = controller.cacheSizeMB.value;

                return context.buildTile(
                  icon: Icons.sd_storage_rounded,
                  title: i18n("current_cache_size"),
                  subtitle: "${size.toStringAsFixed(2)} MB",
                );
              }),

              context.buildTile(
                icon: Icons.cleaning_services_rounded,
                title: i18n("clear_all_cache"),
                subtitle: i18n("clear_all_cache_desc"),
                onTap: () async {
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
              context.buildSwitchTile(
                icon: Icons.hd_rounded,
                title: i18n("prefer_best_stream"),
                subtitle: i18n("prefer_best_stream_desc"),
                value: controller.preferBestStream,
              ),

              context.buildTile(
                icon: Icons.timer_outlined,
                title: i18n("rw_timeout"),
                subtitle: "${controller.rwTimeout.value}s",
                onTap: _showRwTimeoutDialog,
              ),

              context.buildTile(
                icon: Icons.speed_rounded,
                title: i18n("queue_size"),
                subtitle: "${controller.threadQueueSize.value}",
                onTap: _showQueueSizeDialog,
              ),

              context.buildSliderTile(
                context,
                icon: Icons.video_settings_rounded,
                title: i18n("segment_duration"),
                value: controller.segmentTime.value.toDouble(),
                min: 60,
                max: 3600,
                displayValue: _formatDuration(controller.segmentTime.value),
                onChanged: (v) => controller.updateSegmentTime(v.toInt()),
              ),

              context.buildTile(
                icon: Icons.task_alt_rounded,
                title: i18n("max_record_tasks"),
                subtitle: "${controller.maxTaskCount.value}",
                onTap: _showMaxTaskDialog,
              ),
            ]),

            _buildSectionHeader(i18n("auto_reconnect")),
            context.buildModernCard([
              context.buildSwitchTile(
                icon: Icons.refresh_rounded,
                title: i18n("auto_reconnect_switch"),
                subtitle: i18n("auto_reconnect_desc"),
                value: controller.autoReconnect,
              ),

              if (controller.autoReconnect.value)
                context.buildSliderTile(
                  context,
                  icon: Icons.repeat_rounded,
                  title: i18n("max_retry_count"),
                  value: controller.maxRetryCount.value.toDouble(),
                  min: 1,
                  max: 20,
                  displayValue: "${controller.maxRetryCount.value}",
                  onChanged: (v) => controller.updateMaxRetryCount(v.toInt()),
                ),

              context.buildSliderTile(
                context,
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
              context.buildSwitchTile(
                icon: Icons.radar_rounded,
                title: i18n("enable_polling"),
                subtitle: i18n("enable_polling_desc"),
                value: controller.enablePolling,
              ),

              if (controller.enablePolling.value) ...[
                context.buildSliderTile(
                  context,
                  icon: Icons.schedule_rounded,
                  title: i18n("check_interval"),
                  value: controller.liveCheckInterval.value.toDouble(),
                  min: 10,
                  max: 300,
                  displayValue: "${controller.liveCheckInterval.value}s",
                  onChanged: (v) => controller.updateLiveCheckInterval(v.toInt()),
                ),

                context.buildSwitchTile(
                  icon: Icons.trending_up_rounded,
                  title: i18n("enable_backoff"),
                  subtitle: i18n("enable_backoff_desc"),
                  value: controller.enableBackoff,
                ),

                if (controller.enableBackoff.value)
                  context.buildSliderTile(
                    context,
                    icon: Icons.hourglass_bottom_rounded,
                    title: i18n("max_check_interval"),
                    value: controller.maxCheckInterval.value.toDouble(),
                    min: 300,
                    max: 3600,
                    displayValue: _formatDuration(controller.maxCheckInterval.value),
                    onChanged: (v) => controller.updateMaxCheckInterval(v.toInt()),
                  ),

                context.buildSwitchTile(
                  icon: Icons.power_settings_new_rounded,
                  title: i18n("auto_start_boot"),
                  subtitle: i18n("auto_start_boot_desc"),
                  value: controller.autoStartOnBoot,
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
