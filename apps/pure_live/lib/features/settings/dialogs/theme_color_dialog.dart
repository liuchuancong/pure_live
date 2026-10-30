import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/dialogs/color_picker.dart';
import 'package:pure_live/l10n/translations.dart';

/// The reference's accent presets (`AppConsts.themeColors`), in its order.
///
/// They are raw colours, not labels: the swatch and the hex name are what
/// a viewer sees, in every language.
const List<Color> kThemeColorPresets = [
  Color(0xFFDC143C), // Crimson
  Color(0xFFFF9800), // Orange
  Color(0xFFE6B800), // Chrome
  Color(0xFF8BC34A), // Grass
  Color(0xFF009688), // Teal
  Color(0xFF70C1CF), // SeaFoam
  Color(0xFF739BD0), // Ice
  Color(0xFF2196F3), // Blue
  Color(0xFF3F51B5), // Indigo
  Color(0xFF673AB7), // Violet
  Color(0xFF6200EE), // Primary
  Color(0xFFDA70D6), // Orchid
  Color(0xFF3700B3), // Variant
  Color(0xFF03DAC6), // Secondary
];

/// A named tone's localized name.
String themeSeedToneLabel(Translations t, String name) => switch (name) {
  'seedBlue' => t.settings.seedBlue,
  'seedNavy' => t.settings.seedNavy,
  'seedIndigo' => t.settings.seedIndigo,
  'seedGraphite' => t.settings.seedGraphite,
  'seedOxblood' => t.settings.seedOxblood,
  'seedForest' => t.settings.seedForest,
  _ => name,
};

/// Opens the accent-colour picker: the system accent, the named tones,
/// the reference's preset swatches, and an arbitrary colour picked from an
/// HSV field, a hue bar or a hex value. A choice is applied only on
/// Confirm, so closing the dialog leaves the theme as it was.
Future<void> showThemeColorDialog(
  BuildContext context, {
  required AppThemeSettings settings,
  required Color? seedColor,
  required ValueChanged<AppThemeSettings> onChanged,
}) => showDsDialog<void>(
  context: context,
  builder: (context) => _ThemeColorDialog(settings: settings, seedColor: seedColor, onChanged: onChanged),
);

final class _ThemeColorDialog extends StatefulWidget {
  const _ThemeColorDialog({required this.settings, required this.seedColor, required this.onChanged});

  final AppThemeSettings settings;

  /// The arbitrary accent in force; null for a named tone or the system
  /// accent.
  final Color? seedColor;

  final ValueChanged<AppThemeSettings> onChanged;

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

final class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  late final TextEditingController _hex;
  late HSVColor _hsv;
  late final String? _initialNamed;
  late final bool _initialSystem;
  String? _named;
  Color? _custom;
  bool _hexInvalid = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.settings.seed;
    final initial =
        widget.seedColor ??
        (seed == null
            ? DsOklch(DsSeed.blue.l, DsSeed.blue.c, DsSeed.blue.h).toColor()
            : DsOklch(seed.l, seed.c, seed.h).toColor());
    _hsv = HSVColor.fromColor(initial);
    for (final (name, candidate) in kNamedSeeds) {
      if (candidate == seed) _named = name;
    }
    _initialNamed = _named;
    _custom = _named == null ? widget.seedColor : null;
    _initialSystem = _named == null && _custom == null;
    _hex = TextEditingController(text: ThemePersistence.encodeSeedColor(_custom ?? initial));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _selectSystem() {
    setState(() {
      _named = null;
      _custom = null;
      _hexInvalid = false;
    });
  }

  void _selectNamed(String name, DsSeed seed) {
    final color = DsOklch(seed.l, seed.c, seed.h).toColor();
    setState(() {
      _named = name;
      _custom = null;
      _hsv = HSVColor.fromColor(color);
      _hex.text = ThemePersistence.encodeSeedColor(color);
      _hexInvalid = false;
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _named = null;
      _custom = color;
      _hsv = HSVColor.fromColor(color);
      _hex.text = ThemePersistence.encodeSeedColor(color);
      _hexInvalid = false;
    });
  }

  void _pickHsv(HSVColor hsv) {
    final color = hsv.toColor();
    setState(() {
      _named = null;
      _custom = color;
      _hsv = hsv;
      _hex.text = ThemePersistence.encodeSeedColor(color);
      _hexInvalid = false;
    });
  }

  void _onHexChanged(String text) {
    final parsed = ThemePersistence.parseSeedColor(text);
    if (parsed == null) {
      setState(() => _hexInvalid = true);
      return;
    }
    setState(() {
      _hexInvalid = false;
      _named = null;
      _custom = parsed;
      _hsv = HSVColor.fromColor(parsed);
    });
  }

  void _apply() {
    final unchanged = _custom != null
        ? _custom == widget.seedColor
        : _named != null
        ? _named == _initialNamed
        : _initialSystem;
    if (unchanged) {
      Navigator.of(context).pop();
      return;
    }
    DsSeed? seed;
    if (_custom != null) {
      seed = DsSeed.color(_custom!);
    } else if (_named != null) {
      for (final (name, candidate) in kNamedSeeds) {
        if (name == _named) seed = candidate;
      }
    }
    widget.onChanged(widget.settings.rebuild((b) => b..seed = seed));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final sectionStyle = theme.typography.small.copyWith(color: colors.textMuted, fontWeight: FontWeight.w600);
    final preview = _custom ?? _hsv.toColor();
    final system = _named == null && _custom == null;
    return DsDialog(
      title: Text(t.settings.themeColorTitle),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          DsListSection(
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.monitor),
                title: Text(t.settings.themeSeedSystem),
                selected: system,
                trailing: system ? const DsIcon(DsIcons.check) : null,
                onPressed: _selectSystem,
              ),
            ],
          ),
          Text(t.settings.themeColorPresets, style: sectionStyle),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (name, seed) in kNamedSeeds)
                DsChip(
                  label: Text(themeSeedToneLabel(t, name)),
                  leading: _SeedDot(seed: seed),
                  selected: _named == name,
                  onChanged: (on) {
                    if (on) _selectNamed(name, seed);
                  },
                ),
              for (final color in kThemeColorPresets)
                _PresetSwatch(color: color, selected: _custom == color, onPressed: () => _selectColor(color)),
            ],
          ),
          Text(t.settings.themeColorCustom, style: sectionStyle),
          Row(
            spacing: DsSpace.s12,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preview,
                  borderRadius: BorderRadius.circular(theme.radii.card / 2),
                  border: Border.all(color: colors.borderField),
                ),
              ),
              Expanded(
                child: DsTextField(
                  controller: _hex,
                  placeholder: '#RRGGBB',
                  clearable: true,
                  semanticLabel: t.settings.themeColorHex,
                  error: _hexInvalid,
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
          if (_hexInvalid)
            Text(t.settings.themeColorHexInvalid, style: theme.typography.small.copyWith(color: colors.danger.text)),
          ColorPickerField(hsv: _hsv, onChanged: _pickHsv, semanticLabel: t.settings.themeColorSaturation),
          ColorPickerHueBar(
            hue: _hsv.hue,
            onChanged: (hue) => _pickHsv(_hsv.withHue(hue)),
            semanticLabel: t.settings.themeColorHue,
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
        DsButton(onPressed: _hexInvalid ? null : _apply, child: Text(t.common.confirm)),
      ],
    );
  }
}

/// A named tone as a small dot, the same mark the appearance row uses.
final class _SeedDot extends StatelessWidget {
  const _SeedDot({required this.seed});

  final DsSeed seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DsThemeData(seed: seed).colors.accent,
      ),
    );
  }
}

/// One preset colour: a square swatch with a check when it is the draft,
/// named by its hex value for pointers and screen readers.
final class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({required this.color, required this.selected, required this.onPressed});

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final hex = ThemePersistence.encodeSeedColor(color);
    return DsTooltip(
      message: hex,
      child: DsPressable(
        onPressed: onPressed,
        semanticLabel: hex,
        selected: selected,
        builder: (context, states, _) {
          final focused = states.contains(WidgetState.focused);
          return Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(theme.radii.card / 2),
              border: Border.all(
                color: selected ? colors.accent : (focused ? colors.focus : colors.borderField),
                width: selected || focused ? 2 : 1,
              ),
            ),
            child: selected
                ? Center(
                    child: DsIcon(
                      DsIcons.check,
                      size: 16,
                      color: color.computeLuminance() > 0.5 ? const Color(0xFF101418) : const Color(0xFFFFFFFF),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}
