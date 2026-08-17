import 'package:pure_live/common/index.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
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
                _switch(
                  theme,
                  title: i18n("danmaku_no_emoji"),
                  value: SettingsService.to.danmaku.noEmojiMode.v,
                  onChanged: (v) => SettingsService.to.danmaku.noEmojiMode.v = v,
                  labelColor: labelColor,
                ),
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
                  min: 20,
                  max: 400,
                  display: controller.danmakuSpeed.value.toInt().toString(),
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
              const SizedBox(height: 20),

              context.buildGroupTitle(i18n("pip_danmaku")),
              const SizedBox(height: 8),
              context.buildModernCard([
                _switch(
                  theme,
                  title: i18n("pip_danmaku_enable"),
                  value: SettingsService.to.danmaku.enablePipDanmaku.v,
                  onChanged: (v) => SettingsService.to.danmaku.enablePipDanmaku.v = v,
                  labelColor: labelColor,
                ),
                if (SettingsService.to.danmaku.enablePipDanmaku.v) ...[
                  _switch(
                    theme,
                    title: i18n("danmaku_no_emoji"),
                    value: SettingsService.to.danmaku.pipDanmaNoEmojiMode.v,
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmaNoEmojiMode.v = v,
                    labelColor: labelColor,
                  ),
                  _switch(
                    theme,
                    title: i18n("pip_danmaku_auto_scale"),
                    value: SettingsService.to.danmaku.pipDanmakuAutoScale.v,
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuAutoScale.v = v,
                    labelColor: labelColor,
                  ),
                  _switch(
                    theme,
                    title: i18n("pip_danmaku_original_color"),
                    value: SettingsService.to.danmaku.pipDanmakuUseOriginalColor.v,
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuUseOriginalColor.v = v,
                    labelColor: labelColor,
                  ),
                  if (!SettingsService.to.danmaku.pipDanmakuUseOriginalColor.v)
                    _colorPickerRow(labelColor: labelColor, digitColor: digitColor),
                  _slider(
                    theme,
                    title: i18n("font_size"),
                    value: SettingsService.to.danmaku.pipDanmakuFontSize.v,
                    min: 8,
                    max: 24,
                    display: SettingsService.to.danmaku.pipDanmakuFontSize.v.toStringAsFixed(1),
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuFontSize.v = v,
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                  _slider(
                    theme,
                    title: i18n("speed"),
                    value: SettingsService.to.danmaku.pipDanmakuSpeed.v,
                    min: 20,
                    max: 400,
                    display: SettingsService.to.danmaku.pipDanmakuSpeed.v.toStringAsFixed(0),
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuSpeed.v = v,
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                  _slider(
                    theme,
                    title: i18n("opacity"),
                    value: SettingsService.to.danmaku.pipDanmakuOpacity.v,
                    min: 0.1,
                    max: 1,
                    display: "${(SettingsService.to.danmaku.pipDanmakuOpacity.v * 100).toInt()}%",
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuOpacity.v = v,
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                  _slider(
                    theme,
                    title: i18n("danmaku_area"),
                    value: SettingsService.to.danmaku.pipDanmakuArea.v,
                    min: 0.1,
                    max: 1,
                    display: "${(SettingsService.to.danmaku.pipDanmakuArea.v * 100).toInt()}%",
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuArea.v = v,
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                  _counter(
                    theme,
                    title: i18n("pip_danmaku_max_visible"),
                    value: SettingsService.to.danmaku.pipDanmakuMaxVisibleCount.v,
                    min: 1,
                    max: 20,
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuMaxVisibleCount.v = v,
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                  _slider(
                    theme,
                    title: i18n("pip_danmaku_interval"),
                    value: SettingsService.to.danmaku.pipDanmakuEmitInterval.v,
                    min: 0.05,
                    max: 2,
                    display: "${SettingsService.to.danmaku.pipDanmakuEmitInterval.v.toStringAsFixed(2)}s",
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuEmitInterval.v = v,
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                  _slider(
                    theme,
                    title: i18n("danmaku_fps"),
                    value: SettingsService.to.danmaku.pipDanmakuFps.v.toDouble(),
                    min: 15,
                    max: 60,
                    display: "${SettingsService.to.danmaku.pipDanmakuFps.v} FPS",
                    onChanged: (v) => SettingsService.to.danmaku.pipDanmakuFps.v = v.toInt(),
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                ],
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
    int min = 0,
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
            minValue: min,
            selectedValue: value,
            onChanged: onChanged,
            textStyle: TextStyle(color: digitColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _colorPickerRow({required Color labelColor, required Color digitColor}) {
    final color = Color(SettingsService.to.danmaku.pipDanmakuColor.v);
    return InkWell(
      onTap: () => _showPipColorPicker(color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              i18n("pip_danmaku_color"),
              style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
            ),
            Row(
              children: [
                ColorIndicator(width: 28, height: 28, borderRadius: 14, color: color),
                const SizedBox(width: 8),
                Text(
                  '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                  style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold, color: digitColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPipColorPicker(Color initialColor) async {
    final confirmed = await ColorPicker(
      color: initialColor,
      onColorChanged: (color) => SettingsService.to.danmaku.pipDanmakuColor.v = color.toARGB32(),
      enableOpacity: false,
      showColorCode: true,
      showColorName: false,
      showMaterialName: false,
      pickersEnabled: const {
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: true,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(context);
    if (!confirmed) {
      SettingsService.to.danmaku.pipDanmakuColor.v = initialColor.toARGB32();
    }
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
