import 'dart:math' as math;

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
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            i18n('pip_danmaku_desc'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n('pip_danmaku_preview')),
          const SizedBox(height: 8),
          const PipDanmakuPreview(),
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
              _switch(
                theme,
                title: '${i18n('danmaku_fps')} · ${i18n('dynamic_follow_display')}',
                value: settings.pipDanmakuAutoFps.v,
                onChanged: (value) => settings.pipDanmakuAutoFps.v = value,
                labelColor: labelColor,
              ),
              if (!settings.pipDanmakuAutoFps.v)
                _slider(
                  theme,
                  title: i18n('danmaku_fps'),
                  value: settings.pipDanmakuFps.v.toDouble(),
                  min: 15,
                  max: 240,
                  display: '${settings.pipDanmakuFps.v} FPS',
                  onChanged: (value) => settings.pipDanmakuFps.v = value.toInt(),
                  labelColor: labelColor,
                  digitColor: digitColor,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${settings.resolvedDanmakuFps(pip: true)} FPS',
                    style: TextStyle(color: digitColor, fontWeight: FontWeight.w600),
                  ),
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
                onChanged: (dynamic nextValue) => onChanged((nextValue as num).toDouble()),
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

class PipDanmakuPreview extends StatefulWidget {
  const PipDanmakuPreview({super.key});

  @override
  State<PipDanmakuPreview> createState() => _PipDanmakuPreviewState();
}

class _PipDanmakuPreviewState extends State<PipDanmakuPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = SettingsService.to.danmaku;
      // Read every Rx value directly in the Obx callback. Values read only in
      // LayoutBuilder/AnimatedBuilder execute after dependency collection and
      // therefore do not trigger a preview rebuild when the slider changes.
      final enabled = settings.enablePipDanmaku.v;
      final autoScale = settings.pipDanmakuAutoScale.v;
      final useOriginalColor = settings.pipDanmakuUseOriginalColor.v;
      final unifiedColor = Color(settings.pipDanmakuColor.v);
      final configuredFontSize = settings.pipDanmakuFontSize.v;
      final speed = settings.pipDanmakuSpeed.v;
      final opacity = enabled ? settings.pipDanmakuOpacity.v : 0.25;
      final area = settings.pipDanmakuArea.v;
      final maxVisibleCount = settings.pipDanmakuMaxVisibleCount.v;
      final emitInterval = settings.pipDanmakuEmitInterval.v;
      final fps = settings.resolvedDanmakuFps(pip: true);
      final colors = useOriginalColor
          ? const [Color(0xFFFFFFFF), Color(0xFF64B5F6), Color(0xFFFFD54F), Color(0xFF81C784)]
          : [unifiedColor];

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
                  final scale = autoScale ? (constraints.maxWidth / 350).clamp(0.65, 1.0).toDouble() : 1.0;
                  final fontSize = configuredFontSize * scale;
                  final areaHeight = constraints.maxHeight * area;
                  final previewText = i18n('pip_danmaku_preview_text');
                  final painters = List<TextPainter>.generate(
                    maxVisibleCount.clamp(1, 20).toInt(),
                    (index) => TextPainter(
                      text: TextSpan(
                        text: '$previewText ${index + 1}',
                        style: TextStyle(
                          color: colors[index % colors.length].withValues(alpha: opacity),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0.5, 0.5))],
                        ),
                      ),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout(),
                  );

                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: areaHeight,
                        child: ClipRect(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final frame = (_controller.value * 12 * fps).floor();
                              final quantizedProgress = frame / (12 * fps);
                              return CustomPaint(
                                size: Size(constraints.maxWidth, areaHeight),
                                painter: _PipDanmakuPreviewPainter(
                                  progress: quantizedProgress,
                                  painters: painters,
                                  fontSize: fontSize,
                                  speed: speed,
                                  emitInterval: emitInterval,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (!enabled)
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

class _PipDanmakuPreviewPainter extends CustomPainter {
  const _PipDanmakuPreviewPainter({
    required this.progress,
    required this.painters,
    required this.fontSize,
    required this.speed,
    required this.emitInterval,
  });

  final double progress;
  final List<TextPainter> painters;
  final double fontSize;
  final double speed;
  final double emitInterval;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final laneHeight = math.max(fontSize * 1.55, 18.0);
    final laneCount = math.max(1, (size.height / laneHeight).floor());
    final elapsedSeconds = progress * 12;

    for (var index = 0; index < painters.length; index++) {
      final painter = painters[index];
      final travel = size.width + painter.width + 24;
      final phaseDistance = index * math.max(speed * emitInterval, painter.width * 0.7);
      final travelled = elapsedSeconds * speed + phaseDistance;
      final x = size.width - (travelled % travel);
      final y = (index % laneCount) * laneHeight + math.max(0, (laneHeight - painter.height) / 2);
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _PipDanmakuPreviewPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.painters != painters ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.speed != speed ||
        oldDelegate.emitInterval != emitInterval;
  }
}
