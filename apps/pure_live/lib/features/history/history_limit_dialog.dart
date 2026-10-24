import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/providers/refresh_settings_providers.dart' show HistoryLimitController;
import 'package:pure_live/l10n/translations.dart';

/// Asks for the history cap, the number of watch records the history keeps;
/// [save] writes the choice through. Returns the saved cap, or null when
/// the dialog was dismissed.
Future<int?> showHistoryLimitDialog(
  BuildContext context, {
  required int limit,
  required Future<void> Function(int limit) save,
}) => showDsDialog<int>(
  context: context,
  builder: (_) => HistoryLimitDialog(limit: limit, save: save),
);

/// The history cap dialog: preset choices and a custom number between the
/// store's floor and ceiling.
final class HistoryLimitDialog extends StatefulWidget {
  /// Creates the dialog for the current [limit], saving through [save].
  const HistoryLimitDialog({required this.limit, required this.save, super.key});

  /// The cap now.
  final int limit;

  /// Stores a chosen cap.
  final Future<void> Function(int limit) save;

  /// The preset caps the chips offer (within the store's range).
  static const presets = <int>[100, 200, 500, 1000];

  @override
  State<HistoryLimitDialog> createState() => _HistoryLimitDialogState();
}

final class _HistoryLimitDialogState extends State<HistoryLimitDialog> {
  late int _draft = widget.limit;
  final _custom = TextEditingController();
  bool _invalid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // A cap off the presets is the custom field's starting text.
    if (!HistoryLimitDialog.presets.contains(widget.limit)) {
      _custom.text = '${widget.limit}';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _select(int value) {
    // A chosen preset is what the user means; a typed number gives way.
    _custom.clear();
    setState(() {
      _draft = value;
      _invalid = false;
    });
  }

  /// A number in range becomes the draft at once; a partial or out of range
  /// number waits for the save, which explains it.
  void _customChanged(String text) {
    final value = int.tryParse(text.trim());
    if (value != null && value >= HistoryLimitController.min && value <= HistoryLimitController.max) {
      setState(() {
        _draft = value;
        _invalid = false;
      });
    } else if (_invalid) {
      setState(() => _invalid = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final custom = _custom.text.trim();
    if (custom.isNotEmpty) {
      final value = int.tryParse(custom);
      if (value == null || value < HistoryLimitController.min || value > HistoryLimitController.max) {
        setState(() => _invalid = true);
        return;
      }
      _draft = value;
    }
    setState(() => _saving = true);
    try {
      await widget.save(_draft);
      if (mounted) Navigator.of(context).pop(_draft);
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: context.t.history.changeFailed, status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.history.limitTitle),
      icon: const DsIcon(DsIcons.gauge),
      description: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.history.limitDescription, style: theme.typography.body.copyWith(color: colors.textMuted)),
          Text(t.history.limitPresetsLabel, style: theme.typography.small.copyWith(color: colors.textMuted)),
          DsChoiceChips<int>(
            value: _draft,
            onChanged: _saving ? null : _select,
            options: [
              for (final preset in HistoryLimitDialog.presets) DsChipOption(value: preset, label: Text('$preset')),
            ],
          ),
          DsField(
            label: Text(t.history.limitCustomLabel),
            errorText: _invalid
                ? t.history.limitInvalid(min: HistoryLimitController.min, max: HistoryLimitController.max)
                : null,
            child: DsTextField(
              controller: _custom,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              placeholder: '${HistoryLimitController.min}–${HistoryLimitController.max}',
              onChanged: _customChanged,
              onSubmitted: (_) => unawaited(_save()),
            ),
          ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          autofocus: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(loading: _saving, onPressed: _saving ? null : () => unawaited(_save()), child: Text(t.common.confirm)),
      ],
    );
  }
}
