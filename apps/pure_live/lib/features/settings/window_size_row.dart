import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/window_size_provider.dart';
import 'package:pure_live/l10n/translations.dart';

/// The General pane's window-size row and its dialog: pick one of the
/// reference's presets or type a width and height, then apply it to the live
/// window. The size is stored by `WindowSizeController` and applied at the
/// next start too.
final class WindowSizeRow extends ConsumerWidget {
  /// Creates the row.
  const WindowSizeRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final size = ref.watch(windowSizeProvider);
    final label = size == null ? '—' : '${size.width.round()} × ${size.height.round()}';
    return DsListRow(
      leading: const DsIcon(DsIcons.appWindow),
      title: Text(t.settings.windowSize),
      description: Text(t.settings.windowSizeDesc),
      detail: Text(label),
      showChevron: true,
      onPressed: () => unawaited(showWindowSizeDialog(context, ref)),
    );
  }
}

/// Opens the size dialog with the current size filled in.
Future<void> showWindowSizeDialog(BuildContext context, WidgetRef ref) => showDsDialog<void>(
  context: context,
  builder: (context) => _WindowSizeDialog(initial: ref.read(windowSizeProvider) ?? const Size(1280, 800)),
);

final class _WindowSizeDialog extends ConsumerStatefulWidget {
  const _WindowSizeDialog({required this.initial});

  final Size initial;

  @override
  ConsumerState<_WindowSizeDialog> createState() => _WindowSizeDialogState();
}

final class _WindowSizeDialogState extends ConsumerState<_WindowSizeDialog> {
  static const List<(String, Size)> _presets = [
    ('1080 × 720', Size(1080, 720)),
    ('1280 × 720 (720P)', Size(1280, 720)),
    ('1600 × 900', Size(1600, 900)),
    ('1920 × 1080 (1080P)', Size(1920, 1080)),
    ('2560 × 1440 (2K)', Size(2560, 1440)),
  ];

  late final TextEditingController _width = TextEditingController(text: widget.initial.width.round().toString());
  late final TextEditingController _height = TextEditingController(text: widget.initial.height.round().toString());
  String? _error;
  bool _applying = false;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _apply() async {
    final t = context.t;
    final width = int.tryParse(_width.text.trim());
    final height = int.tryParse(_height.text.trim());
    if (width == null ||
        height == null ||
        width < WindowSizeController.minWidth ||
        height < WindowSizeController.minHeight ||
        width > WindowSizeController.maxDimension ||
        height > WindowSizeController.maxDimension) {
      setState(() => _error = t.settings.windowSizeOutOfRange);
      return;
    }
    setState(() {
      _error = null;
      _applying = true;
    });
    final failure = await ref.read(windowSizeProvider.notifier).apply(Size(width.toDouble(), height.toDouble()));
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _applying = false;
        _error = failure == 'out_of_range' ? t.settings.windowSizeOutOfRange : t.settings.windowSizeApplyFailed;
      });
      return;
    }
    showDsToast(context: context, title: t.settings.windowSizeApplied);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.settings.windowSize),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final (label, size) in _presets)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _applying
                      ? null
                      : () {
                          _width.text = size.width.round().toString();
                          _height.text = size.height.round().toString();
                          _clearError();
                        },
                  child: Text(label),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s4,
                  children: [
                    Text(t.settings.windowWidth, style: theme.typography.small.copyWith(color: colors.textMuted)),
                    DsTextField(
                      controller: _width,
                      semanticLabel: t.settings.windowWidth,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _clearError(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.s12),
                child: Text('×', style: theme.typography.body.copyWith(color: colors.textSubtle)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s4,
                  children: [
                    Text(t.settings.windowHeight, style: theme.typography.small.copyWith(color: colors.textMuted)),
                    DsTextField(
                      controller: _height,
                      semanticLabel: t.settings.windowHeight,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _clearError(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            _error ?? t.settings.windowSizeRangeHint,
            style: theme.typography.small.copyWith(color: _error == null ? colors.textSubtle : colors.danger.text),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 520),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          loading: _applying,
          onPressed: _applying ? null : () => unawaited(_apply()),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
