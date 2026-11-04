import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show DanmakuBlockPattern, DanmakuBlockPatternProblem;
import 'package:pure_live/l10n/translations.dart';

/// The inline add line both shield lists use: one entry field and its add
/// button, with the empty and duplicate answers as toasts.
///
/// The room's compact panel and the settings pane share it, so a new keyword
/// or user is accepted the same way wherever it is typed.
final class ShieldAddField extends ConsumerStatefulWidget {
  /// The line adding to a list.
  const ShieldAddField({
    required this.fieldHint,
    required this.onAdd,
    this.acceptsPatterns = false,
    this.padding = EdgeInsets.zero,
    this.trailing,
    super.key,
  });

  /// The field's placeholder.
  final String fieldHint;

  /// Adds the entry; answers false when it is empty or a duplicate.
  final Future<bool> Function(String value) onAdd;

  /// Whether a word written `/…/` means a regular expression here. It is the
  /// keyword list's property, not the user list's, and the guard that decides
  /// whether a pattern is safe to run belongs to the site package — which also
  /// owns the format the room's filter and the recording's sidecar read.
  ///
  /// Refusing a bad one at the field is the only honest option: a pattern the
  /// lists drop would otherwise be stored behind a "已添加" and block nothing.
  final bool acceptsPatterns;

  /// Space around the field and its button.
  final EdgeInsetsGeometry padding;

  /// One more action at the line's end, after the add button.
  final Widget? trailing;

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
          ?widget.trailing,
        ],
      ),
    );
  }

  Future<void> _commit() async {
    final t = context.t;
    final value = _field.text;
    if (widget.acceptsPatterns && value.trim().isNotEmpty) {
      final problem = DanmakuBlockPattern.check(value);
      if (problem != null) {
        // The lists read a refused word as nothing at all, so the field is the
        // one place that can say why the word will not work.
        showDsToast(
          context: context,
          title: switch (problem) {
            DanmakuBlockPatternProblem.tooSlow => t.shield.patternTooSlow,
            _ => t.shield.patternRejected,
          },
        );
        return;
      }
    }
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
