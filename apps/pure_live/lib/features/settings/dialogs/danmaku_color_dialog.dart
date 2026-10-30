import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart'
    show danmakuColorLabel, kDanmakuColorChoices;
import 'package:pure_live/features/settings/dialogs/color_picker.dart';
import 'package:pure_live/l10n/translations.dart';

/// Opens the danmaku colour picker: the palette for a quick answer, then any
/// colour from the HSV field, the hue strip or a hex value. Answers the
/// chosen opaque ARGB, or null when the viewer cancelled.
Future<int?> showDanmakuColorDialog(BuildContext context, {required int initial}) => showDsDialog<int>(
  context: context,
  builder: (context) => _DanmakuColorDialog(initial: initial),
);

final class _DanmakuColorDialog extends StatefulWidget {
  const _DanmakuColorDialog({required this.initial});

  final int initial;

  @override
  State<_DanmakuColorDialog> createState() => _DanmakuColorDialogState();
}

final class _DanmakuColorDialogState extends State<_DanmakuColorDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;
  bool _hexInvalid = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial | 0xFF000000;
    _hsv = HSVColor.fromColor(Color(initial));
    _hex = TextEditingController(text: colorPickerHexLabel(initial));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  int get _color => _hsv.toColor().toARGB32();

  void _pick(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _hex.text = colorPickerHexLabel(hsv.toColor().toARGB32());
      _hexInvalid = false;
    });
  }

  void _pickPalette(int color) {
    setState(() {
      _hsv = HSVColor.fromColor(Color(color));
      _hex.text = colorPickerHexLabel(color);
      _hexInvalid = false;
    });
  }

  void _onHexChanged(String text) {
    final parsed = parseColorPickerHex(text);
    if (parsed == null) {
      setState(() => _hexInvalid = true);
      return;
    }
    setState(() {
      _hexInvalid = false;
      _hsv = HSVColor.fromColor(Color(parsed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final color = _color;
    return DsDialog(
      title: Text(t.settings.danmakuColorTitle),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          Text(
            t.settings.danmakuColorPresets,
            style: theme.typography.small.copyWith(color: colors.textMuted, fontWeight: FontWeight.w600),
          ),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final preset in kDanmakuColorChoices)
                DsChip(
                  label: Text(danmakuColorLabel(t, preset)),
                  leading: ColorDot(color: preset),
                  selected: color == preset,
                  onChanged: (on) {
                    if (on) _pickPalette(preset);
                  },
                ),
            ],
          ),
          Row(
            spacing: DsSpace.s12,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(color),
                  borderRadius: BorderRadius.circular(theme.radii.card / 2),
                  border: Border.all(color: colors.borderField),
                ),
              ),
              Expanded(
                child: DsTextField(
                  controller: _hex,
                  placeholder: '#RRGGBB',
                  clearable: true,
                  semanticLabel: t.settings.danmakuColorHex,
                  error: _hexInvalid,
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
          if (_hexInvalid)
            Text(t.settings.danmakuColorHexInvalid, style: theme.typography.small.copyWith(color: colors.danger.text)),
          ColorPickerField(hsv: _hsv, onChanged: _pick, semanticLabel: t.settings.danmakuColorSaturation),
          ColorPickerHueBar(
            hue: _hsv.hue,
            onChanged: (hue) => _pick(_hsv.withHue(hue)),
            semanticLabel: t.settings.danmakuColorHue,
          ),
        ],
      ),
      style: const DsDialogStyle(width: 560),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: _hexInvalid ? null : () => Navigator.of(context).pop(_color),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
