import 'dart:math' as math;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/utils/compact_danmaku_metrics.dart';
import 'package:pure_live/modules/settings/widgets/app_color_picker_dialog.dart';
import 'package:pure_live/core/consts/app_consts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/core/widgets/count_button.dart';
import 'package:flame_barrage/flame_barrage.dart';

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 840) {
            return _DesktopPipDanmakuLayout(maxPreviewWidth: math.min(520, constraints.maxWidth * 0.43));
          }
          return _MobilePipDanmakuLayout(availableHeight: constraints.maxHeight, availableWidth: constraints.maxWidth);
        },
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

/// Keeps the preview visible while the long settings pane scrolls. On a phone
/// this is a compact top panel; on desktop/tablet the same idea becomes a
/// two-column editor.
class _MobilePipDanmakuLayout extends StatelessWidget {
  const _MobilePipDanmakuLayout({required this.availableHeight, required this.availableWidth});

  final double availableHeight;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final naturalHeight = math.max(0, availableWidth - 32) * 9 / 16;
    final previewHeight = math.min(naturalHeight, math.max(96.0, availableHeight * 0.31)).toDouble();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            i18n('pip_danmaku_desc'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            key: const ValueKey('pip-danmaku-preview-pane'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              context.buildGroupTitle(i18n('pip_danmaku_preview')),
              const SizedBox(height: 6),
              SizedBox(
                height: previewHeight,
                width: double.infinity,
                child: const Center(child: PipDanmakuPreview()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            key: const ValueKey('pip-danmaku-settings-scroll'),
            physics: const PureLiveScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: const [PipDanmakuSettingsSection()],
          ),
        ),
      ],
    );
  }
}

class _DesktopPipDanmakuLayout extends StatelessWidget {
  const _DesktopPipDanmakuLayout({required this.maxPreviewWidth});

  final double maxPreviewWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: maxPreviewWidth,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                i18n('pip_danmaku_desc'),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              context.buildGroupTitle(i18n('pip_danmaku_preview')),
              const SizedBox(height: 8),
              const PipDanmakuPreview(key: ValueKey('pip-danmaku-preview-pane')),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListView(
            key: const ValueKey('pip-danmaku-settings-scroll'),
            physics: const PureLiveScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: const [PipDanmakuSettingsSection(), SizedBox(height: 24)],
          ),
        ),
      ],
    );
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
                title: i18n('danmaku_no_emoji'),
                value: settings.pipDanmakuNoEmojiMode.v,
                onChanged: (value) => settings.pipDanmakuNoEmojiMode.v = value,
                labelColor: labelColor,
              ),
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
                semanticValueBuilder: (value) => value.toStringAsFixed(1),
                onChanged: (value) => settings.pipDanmakuFontSize.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _slider(
                theme,
                title: i18n("font_weight"),
                value: settings.pipDanmakuFontWeight.value.toDouble(),
                min: 100,
                max: 900,
                stepSize: 100,
                display: i18n(AppConsts.fontWeightLabels[settings.pipDanmakuFontWeight.value] ?? 'font_weight_normal'),
                semanticValueBuilder: (value) =>
                    i18n(AppConsts.fontWeightLabels[value.round()] ?? 'font_weight_normal'),
                onChanged: (v) {
                  settings.pipDanmakuFontWeight.value = v.round();
                },
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
                semanticValueBuilder: (value) => value.toStringAsFixed(0),
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
                semanticValueBuilder: (value) => '${(value * 100).toInt()}%',
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
                semanticValueBuilder: (value) => '${(value * 100).toInt()}%',
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
                semanticValueBuilder: (value) => '${value.toStringAsFixed(2)}s',
                onChanged: (value) => settings.pipDanmakuEmitInterval.v = value,
                labelColor: labelColor,
                digitColor: digitColor,
              ),
              _switch(
                theme,
                title: '${i18n('danmaku_fps')} · ${i18n('dynamic_follow_display')}',
                subtitle: i18n('pip_danmaku_fps_policy_desc'),
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
                  semanticValueBuilder: (value) => '${value.toInt()} FPS',
                  onChanged: (value) => settings.pipDanmakuFps.v = value.toInt(),
                  labelColor: labelColor,
                  digitColor: digitColor,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${settings.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode)} FPS',
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
    required String Function(double value) semanticValueBuilder,
    required ValueChanged<double> onChanged,
    required Color labelColor,
    required Color digitColor,
    double? stepSize,
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
                stepSize: stepSize,
                value: value,
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                semanticFormatterCallback: (dynamic semanticValue) =>
                    '$title, ${semanticValueBuilder((semanticValue as num).toDouble())}',
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
            semanticLabel: title,
            decrementSemanticLabel: i18n('decrease_value', args: {'label': title}),
            incrementSemanticLabel: i18n('increase_value', args: {'label': title}),
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
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color labelColor,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        title,
        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
      ),
      subtitle: subtitle == null ? null : Text(subtitle, style: theme.textTheme.bodySmall),
      value: value,
      activeThumbColor: theme.colorScheme.primary,
      onChanged: onChanged,
    );
  }

  Widget _colorPickerRow(BuildContext context, {required Color labelColor, required Color digitColor}) {
    final color = Color(SettingsService.to.danmaku.pipDanmakuColor.v);
    final colorText = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return Semantics(
      button: true,
      label: '${i18n('pip_danmaku_color')}, $colorText',
      child: InkWell(
        onTap: () => _showColorPicker(context, color),
        child: ExcludeSemantics(
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
                      colorText,
                      style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold, color: digitColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context, Color initialColor) async {
    final isZh = Get.locale?.languageCode == 'zh';
    await showAppColorPickerDialog(
      context: context,
      initialColor: initialColor,
      title: i18n('pip_danmaku_color'),
      enableOpacity: false,
      labels: buildAppColorPickerLabels(translate: (key) => i18n(key), isChinese: isZh, enableOpacity: false),
      customColorSwatchesAndNames: AppConsts.colorsNameMap,
      onColorChanged: (color) {
        SettingsService.to.danmaku.pipDanmakuColor.v = color.toARGB32();
      },
    );
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
      final noEmojiMode = settings.pipDanmakuNoEmojiMode.v;
      final useOriginalColor = settings.pipDanmakuUseOriginalColor.v;
      final unifiedColor = Color(settings.pipDanmakuColor.v);
      final configuredFontSize = settings.pipDanmakuFontSize.v;
      final fontWeight = settings.pipDanmakuFontWeight.v;
      final fontFamily = settings.danmakuFontFamilyName.v;
      final showStroke = settings.enableDanmakuStroke.v;
      final strokeWidth = settings.danmakuFontBorder.v;
      final speed = settings.pipDanmakuSpeed.v;
      final opacity = enabled ? settings.pipDanmakuOpacity.v : 0.25;
      final area = settings.pipDanmakuArea.v;
      final maxVisibleCount = settings.pipDanmakuMaxVisibleCount.v;
      final emitInterval = settings.pipDanmakuEmitInterval.v;
      final fps = settings.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode);
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
                  final metrics = CompactDanmakuMetrics.resolve(
                    width: constraints.maxWidth,
                    autoScale: autoScale,
                    configuredFontSize: configuredFontSize,
                    configuredSpeed: speed,
                  );
                  final fontSize = metrics.fontSize;
                  final typography = CompactDanmakuTypography.resolve(
                    configuredFontWeight: fontWeight,
                    configuredFontFamily: fontFamily,
                    showStroke: showStroke,
                    configuredStrokeWidth: strokeWidth,
                  );
                  final areaHeight = constraints.maxHeight * area;
                  final previewText = i18n('pip_danmaku_preview_text');
                  final previewTexts = List<String>.generate(
                    maxVisibleCount.clamp(1, 20).toInt(),
                    (index) => '$previewText ${index + 1}${noEmojiMode ? '' : ' 🎉'}',
                  );
                  final painters = List<TextPainter>.generate(
                    previewTexts.length,
                    (index) => TextPainter(
                      text: TextSpan(
                        text: previewTexts[index],
                        style: TextStyle(
                          color: colors[index % colors.length].withValues(alpha: opacity),
                          fontSize: fontSize,
                          fontWeight: FontWeight(typography.fontWeight),
                          fontFamily: typography.fontFamily,
                          height: 1.15,
                        ),
                      ),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout(),
                  );
                  final strokePainters = typography.showStroke
                      ? List<TextPainter>.generate(
                          previewTexts.length,
                          (index) => TextPainter(
                            text: TextSpan(
                              text: previewTexts[index],
                              style: TextStyle(
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = typography.strokeWidth
                                  ..color = Colors.black.withValues(alpha: resolveBarrageStrokeOpacity(opacity)),
                                fontSize: fontSize,
                                fontWeight: FontWeight(typography.fontWeight),
                                fontFamily: typography.fontFamily,
                                height: 1.15,
                              ),
                            ),
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                          )..layout(),
                        )
                      : const <TextPainter>[];

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
                                  strokePainters: strokePainters,
                                  fontSize: fontSize,
                                  fontWeight: typography.fontWeight,
                                  fontFamily: typography.fontFamily,
                                  showStroke: typography.showStroke,
                                  strokeWidth: typography.strokeWidth,
                                  speed: metrics.baseSpeed,
                                  trackHeight: metrics.trackHeight,
                                  overlapSafeGap: metrics.overlapSafeGap,
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
    required this.strokePainters,
    required this.fontSize,
    required this.fontWeight,
    required this.fontFamily,
    required this.showStroke,
    required this.strokeWidth,
    required this.speed,
    required this.trackHeight,
    required this.overlapSafeGap,
    required this.emitInterval,
  });

  final double progress;
  final List<TextPainter> painters;
  final List<TextPainter> strokePainters;
  final double fontSize;
  final int fontWeight;
  final String fontFamily;
  final bool showStroke;
  final double strokeWidth;
  final double speed;
  final double trackHeight;
  final double overlapSafeGap;
  final double emitInterval;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final laneCount = math.max(1, (size.height / trackHeight).floor());
    final elapsedSeconds = progress * 12;

    for (var index = 0; index < painters.length; index++) {
      final painter = painters[index];
      final travel = size.width + painter.width + overlapSafeGap;
      final phaseDistance = index * math.max(speed * emitInterval, painter.width + overlapSafeGap);
      final travelled = elapsedSeconds * speed + phaseDistance;
      final x = size.width - (travelled % travel);
      final y = (index % laneCount) * trackHeight + math.max(0, (trackHeight - painter.height) / 2);
      if (showStroke) {
        strokePainters[index].paint(canvas, Offset(x, y));
      }
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _PipDanmakuPreviewPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.painters != painters ||
        oldDelegate.strokePainters != strokePainters ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.fontWeight != fontWeight ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.showStroke != showStroke ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.speed != speed ||
        oldDelegate.trackHeight != trackHeight ||
        oldDelegate.overlapSafeGap != overlapSafeGap ||
        oldDelegate.emitInterval != emitInterval;
  }
}
