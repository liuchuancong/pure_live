import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';

Future<void> showLocalDanmakuStyleEditor(
  BuildContext context, {
  required LocalInteractionController controller,
}) {
  final viewport = MediaQuery.sizeOf(context);
  final landscape = viewport.width > viewport.height;
  if (landscape) {
    final layout = resolveContentFirstPanelLayout(
      viewport,
      ContentFirstPanelKind.localDanmakuStyle,
    );
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('local-danmaku-style-dialog'),
        alignment: Alignment.centerRight,
        insetPadding: layout.insetPadding,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: layout.size.width,
          height: layout.size.height,
          child: _StyleSurface(
            controller: controller,
            close: () => Navigator.pop(dialogContext),
            splitPreview: layout.splitContent,
            panelCompact: true,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .86,
        child: _StyleSurface(controller: controller, close: () => Navigator.pop(sheetContext)),
      ),
    ),
  );
}

class _StyleSurface extends StatelessWidget {
  const _StyleSurface({
    required this.controller,
    required this.close,
    this.splitPreview = false,
    this.panelCompact = false,
  });

  final LocalInteractionController controller;
  final VoidCallback close;
  final bool splitPreview;
  final bool panelCompact;

  @override
  Widget build(BuildContext context) {
    final headerHeight = panelCompact ? 38.0 : 46.0;
    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: Padding(
            padding: EdgeInsets.only(left: panelCompact ? 10 : 14, right: 2),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: panelCompact ? 18 : 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: panelCompact ? 6 : 8),
                Expanded(
                  child: Text(
                    i18n('local_danmaku_style'),
                    style: panelCompact
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: i18n('restore_default'),
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tightFor(
                    width: panelCompact ? 34 : 40,
                    height: panelCompact ? 34 : 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: controller.resetDanmakuStyle,
                  icon: Icon(Icons.restart_alt_rounded, size: panelCompact ? 19 : 20),
                ),
                IconButton(
                  tooltip: i18n('close'),
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tightFor(
                    width: panelCompact ? 34 : 40,
                    height: panelCompact ? 34 : 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: close,
                  icon: Icon(Icons.close_rounded, size: panelCompact ? 19 : 20),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: splitPreview
              ? Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Padding(
                        key: const ValueKey('local-danmaku-live-preview-pane'),
                        padding: const EdgeInsets.all(8),
                        child: _DanmakuPreview(controller: controller, expanded: true),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        key: const ValueKey('local-danmaku-style-controls'),
                        physics: const PureLiveScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(8, 7, 8, 10),
                        child: _StyleControls(controller: controller, dense: true),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  key: const ValueKey('local-danmaku-style-controls'),
                  physics: const PureLiveScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  child: LocalDanmakuStyleEditor(controller: controller, compact: panelCompact),
                ),
        ),
      ],
    );
  }
}

class LocalDanmakuStyleEditor extends StatelessWidget {
  const LocalDanmakuStyleEditor({super.key, required this.controller, this.compact = false});

  final LocalInteractionController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DanmakuPreview(controller: controller, compact: compact),
        SizedBox(height: compact ? 12 : 16),
        _StyleControls(controller: controller, compact: compact, showDescription: true),
      ],
    );
  }
}

class _DanmakuPreview extends StatelessWidget {
  const _DanmakuPreview({required this.controller, this.compact = false, this.expanded = false});

  final LocalInteractionController controller;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedColor = Color(controller.danmakuColor.v);
      final previewStyle = controller.currentDanmakuStyle;
      final previewShadows = <Shadow>[
        if (previewStyle.showShadow)
          Shadow(
            color: Color(previewStyle.shadowColor).withValues(alpha: previewStyle.opacity),
            blurRadius: previewStyle.shadowBlur,
            offset: Offset(previewStyle.shadowOffset, previewStyle.shadowOffset),
          ),
        if (previewStyle.showStroke) ...[
          Shadow(
            color: Color(previewStyle.strokeColor),
            offset: Offset(previewStyle.strokeWidth, 0),
          ),
          Shadow(
            color: Color(previewStyle.strokeColor),
            offset: Offset(-previewStyle.strokeWidth, 0),
          ),
          Shadow(
            color: Color(previewStyle.strokeColor),
            offset: Offset(0, previewStyle.strokeWidth),
          ),
          Shadow(
            color: Color(previewStyle.strokeColor),
            offset: Offset(0, -previewStyle.strokeWidth),
          ),
        ],
      ];
      final textStyle = TextStyle(
        color: selectedColor.withValues(alpha: previewStyle.opacity),
        fontSize: previewStyle.fontSize,
        fontWeight: FontWeight(previewStyle.fontWeight),
        fontFamily: previewStyle.fontFamily,
        fontStyle: previewStyle.italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: previewStyle.letterSpacing,
        shadows: previewShadows.isEmpty ? null : previewShadows,
      );
      final previewText = i18n('local_danmaku_preview_text');
      final preview = Container(
        key: const ValueKey('local-danmaku-style-preview'),
        width: double.infinity,
        height: expanded ? null : (compact ? 82 : 112),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF27344D), Color(0xFF101623), Color(0xFF06080E)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(Icons.live_tv_rounded, size: expanded ? 54 : 38, color: Colors.white10),
            ),
            if (expanded)
              Positioned(
                left: 9,
                top: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_fill_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          i18n('local_danmaku_live_preview'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (previewStyle.placement == LiveMessagePlacement.scroll)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(top: expanded ? 22 : 0),
                  child: _ScrollingDanmakuPreview(
                    text: previewText,
                    style: textStyle,
                    speed: previewStyle.baseSpeed,
                  ),
                ),
              )
            else
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: previewStyle.placement == LiveMessagePlacement.top
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: expanded ? 38 : 12),
                  child: Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ),
            if (expanded && previewStyle.placement == LiveMessagePlacement.scroll)
              Positioned(
                left: 12,
                right: 8,
                bottom: 38,
                child: Opacity(
                  opacity: .45,
                  child: Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ),
          ],
        ),
      );
      return expanded ? SizedBox.expand(child: preview) : preview;
    });
  }
}

/// Lightweight live speed preview. It exists only while the style editor is
/// visible and therefore does not add work to the normal playback overlay.
class _ScrollingDanmakuPreview extends StatefulWidget {
  const _ScrollingDanmakuPreview({required this.text, required this.style, required this.speed});

  final String text;
  final TextStyle style;
  final double speed;

  @override
  State<_ScrollingDanmakuPreview> createState() => _ScrollingDanmakuPreviewState();
}

class _ScrollingDanmakuPreviewState extends State<_ScrollingDanmakuPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  double _travelDistance = 360;
  bool _durationUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: _durationFor(_travelDistance))
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant _ScrollingDanmakuPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) _applyDuration();
  }

  Duration _durationFor(double distance) {
    final milliseconds = (distance / widget.speed.clamp(60.0, 260.0).toDouble() * 1000)
        .round()
        .clamp(900, 9000)
        .toInt();
    return Duration(milliseconds: milliseconds);
  }

  void _applyDuration() {
    if (!mounted) return;
    final progress = _animation.value;
    _animation
      ..duration = _durationFor(_travelDistance)
      ..value = progress
      ..repeat();
  }

  void _scheduleTravelDistance(double value) {
    if ((value - _travelDistance).abs() < 1 || _durationUpdateScheduled) return;
    _durationUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _durationUpdateScheduled = false;
      if (!mounted) return;
      _travelDistance = value;
      _applyDuration();
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final textWidth = painter.width;
        painter.dispose();
        final travel = constraints.maxWidth + textWidth + 20;
        _scheduleTravelDistance(travel);
        return ClipRect(
          child: AnimatedBuilder(
            animation: _animation,
            child: Text(widget.text, maxLines: 1, softWrap: false, style: widget.style),
            builder: (context, child) => Transform.translate(
              offset: Offset(constraints.maxWidth + 10 - _animation.value * travel, 0),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ),
        );
      },
    );
  }
}

class _StyleControls extends StatelessWidget {
  const _StyleControls({
    required this.controller,
    this.compact = false,
    this.dense = false,
    this.showDescription = false,
  });

  final LocalInteractionController controller;
  final bool compact;
  final bool dense;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = Theme.of(context);
      final compactUi = compact || dense;
      final sectionGap = compactUi ? 11.0 : 17.0;
      void custom(VoidCallback update) {
        update();
        controller.markDanmakuStyleCustom();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StyleSectionTitle(
            icon: Icons.auto_awesome_rounded,
            label: i18n('local_danmaku_presets'),
          ),
          SizedBox(height: compactUi ? 5 : 8),
          Wrap(
            spacing: compactUi ? 5 : 8,
            runSpacing: compactUi ? 5 : 8,
            children: LocalInteractionController.danmakuPresets
                .map(
                  (preset) => ChoiceChip(
                    key: ValueKey('local-danmaku-preset-${preset.id}'),
                    selected: controller.danmakuPreset.v == preset.id,
                    avatar: CircleAvatar(backgroundColor: Color(preset.color), radius: 5),
                    label: Text(i18n(preset.labelKey)),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                    materialTapTargetSize: compactUi
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    onSelected: (_) => controller.applyDanmakuPreset(preset),
                  ),
                )
                .toList(growable: false),
          ),
          SizedBox(height: sectionGap),
          _StyleSectionTitle(
            icon: Icons.vertical_align_center_rounded,
            label: i18n('local_danmaku_placement'),
          ),
          SizedBox(height: compactUi ? 5 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: LocalInteractionController.placementIds
                .map(
                  (id) => ChoiceChip(
                    key: ValueKey('local-danmaku-placement-$id'),
                    selected: controller.danmakuPlacement.v == id,
                    avatar: Icon(switch (id) {
                      'top' => Icons.vertical_align_top_rounded,
                      'bottom' => Icons.vertical_align_bottom_rounded,
                      _ => Icons.trending_flat_rounded,
                    }, size: 17),
                    label: Text(i18n('local_danmaku_placement_$id')),
                    visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                    materialTapTargetSize: compactUi
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    onSelected: (_) => custom(() => controller.danmakuPlacement.v = id),
                  ),
                )
                .toList(growable: false),
          ),
          SizedBox(height: sectionGap),
          _StyleSectionTitle(
            icon: Icons.text_fields_rounded,
            label: i18n('local_danmaku_typography'),
          ),
          SizedBox(height: compactUi ? 5 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: LocalInteractionController.fontFamilyIds
                .map(
                  (id) => ChoiceChip(
                    key: ValueKey('local-danmaku-font-$id'),
                    selected: controller.danmakuFontFamily.v == id,
                    label: Text(
                      i18n('local_danmaku_font_$id'),
                      style: TextStyle(
                        fontFamily: LocalInteractionController.normalizeFontFamily(id),
                      ),
                    ),
                    visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                    materialTapTargetSize: compactUi
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    onSelected: (_) => custom(() => controller.danmakuFontFamily.v = id),
                  ),
                )
                .toList(growable: false),
          ),
          SizedBox(height: compactUi ? 8 : 11),
          Text(i18n('local_danmaku_color'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          _StyleColorPalette(
            values: LocalInteractionController.danmakuColors,
            selected: controller.danmakuColor.v,
            compact: compactUi,
            keyPrefix: 'local-danmaku-color',
            onSelected: (value) => custom(() => controller.danmakuColor.v = value),
          ),
          SizedBox(height: compactUi ? 8 : 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 340;
              final primary = [
                _StyleSlider(
                  label: i18n('local_danmaku_size'),
                  valueLabel: '${controller.danmakuFontSize.v.toStringAsFixed(0)} px',
                  value: controller.danmakuFontSize.v,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  dense: compactUi,
                  onChanged: (value) => custom(() => controller.danmakuFontSize.v = value),
                ),
                _StyleSlider(
                  label: i18n('local_danmaku_speed'),
                  valueLabel: '${controller.danmakuSpeed.v.toStringAsFixed(0)} px/s',
                  value: controller.danmakuSpeed.v,
                  min: 60,
                  max: 260,
                  divisions: 20,
                  dense: compactUi,
                  onChanged: (value) => custom(() => controller.danmakuSpeed.v = value),
                ),
              ];
              final secondary = [
                _StyleSlider(
                  label: i18n('local_danmaku_opacity'),
                  valueLabel: '${(controller.danmakuOpacity.v * 100).round()}%',
                  value: controller.danmakuOpacity.v,
                  min: .35,
                  max: 1,
                  divisions: 13,
                  dense: compactUi,
                  onChanged: (value) => custom(() => controller.danmakuOpacity.v = value),
                ),
                _StyleSlider(
                  label: i18n('local_danmaku_letter_spacing'),
                  valueLabel: controller.danmakuLetterSpacing.v.toStringAsFixed(1),
                  value: controller.danmakuLetterSpacing.v,
                  min: -.5,
                  max: 3,
                  divisions: 14,
                  dense: compactUi,
                  onChanged: (value) => custom(() => controller.danmakuLetterSpacing.v = value),
                ),
              ];
              return Column(
                children: [
                  _ResponsiveSliderRow(twoColumns: twoColumns, children: primary),
                  _ResponsiveSliderRow(twoColumns: twoColumns, children: secondary),
                ],
              );
            },
          ),
          SizedBox(height: compactUi ? 3 : 8),
          _StyleSectionTitle(
            icon: Icons.auto_fix_high_rounded,
            label: i18n('local_danmaku_effects'),
          ),
          SizedBox(height: compactUi ? 5 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                selected: controller.danmakuFontWeight.v >= 700,
                avatar: const Icon(Icons.format_bold_rounded, size: 18),
                label: Text(i18n('local_danmaku_bold')),
                visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                materialTapTargetSize: compactUi
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                onSelected: (value) =>
                    custom(() => controller.danmakuFontWeight.v = value ? 800 : 500),
              ),
              FilterChip(
                selected: controller.danmakuItalic.v,
                avatar: const Icon(Icons.format_italic_rounded, size: 18),
                label: Text(i18n('local_danmaku_italic')),
                visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                materialTapTargetSize: compactUi
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                onSelected: (value) => custom(() => controller.danmakuItalic.v = value),
              ),
              FilterChip(
                selected: controller.danmakuShowStroke.v,
                avatar: const Icon(Icons.border_color_rounded, size: 18),
                label: Text(i18n('local_danmaku_stroke')),
                visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                materialTapTargetSize: compactUi
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                onSelected: (value) => custom(() => controller.danmakuShowStroke.v = value),
              ),
              FilterChip(
                selected: controller.danmakuShowShadow.v,
                avatar: const Icon(Icons.blur_on_rounded, size: 18),
                label: Text(i18n('local_danmaku_shadow')),
                visualDensity: compactUi ? VisualDensity.compact : VisualDensity.standard,
                materialTapTargetSize: compactUi
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                onSelected: (value) => custom(() => controller.danmakuShowShadow.v = value),
              ),
            ],
          ),
          if (controller.danmakuShowStroke.v) ...[
            SizedBox(height: compactUi ? 8 : 12),
            Text(i18n('local_danmaku_stroke_color'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            _StyleColorPalette(
              values: LocalInteractionController.effectColors,
              selected: controller.danmakuStrokeColor.v,
              compact: true,
              keyPrefix: 'local-danmaku-stroke-color',
              onSelected: (value) => custom(() => controller.danmakuStrokeColor.v = value),
            ),
            _StyleSlider(
              label: i18n('local_danmaku_stroke_width'),
              valueLabel: controller.danmakuStrokeWidth.v.toStringAsFixed(1),
              value: controller.danmakuStrokeWidth.v,
              min: .5,
              max: 4,
              divisions: 7,
              dense: compactUi,
              onChanged: (value) => custom(() => controller.danmakuStrokeWidth.v = value),
            ),
          ],
          if (controller.danmakuShowShadow.v) ...[
            SizedBox(height: compactUi ? 8 : 12),
            Text(i18n('local_danmaku_shadow_color'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            _StyleColorPalette(
              values: LocalInteractionController.effectColors,
              selected: controller.danmakuShadowColor.v,
              compact: true,
              keyPrefix: 'local-danmaku-shadow-color',
              onSelected: (value) => custom(() => controller.danmakuShadowColor.v = value),
            ),
            LayoutBuilder(
              builder: (context, constraints) => _ResponsiveSliderRow(
                twoColumns: constraints.maxWidth >= 340,
                children: [
                  _StyleSlider(
                    label: i18n('local_danmaku_shadow_blur'),
                    valueLabel: controller.danmakuShadowBlur.v.toStringAsFixed(1),
                    value: controller.danmakuShadowBlur.v,
                    min: 0,
                    max: 6,
                    divisions: 12,
                    dense: compactUi,
                    onChanged: (value) => custom(() => controller.danmakuShadowBlur.v = value),
                  ),
                  _StyleSlider(
                    label: i18n('local_danmaku_shadow_offset'),
                    valueLabel: controller.danmakuShadowOffset.v.toStringAsFixed(1),
                    value: controller.danmakuShadowOffset.v,
                    min: 0,
                    max: 4,
                    divisions: 8,
                    dense: compactUi,
                    onChanged: (value) => custom(() => controller.danmakuShadowOffset.v = value),
                  ),
                ],
              ),
            ),
          ],
          if (controller.danmakuPlacement.v != 'scroll') ...[
            SizedBox(height: compactUi ? 7 : 11),
            _StyleSlider(
              label: i18n('local_danmaku_fixed_duration'),
              valueLabel: '${(controller.danmakuFixedDurationMs.v / 1000).toStringAsFixed(1)} s',
              value: controller.danmakuFixedDurationMs.v.toDouble(),
              min: 2000,
              max: 10000,
              divisions: 16,
              dense: compactUi,
              onChanged: (value) =>
                  custom(() => controller.danmakuFixedDurationMs.v = value.round()),
            ),
          ],
          if (showDescription) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sync_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    i18n('local_danmaku_style_sync_desc'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _StyleSectionTitle extends StatelessWidget {
  const _StyleSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: colors.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _StyleColorPalette extends StatelessWidget {
  const _StyleColorPalette({
    required this.values,
    required this.selected,
    required this.onSelected,
    required this.keyPrefix,
    this.compact = false,
  });

  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;
  final String keyPrefix;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact ? 29.0 : 36.0;
    return Wrap(
      spacing: compact ? 7 : 9,
      runSpacing: compact ? 6 : 8,
      children: values
          .map((value) {
            final color = Color(value);
            final isSelected = selected == value;
            final foreground = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black87;
            return InkWell(
              key: ValueKey('$keyPrefix-$value'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSelected(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: .22),
                            blurRadius: 5,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, size: compact ? 16 : 19, color: foreground)
                    : null,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ResponsiveSliderRow extends StatelessWidget {
  const _ResponsiveSliderRow({required this.children, required this.twoColumns});

  final List<Widget> children;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    if (!twoColumns) return Column(children: children);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 12),
        Expanded(child: children[1]),
      ],
    );
  }
}

class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.dense = false,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        SizedBox(
          height: dense ? 32 : 40,
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
