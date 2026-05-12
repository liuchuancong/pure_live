import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
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
      appBar: AppBar(
        title: const Text("录制设置", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(
        () => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader("基础配置"),
            _buildModernCard(theme, [
              _buildTile(
                theme,
                Icons.high_quality_rounded,
                "默认录制清晰度",
                controller.defaultQuality.value,
                _showQualityDialog,
              ),

              _buildSwitchTile(
                Icons.translate_rounded,
                "使用拼音文件夹名",
                "开启后使用主播拼音命名录制文件夹，关闭则使用主播原名",
                controller.usePinyinForFolder.value,
                (val) => controller.updateUsePinyinForFolder(val),
              ),
            ]),

            _buildSectionHeader("缓存管理"),
            _buildModernCard(theme, [
              _buildTile(
                theme,
                Icons.folder_rounded,
                "存储目录",
                controller.recordSavePath.value,
                controller.pickRecordDir,
                isLong: true,
              ),

              _buildSwitchTile(
                Icons.all_inbox_rounded,
                "启用缓存限制",
                "超过限制后自动清理旧录制",
                controller.enableCacheLimit.value,
                controller.updateEnableCacheLimit,
              ),

              if (controller.enableCacheLimit.value)
                _buildTile(theme, Icons.storage_rounded, "缓存限制", "${controller.maxCacheMB.value} MB", _showCacheDialog),

              Obx(() {
                final size = controller.cacheSizeMB.value;

                return _buildTile(
                  theme,
                  Icons.sd_storage_rounded,
                  "当前缓存大小",
                  "${size.toStringAsFixed(2)} MB",
                  () {},
                  showRightRounded: false,
                );
              }),

              _buildTile(theme, Icons.cleaning_services_rounded, "清除全部缓存", "删除录制缓存文件", () async {
                final ok = await Get.dialog<bool>(
                  AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: const Text("确认清除缓存？", style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text("该操作会删除所有录制缓存文件，无法恢复。"),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(Get.context!).pop(false), child: const Text("取消")),
                      ElevatedButton(onPressed: () => Navigator.of(Get.context!).pop(true), child: const Text("清除")),
                    ],
                  ),
                );

                if (ok == true) {
                  await controller.clearCache();

                  Get.snackbar("清理完成", "缓存已清除", snackPosition: SnackPosition.bottom);
                }
              }),
            ]),

            _buildSectionHeader("录制性能与画质"),
            _buildModernCard(theme, [
              _buildSwitchTile(
                Icons.hd_rounded,
                "优先录制原画轨道",
                "强制选择最高清晰度流 (0:v:0)",
                controller.preferBestStream.value,
                controller.updatePreferBestStream,
              ),

              _buildTile(theme, Icons.timer_outlined, "录制读写超时", "${controller.rwTimeout.value}s", _showRwTimeoutDialog),

              _buildTile(
                theme,
                Icons.speed_rounded,
                "输入缓冲队列",
                "${controller.threadQueueSize.value}",
                _showQueueSizeDialog,
              ),

              _buildSliderTile(
                theme,
                icon: Icons.video_settings_rounded,
                title: "视频切片时长",
                value: controller.segmentTime.value.toDouble(),
                min: 60,
                max: 3600,
                displayValue: _formatDuration(controller.segmentTime.value),
                onChanged: (v) => controller.updateSegmentTime(v.toInt()),
              ),
            ]),

            _buildSectionHeader("自动重连"),
            _buildModernCard(theme, [
              _buildSwitchTile(
                Icons.refresh_rounded,
                "自动断线重连",
                "录制异常时尝试恢复",
                controller.autoReconnect.value,
                controller.updateAutoReconnect,
              ),

              if (controller.autoReconnect.value)
                _buildSliderTile(
                  theme,
                  icon: Icons.repeat_rounded,
                  title: "最大重试次数",
                  value: controller.maxRetryCount.value.toDouble(),
                  min: 1,
                  max: 20,
                  displayValue: "${controller.maxRetryCount.value}次",
                  onChanged: (v) => controller.updateMaxRetryCount(v.toInt()),
                ),

              _buildSliderTile(
                theme,
                icon: Icons.timer_rounded,
                title: "重连间隔时间",
                value: controller.retryDelay.value.toDouble(),
                min: 5,
                max: 120,
                displayValue: "${controller.retryDelay.value}s",
                onChanged: (v) => controller.updateRetryDelay(v.toInt()),
              ),
            ]),

            _buildSectionHeader("挂机轮询检测"),
            _buildModernCard(theme, [
              _buildSwitchTile(
                Icons.radar_rounded,
                "启用开播检测",
                "主播未开播时自动轮询",
                controller.enablePolling.value,
                controller.updateEnablePolling,
              ),

              if (controller.enablePolling.value) ...[
                _buildSliderTile(
                  theme,
                  icon: Icons.schedule_rounded,
                  title: "检测间隔时间",
                  value: controller.liveCheckInterval.value.toDouble(),
                  min: 10,
                  max: 300,
                  displayValue: "${controller.liveCheckInterval.value}s",
                  onChanged: (v) => controller.updateLiveCheckInterval(v.toInt()),
                ),

                _buildSwitchTile(
                  Icons.trending_up_rounded,
                  "启用指数退避",
                  "失败次数越多，检测间隔越长",
                  controller.enableBackoff.value,
                  controller.updateEnableBackoff,
                ),

                if (controller.enableBackoff.value)
                  _buildSliderTile(
                    theme,
                    icon: Icons.hourglass_bottom_rounded,
                    title: "最大检测间隔",
                    value: controller.maxCheckInterval.value.toDouble(),
                    min: 300,
                    max: 3600,
                    displayValue: _formatDuration(controller.maxCheckInterval.value),
                    onChanged: (v) => controller.updateMaxCheckInterval(v.toInt()),
                  ),

                _buildSwitchTile(
                  Icons.power_settings_new_rounded,
                  "开机自动检测",
                  "应用开机后继续检测",
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
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Get.theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernCard(ThemeData theme, List<Widget> children) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(children: children),
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
    return ListTile(
      leading: Icon(icon, size: 24, color: theme.colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: isDesktop ? 400 : 150),
            child: Text(
              val,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayValue,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
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
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      activeThumbColor: Get.theme.colorScheme.primary,
      value: val,
      onChanged: onChanged,
    );
  }

  void _showRwTimeoutDialog() {
    final theme = Get.theme;

    final Map<int, String> timeoutOptions = {15: "响应迅速 (推荐，适合稳定网络)", 30: "平衡模式 (兼顾稳定与重连速度)", 60: "保守模式 (适合极端弱网环境)"};

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("录制读写超时", style: TextStyle(fontWeight: FontWeight.bold)),
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
                title: Text("${entry.key}s", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text(entry.value, style: const TextStyle(fontSize: 12)),
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
        title: const Text("输入缓冲队列", style: TextStyle(fontWeight: FontWeight.bold)),
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
                subTitle = "省电模式";
              } else if (value == 1024) {
                subTitle = "标清/高清推荐";
              } else if (value == 2048) {
                subTitle = "原画推荐 (1080P)";
              } else {
                subTitle = "极致性能 (适用于 4K 录制/高负载环境)";
              }

              return RadioListTile<int>(
                title: Text("$value", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text(subTitle, style: const TextStyle(fontSize: 12)),
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

  void _showQualityDialog() {
    final theme = Get.theme;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("默认录制清晰度", style: TextStyle(fontWeight: FontWeight.bold)),
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
                title: Text(e, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
        title: const Text("设置最大缓存 (MB)", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: "请输入数字",
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
            child: const Text("取消", style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(textController.text);

              if (val != null) {
                controller.updateMaxCache(val);
              }

              Navigator.pop(Get.context!);
            },
            child: const Text("确定", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
