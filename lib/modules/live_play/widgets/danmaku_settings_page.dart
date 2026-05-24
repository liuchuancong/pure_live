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
        padding: const EdgeInsets.all(16),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(theme, i18n("danmaku_area")),
              _card(theme, [
                _slider(
                  theme,
                  title: i18n("danmaku_area"),
                  value: controller.danmakuArea.value,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  display: "${(controller.danmakuArea.value * 100).toInt()}%",
                  onChanged: (v) => controller.danmakuArea.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
              ]),

              const SizedBox(height: 12),

              _section(theme, i18n("position")),
              _card(theme, [
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

              const SizedBox(height: 12),

              _section(theme, i18n("style")),
              _card(theme, [
                _slider(
                  theme,
                  title: i18n("opacity"),
                  value: controller.danmakuOpacity.value,
                  min: 0,
                  max: 1,
                  divisions: 10,
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
                  divisions: 15,
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
                  divisions: 20,
                  display: controller.danmakuFontSize.value.toStringAsFixed(2),
                  onChanged: (v) => controller.danmakuFontSize.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),

                _slider(
                  theme,
                  title: i18n("stroke"),
                  value: controller.danmakuFontBorder.value.toDouble(),
                  min: 0,
                  max: 8,
                  divisions: 8,
                  display: controller.danmakuFontBorder.value.toStringAsFixed(1),
                  onChanged: (v) => controller.danmakuFontBorder.value = v,
                  labelColor: labelColor,
                  digitColor: digitColor,
                ),
              ]),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 0),
      child: Text(
        title,
        style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _card(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.canvasColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _slider(
    ThemeData theme, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
    required Color labelColor,
    required Color digitColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  display,
                  style: AppTextStyles.t13.copyWith(fontWeight: FontWeight.bold, color: digitColor),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            textStyle: TextStyle(color: digitColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
