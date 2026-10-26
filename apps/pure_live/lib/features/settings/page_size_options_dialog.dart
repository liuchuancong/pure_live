import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/page_size_options_provider.dart'
    show
        kPageSizeOptionMax,
        kPageSizeOptionMin,
        normalizePageSizeOptions,
        pageSizeOptionsForWidth,
        pageSizeOptionsProvider;
import 'package:pure_live/l10n/translations.dart';

/// Opens the manager for the pagers' rooms-per-page choices: the current
/// options, a custom 1–100 field and the reference's width-based
/// recommendation. Saving writes the normalized list for every pager.
Future<void> showPageSizeOptionsDialog(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _PageSizeOptionsDialog());

final class _PageSizeOptionsDialog extends ConsumerStatefulWidget {
  const _PageSizeOptionsDialog();

  @override
  ConsumerState<_PageSizeOptionsDialog> createState() => _PageSizeOptionsDialogState();
}

final class _PageSizeOptionsDialogState extends ConsumerState<_PageSizeOptionsDialog> {
  late List<int> _draft;
  final TextEditingController _input = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = List<int>.from(ref.read(pageSizeOptionsProvider));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _add() {
    final t = context.t;
    final value = int.tryParse(_input.text.trim());
    if (value == null || value < kPageSizeOptionMin || value > kPageSizeOptionMax) {
      setState(() => _error = t.settings.pageSizeOptionInvalid);
      return;
    }
    if (_draft.contains(value)) {
      setState(() => _error = t.settings.pageSizeOptionDuplicate);
      return;
    }
    setState(() {
      _draft = normalizePageSizeOptions([..._draft, value]);
      _error = null;
    });
    _input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _remove(int size) {
    if (_draft.length <= 1) return;
    setState(() {
      _draft = [..._draft]..remove(size);
      _error = null;
    });
  }

  void _recommend() {
    setState(() {
      _draft = pageSizeOptionsForWidth(MediaQuery.sizeOf(context).width);
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(pageSizeOptionsProvider.notifier).save(_draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.settings.pageSizeOptionsDialogTitle),
      description: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              Text(
                t.settings.pageSizeOptionsDescription,
                style: theme.typography.small.copyWith(color: colors.textMuted),
              ),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (final size in _draft)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.trash2, size: 12),
                      semanticLabel: t.settings.pageSizeOptionRemove(size: size),
                      onPressed: _saving || _draft.length <= 1 ? null : () => _remove(size),
                      child: Text('$size'),
                    ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.wandSparkles, size: 14),
                  onPressed: _saving ? null : _recommend,
                  child: Text(t.settings.pageSizeOptionsRecommend),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsTextField(
                      controller: _input,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      placeholder: t.settings.pageSizeOptionCustom,
                      semanticLabel: t.settings.pageSizeOptionCustom,
                      error: _error != null,
                      onChanged: (_) => _clearError(),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    onPressed: _saving ? null : _add,
                    child: Text(t.settings.pageSizeOptionAdd),
                  ),
                ],
              ),
              if (_error != null) Text(_error!, style: theme.typography.small.copyWith(color: colors.danger.text)),
            ],
          ),
        ),
      ),
      style: const DsDialogStyle(width: 520),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(loading: _saving, onPressed: _saving ? null : () => unawaited(_save()), child: Text(t.common.confirm)),
      ],
    );
  }
}
