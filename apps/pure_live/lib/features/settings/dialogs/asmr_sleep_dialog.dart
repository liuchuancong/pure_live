import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart'
    show
        asmrSleepDurationLabel,
        kAsmrSleepMinuteChoices,
        kAsmrSleepMinutesMax,
        kAsmrSleepMinutesMin,
        playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/room.dart';

/// Opens the ASMR sleep-duration dialog with the stored duration filled in.
Future<void> showAsmrSleepMinutesDialog(BuildContext context, WidgetRef ref) => showDsDialog<void>(
  context: context,
  builder: (context) => _AsmrSleepDialog(initial: ref.read(playbackSettingsProvider).asmrSleepMinutes),
);

final class _AsmrSleepDialog extends ConsumerStatefulWidget {
  const _AsmrSleepDialog({required this.initial});

  final int initial;

  @override
  ConsumerState<_AsmrSleepDialog> createState() => _AsmrSleepDialogState();
}

final class _AsmrSleepDialogState extends ConsumerState<_AsmrSleepDialog> {
  late final TextEditingController _minutes = TextEditingController(text: widget.initial.toString());
  String? _error;
  bool _applying = false;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    final t = context.t;
    final minutes = int.tryParse(_minutes.text.trim());
    if (minutes == null || minutes < kAsmrSleepMinutesMin || minutes > kAsmrSleepMinutesMax) {
      setState(() => _error = t.settings.asmrSleepRange);
      return;
    }
    setState(() {
      _error = null;
      _applying = true;
    });
    // A running sleep session takes the new duration immediately; a future
    // room reads the persisted value on open.
    final timerActive = ref.read(sleepTimerProvider).endsAt != null;
    await ref.read(playbackSettingsProvider.notifier).setAsmrSleepMinutes(minutes);
    if (timerActive) ref.read(sleepTimerProvider.notifier).start(minutes);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.settings.asmrSleepTimer),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final minutes in kAsmrSleepMinuteChoices)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _applying
                      ? null
                      : () {
                          _minutes.text = minutes.toString();
                          _clearError();
                        },
                  child: Text(asmrSleepDurationLabel(minutes)),
                ),
            ],
          ),
          DsTextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            semanticLabel: t.settings.asmrSleepCustomMinutes,
            onChanged: (_) => _clearError(),
          ),
          Text(
            _error ?? t.settings.asmrSleepRange,
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
          onPressed: _applying ? null : () => unawaited(_save()),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}
