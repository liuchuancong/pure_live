import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart';

/// The station's own settings: the companion service it asks — where it
/// listens, the key it presents — and the rendition an episode opens with.
final class HongguoSettingsPane extends ConsumerStatefulWidget {
  /// The pane shown under Settings → 红果短剧.
  const HongguoSettingsPane({super.key});

  @override
  ConsumerState<HongguoSettingsPane> createState() => _HongguoSettingsPaneState();
}

final class _HongguoSettingsPaneState extends ConsumerState<HongguoSettingsPane> {
  late final TextEditingController _server = TextEditingController()..text = ref.read(hongguoSettingsProvider).serverUrl;
  late final TextEditingController _key = TextEditingController()..text = ref.read(hongguoSettingsProvider).apiKey;

  /// The test row's one-line outcome, until the next test clears it.
  String? _testResult;

  bool _testing = false;

  @override
  void dispose() {
    _server.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await ref.read(hongguoClientProvider).ping();
      _testResult = mounted ? context.t.settings.hongguoTestOk : '';
    } on Object catch (error) {
      _testResult = error is HongguoFailure ? error.message : '$error';
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(hongguoSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.hongguoService),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.server),
              title: t.settings.hongguoServer,
              description: t.settings.hongguoServerDesc,
              control: SizedBox(
                width: 260,
                child: DsTextField(
                  controller: _server,
                  semanticLabel: t.settings.hongguoServer,
                  keyboardType: TextInputType.url,
                  onSubmitted: (value) => unawaited(ref.read(hongguoSettingsProvider.notifier).setServerUrl(value)),
                ),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.keyRound),
              title: t.settings.hongguoApiKey,
              description: t.settings.hongguoApiKeyDesc,
              control: SizedBox(
                width: 260,
                child: DsTextField(
                  controller: _key,
                  semanticLabel: t.settings.hongguoApiKey,
                  onSubmitted: (value) => unawaited(ref.read(hongguoSettingsProvider.notifier).setApiKey(value)),
                ),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.activity),
              title: Text(t.settings.hongguoTest),
              description: _testResult == null ? Text(t.settings.hongguoTestDesc) : Text(_testResult!),
              onPressed: _testing ? null : () => unawaited(_test()),
            ),
          ],
        ),
        DsListSection(
          children: [
            SettingsChoiceRow<HongguoQualityChoice>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.hongguoQuality,
              description: t.settings.hongguoQualityDesc,
              value: settings.quality,
              options: [
                for (final choice in HongguoQualityChoice.values) DsSelectOption(value: choice, label: choice.label(t)),
              ],
              onChanged: (choice) => unawaited(ref.read(hongguoSettingsProvider.notifier).setQuality(choice)),
            ),
          ],
        ),
      ],
    );
  }
}
