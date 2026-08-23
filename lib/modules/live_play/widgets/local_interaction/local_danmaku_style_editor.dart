import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';

Future<void> showLocalDanmakuStyleEditor(BuildContext context, {required LocalInteractionController controller}) {
  final size = MediaQuery.sizeOf(context);
  final landscape = size.width > size.height;
  if (landscape) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('local-danmaku-style-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * .82),
          child: _StyleSurface(controller: controller, close: () => Navigator.pop(dialogContext)),
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
        heightFactor: .82,
        child: _StyleSurface(controller: controller, close: () => Navigator.pop(sheetContext)),
      ),
    ),
  );
}

class _StyleSurface extends StatelessWidget {
  const _StyleSurface({required this.controller, required this.close});

  final LocalInteractionController controller;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(i18n('local_danmaku_style'), style: Theme.of(context).textTheme.titleLarge)),
              TextButton.icon(
                onPressed: controller.resetDanmakuStyle,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(i18n('restore_default')),
              ),
              IconButton(onPressed: close, icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            physics: const PureLiveScrollPhysics(),
            padding: const EdgeInsets.all(18),
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
    return Obx(() {
      final theme = Theme.of(context);
      final selectedColor = Color(controller.danmakuColor.v);
      final previewStyle = controller.currentDanmakuStyle;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('local-danmaku-style-preview'),
            height: compact ? 82 : 100,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF172033), Color(0xFF080B12)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              i18n('local_danmaku_preview_text'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selectedColor,
                fontSize: previewStyle.fontSize,
                fontWeight: FontWeight(previewStyle.fontWeight),
                shadows: previewStyle.showStroke
                    ? [
                        Shadow(color: Colors.black, blurRadius: previewStyle.strokeWidth * 1.8),
                        const Shadow(color: Colors.black, offset: Offset(1, 1)),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(i18n('local_danmaku_presets'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LocalInteractionController.danmakuPresets
                .map(
                  (preset) => ChoiceChip(
                    key: ValueKey('local-danmaku-preset-${preset.id}'),
                    selected: controller.danmakuPreset.v == preset.id,
                    avatar: CircleAvatar(backgroundColor: Color(preset.color), radius: 6),
                    label: Text(i18n(preset.labelKey)),
                    onSelected: (_) => controller.applyDanmakuPreset(preset),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          Text(i18n('local_danmaku_color'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: selected ? const Icon(Icons.check_rounded, size: 20, color: Colors.black87) : null,
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = !compact && constraints.maxWidth >= 620;
              final children = [
                _StyleSlider(
                  label: i18n('local_danmaku_size'),
                  valueLabel: '${controller.danmakuFontSize.v.toStringAsFixed(0)} px',
                  value: controller.danmakuFontSize.v,
                  min: 14,
                  max: 32,
                  divisions: 18,
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
                        const SizedBox(width: 18),
                        Expanded(child: children[1]),
                      ],
                    )
                  : Column(children: children);
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: controller.danmakuFontWeight.v >= 700,
                avatar: const Icon(Icons.format_bold_rounded, size: 18),
                label: Text(i18n('local_danmaku_bold')),
                onSelected: (value) {
                  controller.danmakuFontWeight.v = value ? 800 : 500;
                  controller.markDanmakuStyleCustom();
                },
              ),
              FilterChip(
                selected: controller.danmakuShowStroke.v,
                avatar: const Icon(Icons.border_color_rounded, size: 18),
                label: Text(i18n('local_danmaku_stroke')),
                onSelected: (value) {
                  controller.danmakuShowStroke.v = value;
                  controller.markDanmakuStyleCustom();
                },
              ),
              if (controller.danmakuShowStroke.v)
                SizedBox(
                  width: 220,
                  child: _StyleSlider(
                    label: i18n('local_danmaku_stroke_width'),
                    valueLabel: controller.danmakuStrokeWidth.v.toStringAsFixed(1),
                    value: controller.danmakuStrokeWidth.v,
                    min: .5,
                    max: 4,
                    divisions: 7,
                    onChanged: (value) {
                      controller.danmakuStrokeWidth.v = value;
                      controller.markDanmakuStyleCustom();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(i18n('local_danmaku_style_sync_desc'), style: theme.textTheme.bodySmall),
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
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }
}
