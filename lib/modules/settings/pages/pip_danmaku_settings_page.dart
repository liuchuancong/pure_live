import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/count_button.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class PipDanmakuSettingsPage extends StatelessWidget {
  const PipDanmakuSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('pip_danmaku')),
        actions: [
          IconButton(
            tooltip: i18n('pip_danmaku_reset'),
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            i18n('pip_danmaku_desc'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('pip_danmaku_preview')),
          const SizedBox(height: 8),
          const _PipDanmakuPreview(),
          const SizedBox(height: 20),
          const PipDanmakuSettingsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('pip_danmaku_reset')),
        content: Text(i18n('pip_danmaku_reset_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('reset'))),
        ],
      ),
    );
    if (confirmed == true) {
      SettingsService.to.danmaku.resetPipDanmaku();
    }
  }
}

class PipDanmakuSettingsSection extends StatelessWidget {
  const PipDanmakuSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.colorScheme.onSurface;
    final digitColor = theme.colorScheme.primary;

    return Obx(() {
      final settings = SettingsService.to.danmaku;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          context.buildGroupTitle(i18n('pip_danmaku')),
          const SizedBox(height: 8),
          context.buildModernCard([
            _switch(
              theme,
              title: i18n('pip_danmaku_enable'),
              value: settings.enablePipDanmaku.v,
              onChanged: (value) => settings.enablePipDanmaku.v = value,
              labelColor: labelColor,
            ),
            if (settings.enablePipDanmaku.v) ...[
              _switch(
                theme,
                title: i18n('pip_danmaku_auto_scale'),
                value: settings.pipDanmakuAutoScale.v,
                onChanged: (value) => settings.pipDanmakuAutoScale.v = value,
                labelColor: labelColor,
              ),
              _switch(
                theme,
                title: i18n('pip_danmaku_original_color'),
                value: settings.pipDanmakuUseOriginalColor.v,
                onChanged: (value) => settings.pipDanmakuUseOriginalColor.v = value,
                labelColor: labelColor,
              ),
              if (!settings.pipDanmakuUseOriginalColor.v)
                _colorPickerRow(context, labelColor: labelColor, digitColor: digitColor),
              _slider(
                theme,
                title: i18n('font_size'),
                value: settings.pipDanmakuFontSize.v,
                min: 8,
                max: 24,
                display: settings.pipDanmakuFontSize.v.toStringAsFixed(1),
                onChanged: (value) => settings.pipDanmakuFontSize.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _slider(
                theme,
                title: i18n('speed'),
                value: settings.pipDanmakuSpeed.v,
                min: 20,
                max: 400,
                display: settings.pipDanmakuSpeed.v.toStringAsFixed(0),
                onChanged: (value) => settings.pipDanmakuSpeed.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _slider(
                theme,
                title: i18n('opacity'),
                value: settings.pipDanmakuOpacity.v,
                min: 0.1,
                max: 1,
                display: '${(settings.pipDanmakuOpacity.v * 100).toInt()}%',
                onChanged: (value) => settings.pipDanmakuOpacity.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _slider(
                theme,
                title: i18n('danmaku_area'),
                value: settings.pipDanmakuArea.v,
                min: 0.1,
                max: 1,
                display: '${(settings.pipDanmakuArea.v * 100).toInt()}%',
                onChanged: (value) => settings.pipDanmakuArea.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _counter(
                theme,
                title: i18n('pip_danmaku_max_visible'),
                value: settings.pipDanmakuMaxVisibleCount.v,
                min: 1,
                max: 20,
                onChanged: (value) => settings.pipDanmakuMaxVisibleCount.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _slider(
                theme,
                title: i18n('pip_danmaku_interval'),
                value: settings.pipDanmakuEmitInterval.v,
                min: 0.05,
                max: 2,
                display: '${settings.pipDanmakuEmitInterval.v.toStringAsFixed(2)}s',
                onChanged: (value) => settings.pipDanmakuEmitInterval.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _slider(
                theme,
                title: i18n('danmaku_fps'),
                value: settings.pipDanmakuFps.v.toDouble(),
                min: 15,
                max: 60,
                display: '${settings.pipDanmakuFps.v} FPS',
                onChanged: (value) => settings.pipDanmakuFps.v = value.toInt(),
                labelColor: labelColor,
                digitColor: digitColor,
              ),
            ],
          ]),
        ],
      );
    });
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
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
                ),
              ),
              const SizedBox(width: 12),
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
                onChanged: (dynamic nextValue) => onChanged(nextValue as double),
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
    required int min,
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
          Flexible(
            child: Text(
              title,
              style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
            ),
          ),
          const SizedBox(width: 12),
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
          Flexible(
            child: Text(
              title,
              style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, activeThumbColor: theme.colorScheme.primary, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _colorPickerRow(BuildContext context, {required Color labelColor, required Color digitColor}) {
    final color = Color(SettingsService.to.danmaku.pipDanmakuColor.v);
    return InkWell(
      onTap: () => _showColorPicker(context, color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                i18n('pip_danmaku_color'),
                style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
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

  Future<void> _showColorPicker(BuildContext context, Color initialColor) async {
    final confirmed = await ColorPicker(
      color: initialColor,
      onColorChanged: (color) {
        SettingsService.to.danmaku.pipDanmakuColor.v = color.toARGB32();
      },
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
}

class _PipDanmakuPreview extends StatelessWidget {
  const _PipDanmakuPreview();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      final unifiedColor = Color(settings.pipDanmakuColor.v);
      final colors = settings.pipDanmakuUseOriginalColor.v
          ? const [Color(0xFFFFFFFF), Color(0xFF64B5F6), Color(0xFFFFD54F)]
          : [unifiedColor, unifiedColor, unifiedColor];
      final opacity = settings.enablePipDanmaku.v ? settings.pipDanmakuOpacity.v : 0.25;

      return RepaintBoundary(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172033), Color(0xFF090B10)],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = settings.pipDanmakuAutoScale.v
                      ? (constraints.maxWidth / 350).clamp(0.65, 1.0).toDouble()
                      : 1.0;
                  final fontSize = settings.pipDanmakuFontSize.v * scale;
                  final areaHeight = constraints.maxHeight * settings.pipDanmakuArea.v;

                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: areaHeight,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              for (var index = 0; index < colors.length; index++)
                                Positioned(
                                  left: 18.0 + index * 42,
                                  top: 12.0 + index * (fontSize * 1.8),
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Text(
                                      '${i18n('pip_danmaku_preview_text')} ${index + 1}',
                                      style: TextStyle(
                                        color: colors[index],
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w600,
                                        shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (!settings.enablePipDanmaku.v)
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Text(i18n('pip_danmaku_disabled'), style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}
