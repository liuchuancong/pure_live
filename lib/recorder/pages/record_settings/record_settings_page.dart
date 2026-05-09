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
    if (seconds < 60) return "${seconds}s";
    final minutes = seconds ~/ 60;
    if (minutes < 60) return "${minutes}m";
    final hours = minutes / 60;
    return "${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)}h";
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
          padding: EdgeInsets.all(20),
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
              _buildTile(
                theme,
                Icons.folder_rounded,
                "存储目录",
                controller.recordSavePath.value,
                controller.pickRecordDir,
                isLong: true,
              ),
              _buildTile(theme, Icons.storage_rounded, "缓存限制", "${controller.maxCacheMB.value} MB", _showCacheDialog),
            ]),

            _buildSectionHeader("录制性能"),
            _buildModernCard(theme, [
              _buildSliderTile(
                theme,
                title: "最大并发任务",
                value: controller.maxTaskCount.value.toDouble(),
                min: 1,
                max: 10,
                displayValue: "${controller.maxTaskCount.value}",
                onChanged: (v) => controller.updateMaxTask(v.toInt()),
              ),
              _buildSliderTile(
                theme,
                title: "视频切片时长",
                value: controller.segmentTime.value.toDouble(),
                min: 60,
                max: 43200,
                displayValue: _formatDuration(controller.segmentTime.value),
                onChanged: (v) => controller.updateSegmentTime(v.toInt()),
              ),
            ]),

            _buildSectionHeader("自动检测与重连"),
            _buildModernCard(theme, [
              _buildSwitchTile("自动断线重连", "录制异常时尝试恢复", controller.autoReconnect.value, controller.updateAutoReconnect),
              if (controller.autoReconnect.value)
                _buildSliderTile(
                  theme,
                  title: "重连间隔时间",
                  value: controller.retryDelay.value.toDouble(),
                  min: 5,
                  max: 120,
                  displayValue: "${controller.retryDelay.value}s",
                  onChanged: (v) => controller.updateRetryDelay(v.toInt()),
                ),
              _buildSwitchTile("启用挂机检测", "主播未开播时自动轮询", controller.enablePolling.value, controller.updateEnablePolling),
              _buildSliderTile(
                theme,
                title: "初始检测间隔",
                value: controller.liveCheckInterval.value.toDouble(),
                min: 10,
                max: 300,
                displayValue: "${controller.liveCheckInterval.value}s",
                onChanged: (v) => controller.updateLiveCheckInterval(v.toInt()),
              ),
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
          fontSize: 15, // Larger font
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
  }) {
    return ListTile(
      leading: Icon(icon, size: 24, color: theme.colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), // Larger font
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: isDesktop ? 400 : 150),
            child: Text(
              val,
              style: TextStyle(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSliderTile(
    ThemeData theme, {
    required String title,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), // Larger font
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          SfSlider(
            min: min,
            max: max,
            value: value,
            activeColor: theme.colorScheme.primary, // Force Primary Color
            inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            onChanged: (dynamic v) => onChanged(v as double),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String sub, bool val, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), // Larger font
      subtitle: Text(sub, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      activeThumbColor: Get.theme.colorScheme.primary, // Selection Color
      value: val,
      onChanged: onChanged,
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
            if (v != null) controller.updateDefaultQuality(v);
            Navigator.pop(Get.context!);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlayerConsts.resolutions
                .map(
                  (e) => RadioListTile<String>(
                    title: Text(e, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    value: e,
                    activeColor: theme.colorScheme.primary, // Fixed Gray Color Issue
                    selected: controller.defaultQuality.value == e,
                    selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                  ),
                )
                .toList(),
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
              if (val != null) controller.updateMaxCache(val);
              Navigator.pop(Get.context!);
            },
            child: const Text("确定", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
