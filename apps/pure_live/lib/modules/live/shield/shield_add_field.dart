import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';

/// The inline add line both shield lists use: one entry field and its add
/// button, with the empty and duplicate answers as toasts.
///
/// The room's compact panel and the settings pane share it, so a new keyword
/// or user is accepted the same way wherever it is typed.
final class ShieldAddField extends ConsumerStatefulWidget {
  /// The line adding to a list.
  const ShieldAddField({required this.fieldHint, required this.onAdd, this.padding = EdgeInsets.zero, super.key});

  /// The field's placeholder.
  final String fieldHint;

  /// Adds the entry; answers false when it is empty or a duplicate.
  final Future<bool> Function(String value) onAdd;

  /// Space around the field and its button.
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ShieldAddField> createState() => _ShieldAddFieldState();
}

final class _ShieldAddFieldState extends ConsumerState<ShieldAddField> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    return Padding(
      padding: widget.padding,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsTextField(
              controller: _field,
              clearable: true,
              placeholder: widget.fieldHint,
              onSubmitted: (value) => unawaited(_commit()),
              semanticLabel: widget.fieldHint,
              style: DsTextFieldStyle(height: theme.sizes.sm),
            ),
          ),
          DsButton(size: DsSize.sm, onPressed: () => unawaited(_commit()), child: Text(t.shield.add)),
        ],
      ),
    );
  }

  Future<void> _commit() async {
    final t = context.t;
    final value = _field.text;
    final added = await widget.onAdd(value);
    if (!mounted) return;
    if (value.trim().isEmpty) {
      showDsToast(context: context, title: t.shield.invalidEntry);
      return;
    }
    if (!added) {
      showDsToast(context: context, title: t.shield.duplicateEntry);
      return;
    }
    _field.clear();
    showDsToast(context: context, title: t.shield.added);
  }
}
