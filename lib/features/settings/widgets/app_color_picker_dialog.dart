import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' as material;

/// User-facing strings for [showAppColorPickerDialog].
///
/// Keeping these values at the call site lets the shared picker remain
/// independent from the application's localization lifecycle and makes the
/// editor straightforward to exercise in widget tests.
@immutable
class AppColorPickerLabels {
  const AppColorPickerLabels({
    required this.shades,
    required this.wheel,
    required this.opacity,
    required this.colorCode,
    required this.invalidColorCode,
    required this.primary,
    required this.accent,
    required this.custom,
    required this.wheelPicker,
  });

  final String shades;
  final String wheel;
  final String opacity;
  final String colorCode;
  final String invalidColorCode;
  final String primary;
  final String accent;
  final String custom;
  final String wheelPicker;
}

AppColorPickerLabels buildAppColorPickerLabels({
  required String Function(String key) translate,
  required bool isChinese,
  required bool enableOpacity,
}) {
  return AppColorPickerLabels(
    shades: translate('select_color_shade'),
    wheel: translate('color_wheel_and_tone'),
    opacity: translate('select_opacity'),
    colorCode: translate(enableOpacity ? 'argb_color_code' : 'rgb_color_code'),
    invalidColorCode: translate('invalid_color_code'),
    primary: isChinese ? '常用色' : 'Primary',
    accent: isChinese ? '鲜艳色' : 'Accent',
    custom: isChinese ? '自定义' : 'Custom',
    wheelPicker: isChinese ? '调色盘' : 'Wheel',
  );
}

/// Converts a user-entered RGB/ARGB code into a color.
///
/// Accepted forms are `RRGGBB`, `AARRGGBB`, `#RRGGBB`, `#AARRGGBB`,
/// `0xRRGGBB` and `0xAARRGGBB`. When opacity is disabled an optional alpha
/// prefix is accepted for convenient paste, but normalized to fully opaque.
Color? parseAppColorCode(String input, {required bool enableOpacity}) {
  var value = input.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.toLowerCase().startsWith('0x')) value = value.substring(2);
  if (value.length != 6 && value.length != 8) return null;
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) return null;

  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  final color = Color(parsed);
  return enableOpacity ? color : color.withValues(alpha: 1);
}

String formatAppColorCode(Color color, {required bool enableOpacity}) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  return enableOpacity ? '0x$argb' : '#${argb.substring(2)}';
}

/// Opens the application color editor and restores [initialColor] on cancel.
///
/// FlexColorPicker intentionally exposes a six-character RGB edit field and
/// keeps alpha in a separate slider. This dialog adds a persistent full
/// RGB/ARGB field on every picker tab, explicit clipboard-friendly text
/// selection, and the real opacity control when the target setting supports
/// transparency.
Future<bool> showAppColorPickerDialog({
  required BuildContext context,
  required Color initialColor,
  required ValueChanged<Color> onColorChanged,
  required String title,
  required AppColorPickerLabels labels,
  required Map<ColorSwatch<Object>, String> customColorSwatchesAndNames,
  bool enableOpacity = false,
}) async {
  final selected = await showDialog<Color>(
    context: context,
    builder: (dialogContext) => _AppColorPickerDialog(
      initialColor: initialColor,
      title: title,
      labels: labels,
      customColorSwatchesAndNames: customColorSwatchesAndNames,
      enableOpacity: enableOpacity,
      onPreviewChanged: onColorChanged,
    ),
  );

  if (selected == null) {
    onColorChanged(initialColor);
    return false;
  }
  onColorChanged(selected);
  return true;
}

class _AppColorPickerDialog extends StatefulWidget {
  const _AppColorPickerDialog({
    required this.initialColor,
    required this.title,
    required this.labels,
    required this.customColorSwatchesAndNames,
    required this.enableOpacity,
    required this.onPreviewChanged,
  });

  final Color initialColor;
  final String title;
  final AppColorPickerLabels labels;
  final Map<ColorSwatch<Object>, String> customColorSwatchesAndNames;
  final bool enableOpacity;
  final ValueChanged<Color> onPreviewChanged;

  @override
  State<_AppColorPickerDialog> createState() => _AppColorPickerDialogState();
}

class _AppColorPickerDialogState extends State<_AppColorPickerDialog> {
  static const codeFieldKey = ValueKey<String>('app-color-picker-code');
  static const cancelButtonKey = ValueKey<String>('app-color-picker-cancel');
  static const confirmButtonKey = ValueKey<String>('app-color-picker-confirm');

  late Color _selectedColor;
  late final TextEditingController _codeController;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.enableOpacity ? widget.initialColor : widget.initialColor.withValues(alpha: 1);
    _codeController = TextEditingController(
      text: formatAppColorCode(_selectedColor, enableOpacity: widget.enableOpacity),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _setSelectedColor(Color color, {required bool updateCode}) {
    final normalized = widget.enableOpacity ? color : color.withValues(alpha: 1);
    setState(() {
      _selectedColor = normalized;
      _codeError = null;
      if (updateCode) {
        _codeController.value = TextEditingValue(
          text: formatAppColorCode(normalized, enableOpacity: widget.enableOpacity),
          selection: TextSelection.collapsed(
            offset: formatAppColorCode(normalized, enableOpacity: widget.enableOpacity).length,
          ),
        );
      }
    });
    widget.onPreviewChanged(normalized);
  }

  void _onCodeChanged(String rawValue) {
    final color = parseAppColorCode(rawValue, enableOpacity: widget.enableOpacity);
    if (color == null) {
      if (_codeError != null) setState(() => _codeError = null);
      return;
    }
    _setSelectedColor(color, updateCode: false);
  }

  void _confirm() {
    final color = parseAppColorCode(_codeController.text, enableOpacity: widget.enableOpacity);
    if (color == null) {
      setState(() => _codeError = widget.labels.invalidColorCode);
      return;
    }
    Navigator.of(context).pop(color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materialLocalizations = MaterialLocalizations.of(context);
    final availableHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 320, maxWidth: 420, maxHeight: availableHeight * 0.72),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              material.Material(
                type: material.MaterialType.transparency,
                child: ColorPicker(
                  color: _selectedColor,
                  onColorChanged: (color) => _setSelectedColor(color, updateCode: true),
                  mainAxisSize: MainAxisSize.min,
                  enableOpacity: widget.enableOpacity,
                  width: kMinInteractiveDimension,
                  height: kMinInteractiveDimension,
                  borderRadius: 4,
                  spacing: 5,
                  runSpacing: 5,
                  wheelDiameter: 155,
                  padding: EdgeInsets.zero,
                  subheading: Text(widget.labels.shades, style: theme.textTheme.titleSmall),
                  wheelSubheading: Text(widget.labels.wheel, style: theme.textTheme.titleSmall),
                  opacitySubheading: widget.enableOpacity
                      ? Text(widget.labels.opacity, style: theme.textTheme.titleSmall)
                      : null,
                  showMaterialName: false,
                  showColorName: false,
                  showColorCode: false,
                  selectedPickerTypeColor: theme.colorScheme.primary,
                  customColorSwatchesAndNames: widget.customColorSwatchesAndNames,
                  pickerTypeLabels: <ColorPickerType, String>{
                    ColorPickerType.primary: widget.labels.primary,
                    ColorPickerType.accent: widget.labels.accent,
                    ColorPickerType.custom: widget.labels.custom,
                    ColorPickerType.wheel: widget.labels.wheelPicker,
                  },
                  pickersEnabled: const <ColorPickerType, bool>{
                    ColorPickerType.both: false,
                    ColorPickerType.primary: true,
                    ColorPickerType.accent: true,
                    ColorPickerType.bw: false,
                    ColorPickerType.custom: true,
                    ColorPickerType.wheel: true,
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: codeFieldKey,
                controller: _codeController,
                maxLength: widget.enableOpacity ? 10 : 9,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX#]'))],
                decoration: InputDecoration(
                  labelText: widget.labels.colorCode,
                  helperText: widget.enableOpacity ? '0xAARRGGBB / #AARRGGBB / RRGGBB' : '#RRGGBB / 0xRRGGBB',
                  errorText: _codeError,
                  counterText: '',
                ),
                onChanged: _onCodeChanged,
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: cancelButtonKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialLocalizations.cancelButtonLabel),
        ),
        FilledButton(key: confirmButtonKey, onPressed: _confirm, child: Text(materialLocalizations.okButtonLabel)),
      ],
    );
  }
}
