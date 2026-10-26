import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/twitch_languages_provider.dart'
    show kTwitchLanguageCodes, kTwitchLegacyLanguages;
import 'package:pure_live/l10n/translations.dart';

/// The localized name of a Twitch broadcaster-language code.
String twitchLanguageLabel(Translations t, String code) => switch (code) {
  'zh' => t.settings.twitchLanguage_zh,
  'en' => t.settings.twitchLanguage_en,
  'ko' => t.settings.twitchLanguage_ko,
  'ja' => t.settings.twitchLanguage_ja,
  'es' => t.settings.twitchLanguage_es,
  'pt' => t.settings.twitchLanguage_pt,
  'de' => t.settings.twitchLanguage_de,
  'fr' => t.settings.twitchLanguage_fr,
  'ru' => t.settings.twitchLanguage_ru,
  'it' => t.settings.twitchLanguage_it,
  'th' => t.settings.twitchLanguage_th,
  'vi' => t.settings.twitchLanguage_vi,
  'id' => t.settings.twitchLanguage_id,
  'tr' => t.settings.twitchLanguage_tr,
  'pl' => t.settings.twitchLanguage_pl,
  _ => code,
};

/// A one-line summary of the current filter for the row.
String twitchLanguagesSummary(Translations t, List<String> codes) => codes.isEmpty
    ? t.settings.twitchAllLanguages
    : [for (final code in codes) twitchLanguageLabel(t, code)].join('、');

/// Opens the language picker; answers the chosen codes, or null when the
/// viewer cancelled.
Future<List<String>?> showTwitchLanguagesDialog(BuildContext context, {required List<String> initial}) =>
    showDsDialog<List<String>>(
      context: context,
      builder: (context) => _TwitchLanguagesDialog(initial: initial),
    );

final class _TwitchLanguagesDialog extends ConsumerStatefulWidget {
  const _TwitchLanguagesDialog({required this.initial});

  final List<String> initial;

  @override
  ConsumerState<_TwitchLanguagesDialog> createState() => _TwitchLanguagesDialogState();
}

final class _TwitchLanguagesDialogState extends ConsumerState<_TwitchLanguagesDialog> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(t.settings.twitchLanguages),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: () => Navigator.of(context).pop([
            for (final code in kTwitchLanguageCodes)
              if (_selected.contains(code)) code,
          ]),
          child: Text(t.common.save),
        ),
      ],
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          Text(
            t.settings.twitchLanguagesHint,
            style: theme.typography.small.copyWith(color: colors.textMuted),
          ),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => setState(_selected.clear),
                child: Text(t.settings.twitchAllLanguages),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => setState(() => _selected
                  ..clear()
                  ..addAll(kTwitchLegacyLanguages)),
                child: Text(t.settings.twitchLegacyLanguages),
              ),
            ],
          ),
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final code in kTwitchLanguageCodes)
                DsButton(
                  variant: _selected.contains(code) ? DsButtonVariant.primary : DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => setState(() {
                    if (!_selected.remove(code)) _selected.add(code);
                  }),
                  child: Text(twitchLanguageLabel(t, code)),
                ),
            ],
          ),
        ],
      ),
      style: const DsDialogStyle(width: 520),
    );
  }
}
