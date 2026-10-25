import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/auto_shutdown_provider.dart';
import 'package:pure_live/l10n/translations.dart';

/// The automatic-shutdown section of the General pane: the switch and the
/// duration. The countdown runs from the moment it is enabled (and restarts
/// when the duration changes), matching the reference's auto-shutdown timer.
final class AutoShutdownSection extends ConsumerWidget {
  /// Creates the section.
  const AutoShutdownSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(autoShutdownProvider);
    final remaining = state.remaining;
    return DsListSection(
      header: Text(t.settings.autoShutdownGroup),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.timer),
          title: Text(t.settings.autoShutdown),
          description: Text(t.settings.autoShutdownDesc),
          trailing: DsSwitch(
            value: state.enabled,
            onChanged: (value) => unawaited(ref.read(autoShutdownProvider.notifier).setEnabled(enabled: value)),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.clock),
          title: Text(t.settings.autoShutdownDuration),
          detail: Text(
            state.enabled && remaining != null
                ? t.settings.autoShutdownRemaining(time: _format(remaining))
                : t.settings.autoShutdownMinutes(count: state.minutes),
          ),
          showChevron: true,
          onPressed: () => unawaited(showAutoShutdownDurationDialog(context, ref)),
        ),
      ],
    );
  }

  static String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Opens the duration dialog; choosing a value saves it and restarts a
/// running countdown.
Future<void> showAutoShutdownDurationDialog(BuildContext context, WidgetRef ref) => showDsDialog<void>(
  context: context,
  builder: (context) => _AutoShutdownDurationDialog(initial: ref.read(autoShutdownProvider).minutes),
);

final class _AutoShutdownDurationDialog extends ConsumerStatefulWidget {
  const _AutoShutdownDurationDialog({required this.initial});

  final int initial;

  @override
  ConsumerState<_AutoShutdownDurationDialog> createState() => _AutoShutdownDurationDialogState();
}

final class _AutoShutdownDurationDialogState extends ConsumerState<_AutoShutdownDurationDialog> {
  static const List<int> _presets = [15, 30, 45, 60, 90, 120, 180, 240, 480, 720, 1440];

  late final TextEditingController _minutes = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final t = context.t;
    final value = int.tryParse(_minutes.text.trim());
    if (value == null || value < AutoShutdownController.minMinutes || value > AutoShutdownController.maxMinutes) {
      setState(() => _error = t.settings.autoShutdownInvalid);
      return;
    }
    await ref.read(autoShutdownProvider.notifier).setMinutes(value);
    if (!mounted) return;
    showDsToast(context: context, title: t.settings.autoShutdownSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.settings.autoShutdownDuration),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final minutes in _presets)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () {
                    _minutes.text = '$minutes';
                    if (_error != null) setState(() => _error = null);
                  },
                  child: Text(t.settings.autoShutdownPreset(minutes: minutes)),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              Text(t.settings.autoShutdownCustom, style: theme.typography.small.copyWith(color: colors.textMuted)),
              DsTextField(
                controller: _minutes,
                semanticLabel: t.settings.autoShutdownCustom,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ],
          ),
          Text(
            _error ?? t.settings.autoShutdownRange,
            style: theme.typography.small.copyWith(color: _error == null ? colors.textSubtle : colors.danger.text),
          ),
        ],
      ),
      style: const DsDialogStyle(width: 520),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(onPressed: () => unawaited(_apply()), child: Text(t.common.confirm)),
      ],
    );
  }
}
