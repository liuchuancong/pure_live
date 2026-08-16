import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:pure_live/common/widgets/count_button.dart';
import 'package:pure_live/modules/settings/pages/pip_danmaku_settings_page.dart';
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
    Widget reactiveCard(List<Widget> Function() builder) => Obx(() => context.buildModernCard(builder()));

    return Scaffold(
      body: SingleChildScrollView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            context.buildGroupTitle(i18n('danmaku_templates')),
            const SizedBox(height: 8),
            context.buildModernCard([
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _applyPreset('best'),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(i18n('danmaku_template_best')),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyPreset('comfort'),
                          child: Text(i18n('danmaku_template_comfort')),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyPreset('dense'),
                          child: Text(i18n('danmaku_template_dense')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saveTemplate,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(i18n('save_current_template')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _restoreTemplate,
                          icon: const Icon(Icons.restore_rounded),
                          label: Text(i18n('restore_saved_template')),
                        ),
                        TextButton(onPressed: () => _applyPreset('default'), child: Text(i18n('reset'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${i18n('danmaku_best_preset_desc')}\n${i18n('danmaku_realtime_hint')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("danmaku_area")),
            const SizedBox(height: 8),
            reactiveCard(
              () => [
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
              ],
            ),

            const SizedBox(height: 20),

            context.buildGroupTitle(i18n("position")),
            const SizedBox(height: 8),
            reactiveCard(
              () => [
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
              ],
            ),

            const SizedBox(height: 20),

            context.buildGroupTitle(i18n("style")),
            const SizedBox(height: 8),
            reactiveCard(
              () => [
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
                  display: '${controller.danmakuSpeed.value.toInt()} px/s',
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
                  display: '${controller.danmakuFontSize.value.toStringAsFixed(1)} px',
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
                  max: 4,
                  display: '${controller.danmakuFontBorder.value.toStringAsFixed(1)} px',
                  onChanged: (v) => controller.danmakuFontBorder.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
                _switch(
                  theme,
                  title: '${i18n("danmaku_fps")} · ${i18n("dynamic_follow_display")}',
                  value: SettingsService.to.danmaku.danmakuAutoFps.v,
                  onChanged: (v) => SettingsService.to.danmaku.danmakuAutoFps.v = v,
                  labelColor: labelColor,
                ),
                if (!SettingsService.to.danmaku.danmakuAutoFps.v)
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
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      '${SettingsService.to.danmaku.resolvedDanmakuFps()} FPS',
                      style: TextStyle(color: digitColor, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n('danmaku_screen_interaction')),
            const SizedBox(height: 8),
            reactiveCard(
              () => [
                _switch(
                  theme,
                  title: i18n('danmaku_tap_action'),
                  value: SettingsService.to.danmaku.enableDanmakuTapInteraction.v,
                  onChanged: (v) => SettingsService.to.danmaku.enableDanmakuTapInteraction.v = v,
                  labelColor: labelColor,
                ),
                _switch(
                  theme,
                  title: i18n('danmaku_long_press_action'),
                  value: SettingsService.to.danmaku.enableDanmakuLongPressInteraction.v,
                  onChanged: (v) => SettingsService.to.danmaku.enableDanmakuLongPressInteraction.v = v,
                  labelColor: labelColor,
                ),
              ],
            ),
            const SizedBox(height: 20),

            const PipDanmakuSettingsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _applyPreset(String preset) {
    final values = switch (preset) {
      'best' => const [0.20, 0.0, 0.0, 118.0, 16.0, 1.5, 0.92, 1.0],
      'comfort' => const [0.35, 0.0, 0.0, 105.0, 17.0, 1.5, 0.9, 1.0],
      'dense' => const [0.55, 0.0, 0.0, 138.0, 15.0, 1.2, 0.88, 1.0],
      _ => const [1.0, 0.0, 0.0, 120.0, 16.0, 1.5, 1.0, 1.0],
    };
    controller.danmakuArea.v = values[0];
    controller.danmakuTopArea.v = values[1];
    controller.danmakuBottomArea.v = values[2];
    controller.danmakuSpeed.v = values[3];
    controller.danmakuFontSize.v = values[4];
    controller.danmakuFontBorder.v = values[5];
    controller.danmakuOpacity.v = values[6];
    controller.enableDanmakuStroke.v = values[7] == 1;
    SettingsService.to.danmaku.danmakuAutoFps.v = true;
    ToastUtil.show(i18n('danmaku_template_applied'));
  }

  void _saveTemplate() {
    SettingsService.to.danmaku.savedDanmakuTemplate.v = jsonEncode({
      'area': controller.danmakuArea.v,
      'top': controller.danmakuTopArea.v,
      'bottom': controller.danmakuBottomArea.v,
      'speed': controller.danmakuSpeed.v,
      'fontSize': controller.danmakuFontSize.v,
      'fontBorder': controller.danmakuFontBorder.v,
      'opacity': controller.danmakuOpacity.v,
      'stroke': controller.enableDanmakuStroke.v,
      'fps': controller.danmakuFps.v,
      'autoFps': SettingsService.to.danmaku.danmakuAutoFps.v,
    });
    ToastUtil.show(i18n('danmaku_template_saved'));
  }

  void _restoreTemplate() {
    final raw = SettingsService.to.danmaku.savedDanmakuTemplate.v;
    if (raw.isEmpty) {
      ToastUtil.show(i18n('danmaku_template_empty'));
      return;
    }
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      controller.danmakuArea.v = (value['area'] as num).toDouble();
      controller.danmakuTopArea.v = (value['top'] as num).toDouble();
      controller.danmakuBottomArea.v = (value['bottom'] as num).toDouble();
      controller.danmakuSpeed.v = (value['speed'] as num).toDouble();
      controller.danmakuFontSize.v = (value['fontSize'] as num).toDouble();
      controller.danmakuFontBorder.v = (value['fontBorder'] as num).toDouble();
      controller.danmakuOpacity.v = (value['opacity'] as num).toDouble();
      controller.enableDanmakuStroke.v = value['stroke'] == true;
      controller.danmakuFps.v = (value['fps'] as num?)?.toInt() ?? 60;
      SettingsService.to.danmaku.danmakuAutoFps.v = value['autoFps'] != false;
      ToastUtil.show(i18n('danmaku_template_applied'));
    } catch (_) {
      ToastUtil.show(i18n('danmaku_template_empty'));
    }
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
