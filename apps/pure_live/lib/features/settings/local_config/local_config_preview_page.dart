import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The local configuration preview — the reference's read-only "what is
/// actually stored on this device".
///
/// The reference dumps `BackupController.exportAllSettings()`; this build's
/// answer is the live set of persisted documents: the general preferences and
/// the appearance document, each rendered as the JSON its store holds. The
/// page writes nothing — it is the thing you screenshot when a setting "does
/// not seem to save".
final class LocalConfigPreviewPage extends ConsumerWidget {
  /// The page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final documents = <String, Map<String, Object?>>{
      t.settings.localConfigApp: ref.watch(appPreferencesProvider).toJson(),
      t.settings.localConfigAppearance: ref.watch(appearancePreferencesProvider).toJson(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return SettingsChrome(
      title: t.settings.localConfig,
      body: SettingsList(
      sections: [
        SettingsSection(
          tiles: [SettingsTile(leading: const Icon(Icons.info_outline), title: Text(t.settings.localConfigNote))],
        ),
        for (final entry in documents.entries)
          SettingsSection(
            title: Text(entry.key),
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SelectableText(
                    encoder.convert(entry.value),
                    style: PureTheme.of(context).text.caption.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(t.settings.localConfigCopy),
                onPressed: (_) => unawaited(
                  Clipboard.setData(ClipboardData(text: encoder.convert(entry.value))).then((_) {
                    if (context.mounted) {
                      PureToast.show(context, t.room.linkCopied);
                    }
                  }),
                ),
              ),
            ],
          ),
      ],
      ),
    );
  }
}
