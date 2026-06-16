import 'package:pure_live/common/index.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:pure_live/common/widgets/count_button.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class DanmakuSettingsPage extends StatefulWidget {
  const DanmakuSettingsPage({super.key, required this.controller});
  final VideoController controller;

  @override
  State<DanmakuSettingsPage> createState() => _DanmakuSettingsPageState();
}

class _DanmakuSettingsPageState extends State<DanmakuSettingsPage> {
  VideoController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color labelColor = theme.colorScheme.onSurface;
    final Color digitColor = theme.colorScheme.primary;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              context.buildGroupTitle(i18n("danmaku_area")),
              const SizedBox(height: 8),
              context.buildModernCard([
                _slider(
                  theme,
                  title: i18n("danmaku_area"),
                  value: controller.danmakuArea.value,
                  min: 0,
                  max: 1,
                  display: "${(controller.danmakuArea.value * 100).toInt()}%",
                  onChanged: (v) => controller.danmakuArea.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
              ]),

              const SizedBox(height: 20),

              context.buildGroupTitle(i18n("position")),
              const SizedBox(height: 8),
              context.buildModernCard([
                _counter(
                  theme,
                  title: i18n("margin_top"),
                  value: controller.danmakuTopArea.value.toInt(),
                  max: 300,
                  onChanged: (v) => controller.danmakuTopArea.value = v.toDouble(),
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
                _counter(
                  theme,
                  title: i18n("margin_bottom"),
                  value: controller.danmakuBottomArea.value.toInt(),
                  max: 300,
                  onChanged: (v) => controller.danmakuBottomArea.value = v.toDouble(),
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
              ]),

              const SizedBox(height: 20),

              context.buildGroupTitle(i18n("style")),
              const SizedBox(height: 8),
              context.buildModernCard([
                _slider(
                  theme,
                  title: i18n("opacity"),
                  value: controller.danmakuOpacity.value,
                  min: 0,
                  max: 1,
                  display: "${(controller.danmakuOpacity.value * 100).toInt()}%",
                  onChanged: (v) => controller.danmakuOpacity.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
                _slider(
                  theme,
                  title: i18n("speed"),
                  value: controller.danmakuSpeed.value.toDouble(),
                  min: 5,
                  max: 20,
                  display: controller.danmakuSpeed.value.toStringAsFixed(2),
                  onChanged: (v) => controller.danmakuSpeed.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
                _slider(
                  theme,
                  title: i18n("font_size"),
                  value: controller.danmakuFontSize.value.toDouble(),
                  min: 10,
                  max: 30,
                  display: controller.danmakuFontSize.value.toStringAsFixed(2),
                  onChanged: (v) => controller.danmakuFontSize.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
                _switch(
                  theme,
                  title: i18n("danmaku_stroke"),
                  value: controller.enableDanmakuStroke.value,
                  onChanged: (v) => controller.enableDanmakuStroke.value = v,
                  labelColor: labelColor,
                ),
                _slider(
                  theme,
                  title: i18n("stroke"),
                  value: controller.danmakuFontBorder.value.toDouble(),
                  min: 0,
                  max: 8,
                  display: controller.danmakuFontBorder.value.toStringAsFixed(1),
                  onChanged: (v) => controller.danmakuFontBorder.value = v.toInt(),
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
                // ... 前面已有的 opacity, speed, font_size, stroke 等 slider 组件
                _slider(
                  theme,
                  title: i18n("danmaku_fps"),
                  value: controller.danmakuFps.value.toDouble(),
                  min: 30,
                  max: 240,
                  display: "${controller.danmakuFps.value.toInt()} FPS",
                  onChanged: (v) => controller.danmakuFps.value = v.toInt(),
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(
    ThemeData theme, {
    required String title,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
    required Color labelColor,
    required Color digitColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  display,
                  style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold, color: digitColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
    );
  }

  Widget _counter(
    ThemeData theme, {
    required String title,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
    required Color labelColor,
    required Color digitColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
          ),
          CountButton(
            maxValue: max,
            minValue: 0,
            selectedValue: value,
            onChanged: onChanged,
            textStyle: TextStyle(color: digitColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    ThemeData theme, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
          ),
          Switch(value: value, activeThumbColor: theme.colorScheme.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
