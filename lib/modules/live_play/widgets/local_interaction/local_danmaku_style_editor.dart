import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';

Future<void> showLocalDanmakuStyleEditor(BuildContext context, {required LocalInteractionController controller}) {
  final viewport = MediaQuery.sizeOf(context);
  final landscape = viewport.width > viewport.height;
  if (landscape) {
    final layout = resolveContentFirstPanelLayout(viewport, ContentFirstPanelKind.localDanmakuStyle);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('local-danmaku-style-dialog'),
        insetPadding: layout.insetPadding,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: layout.size.width,
          height: layout.size.height,
          child: _StyleSurface(
            controller: controller,
            close: () => Navigator.pop(dialogContext),
            splitPreview: layout.splitContent,
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
  const _StyleSurface({required this.controller, required this.close, this.splitPreview = false});

  final LocalInteractionController controller;
  final VoidCallback close;
  final bool splitPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(i18n('local_danmaku_style'), style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: i18n('restore_default'),
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.resetDanmakuStyle,
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                ),
                IconButton(
                  tooltip: i18n('close'),
                  visualDensity: VisualDensity.compact,
                  onPressed: close,
                  icon: const Icon(Icons.close_rounded, size: 20),
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
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _DanmakuPreview(controller: controller, expanded: true),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        key: const ValueKey('local-danmaku-style-controls'),
                        physics: const PureLiveScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        child: _StyleControls(controller: controller, dense: true),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  key: const ValueKey('local-danmaku-style-controls'),
                  physics: const PureLiveScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  child: LocalDanmakuStyleEditor(controller: controller),
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
      final textStyle = TextStyle(
        color: selectedColor,
        fontSize: previewStyle.fontSize,
        fontWeight: FontWeight(previewStyle.fontWeight),
        shadows: previewStyle.showStroke
            ? [
                Shadow(color: Colors.black, blurRadius: previewStyle.strokeWidth * 1.8),
                const Shadow(color: Colors.black, offset: Offset(1, 1)),
              ]
            : null,
      );
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
              child: Icon(Icons.live_tv_rounded, size: expanded ? 72 : 38, color: Colors.white10),
            ),
            Positioned(
              left: 18,
              right: 12,
              top: expanded ? 38 : 18,
              child: Text(
                i18n('local_danmaku_preview_text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (expanded)
              Positioned(
                left: 48,
                right: 12,
                top: 112,
                child: Opacity(
                  opacity: .62,
                  child: Text(
                    i18n('local_danmaku_preview_text'),
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
      final colorSize = dense ? 32.0 : 38.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(i18n('local_danmaku_presets'), style: theme.textTheme.titleSmall),
          SizedBox(height: dense ? 5 : 8),
          Wrap(
            spacing: dense ? 6 : 8,
            runSpacing: dense ? 5 : 8,
            children: LocalInteractionController.danmakuPresets
                .map(
                  (preset) => ChoiceChip(
                    key: ValueKey('local-danmaku-preset-${preset.id}'),
                    selected: controller.danmakuPreset.v == preset.id,
                    avatar: CircleAvatar(backgroundColor: Color(preset.color), radius: 5),
                    label: Text(i18n(preset.labelKey)),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                    visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
                    materialTapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
                    onSelected: (_) => controller.applyDanmakuPreset(preset),
                  ),
                )
                .toList(growable: false),
          ),
          SizedBox(height: dense ? 10 : 18),
          Text(i18n('local_danmaku_color'), style: theme.textTheme.titleSmall),
          SizedBox(height: dense ? 5 : 8),
          Wrap(
            spacing: dense ? 8 : 10,
            runSpacing: dense ? 7 : 10,
            children: LocalInteractionController.danmakuColors
                .map((value) {
                  final selected = controller.danmakuColor.v == value;
                  return InkWell(
                    key: ValueKey('local-danmaku-color-$value'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      controller.danmakuColor.v = value;
                      controller.markDanmakuStyleCustom();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: colorSize,
                      height: colorSize,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: selected ? Icon(Icons.check_rounded, size: dense ? 17 : 20, color: Colors.black87) : null,
                    ),
                  );
                })
                .toList(growable: false),
          ),
          SizedBox(height: dense ? 8 : 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = !compact && constraints.maxWidth >= 420;
              final children = [
                _StyleSlider(
                  label: i18n('local_danmaku_size'),
                  valueLabel: '${controller.danmakuFontSize.v.toStringAsFixed(0)} px',
                  value: controller.danmakuFontSize.v,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  dense: dense,
                  onChanged: (value) {
                    controller.danmakuFontSize.v = value;
                    controller.markDanmakuStyleCustom();
                  },
                ),
                _StyleSlider(
                  label: i18n('local_danmaku_speed'),
                  valueLabel: '${controller.danmakuSpeed.v.toStringAsFixed(0)} px/s',
                  value: controller.danmakuSpeed.v,
                  min: 60,
                  max: 260,
                  divisions: 20,
                  dense: dense,
                  onChanged: (value) {
                    controller.danmakuSpeed.v = value;
                    controller.markDanmakuStyleCustom();
                  },
                ),
              ];
              return twoColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: children[0]),
                        const SizedBox(width: 14),
                        Expanded(child: children[1]),
                      ],
                    )
                  : Column(children: children);
            },
          ),
          SizedBox(height: dense ? 0 : 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                selected: controller.danmakuFontWeight.v >= 700,
                avatar: const Icon(Icons.format_bold_rounded, size: 18),
                label: Text(i18n('local_danmaku_bold')),
                visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
                materialTapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
                onSelected: (value) {
                  controller.danmakuFontWeight.v = value ? 800 : 500;
                  controller.markDanmakuStyleCustom();
                },
              ),
              FilterChip(
                selected: controller.danmakuShowStroke.v,
                avatar: const Icon(Icons.border_color_rounded, size: 18),
                label: Text(i18n('local_danmaku_stroke')),
                visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
                materialTapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
                onSelected: (value) {
                  controller.danmakuShowStroke.v = value;
                  controller.markDanmakuStyleCustom();
                },
              ),
              if (controller.danmakuShowStroke.v)
                SizedBox(
                  width: dense ? 190 : 220,
                  child: _StyleSlider(
                    label: i18n('local_danmaku_stroke_width'),
                    valueLabel: controller.danmakuStrokeWidth.v.toStringAsFixed(1),
                    value: controller.danmakuStrokeWidth.v,
                    min: .5,
                    max: 4,
                    divisions: 7,
                    dense: dense,
                    onChanged: (value) {
                      controller.danmakuStrokeWidth.v = value;
                      controller.markDanmakuStyleCustom();
                    },
                  ),
                ),
            ],
          ),
          if (showDescription) ...[
            const SizedBox(height: 8),
            Text(i18n('local_danmaku_style_sync_desc'), style: theme.textTheme.bodySmall),
          ],
        ],
      );
    });
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
