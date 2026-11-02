import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pure_live/features/lan_sync/application/lan_sync_providers.dart';
import 'package:pure_live/features/lan_sync/data/sync_scopes.dart';
import 'package:pure_live/l10n/translations.dart';

/// The scope's name as the pane shows it.
String lanSyncScopeLabel(Translations t, LanSyncScope scope) => switch (scope) {
  LanSyncScope.favorites => t.settings.lanSyncScopeFavorites,
  LanSyncScope.areaFollows => t.settings.lanSyncScopeAreaFollows,
  LanSyncScope.history => t.settings.lanSyncScopeHistory,
  LanSyncScope.recordings => t.settings.lanSyncScopeRecordings,
  LanSyncScope.iptv => t.settings.lanSyncScopeIptv,
  LanSyncScope.multiview => t.settings.lanSyncScopeMultiview,
  LanSyncScope.settingsAppearance => t.settings.lanSyncScopeAppearance,
  LanSyncScope.settingsPlayback => t.settings.lanSyncScopePlayback,
  LanSyncScope.settingsDanmaku => t.settings.lanSyncScopeDanmaku,
  LanSyncScope.settingsMusic => t.settings.lanSyncScopeMusic,
  LanSyncScope.settingsRecorder => t.settings.lanSyncScopeRecorder,
  LanSyncScope.settingsModules => t.settings.lanSyncScopeModules,
  LanSyncScope.secrets => t.settings.lanSyncScopeSecrets,
};

/// The scope's one-line description.
String lanSyncScopeDescription(Translations t, LanSyncScope scope) => switch (scope) {
  LanSyncScope.favorites => t.settings.lanSyncScopeFavoritesDesc,
  LanSyncScope.areaFollows => t.settings.lanSyncScopeAreaFollowsDesc,
  LanSyncScope.history => t.settings.lanSyncScopeHistoryDesc,
  LanSyncScope.recordings => t.settings.lanSyncScopeRecordingsDesc,
  LanSyncScope.iptv => t.settings.lanSyncScopeIptvDesc,
  LanSyncScope.multiview => t.settings.lanSyncScopeMultiviewDesc,
  LanSyncScope.settingsAppearance => t.settings.lanSyncScopeAppearanceDesc,
  LanSyncScope.settingsPlayback => t.settings.lanSyncScopePlaybackDesc,
  LanSyncScope.settingsDanmaku => t.settings.lanSyncScopeDanmakuDesc,
  LanSyncScope.settingsMusic => t.settings.lanSyncScopeMusicDesc,
  LanSyncScope.settingsRecorder => t.settings.lanSyncScopeRecorderDesc,
  LanSyncScope.settingsModules => t.settings.lanSyncScopeModulesDesc,
  LanSyncScope.secrets => t.settings.lanSyncScopeSecretsDesc,
};

/// The scope's glyph.
DsIconData lanSyncScopeIcon(LanSyncScope scope) => switch (scope) {
  LanSyncScope.favorites => DsIcons.heart,
  LanSyncScope.areaFollows => DsIcons.layoutGrid,
  LanSyncScope.history => DsIcons.history,
  LanSyncScope.recordings => DsIcons.video,
  LanSyncScope.iptv => DsIcons.tv,
  LanSyncScope.multiview => DsIcons.layoutGrid,
  LanSyncScope.settingsAppearance => DsIcons.palette,
  LanSyncScope.settingsPlayback => DsIcons.play,
  LanSyncScope.settingsDanmaku => DsIcons.messageSquare,
  LanSyncScope.settingsMusic => DsIcons.music,
  LanSyncScope.settingsRecorder => DsIcons.circleDot,
  LanSyncScope.settingsModules => DsIcons.layers,
  LanSyncScope.secrets => DsIcons.keyRound,
};

/// Opens the grants of one paired [trust]: per scope this device shares,
/// whether the peer may read it from us and write it to us. Saving writes
/// the trust record; the peer learns the new grants on its next request.
///
/// The panel is the kit's own sheet: a dialog on a wide window, a bottom
/// sheet on a narrow one, a focusable list on a TV.
Future<bool> showLanSyncGrantsPanel(
  BuildContext context, {
  required LanSyncRuntime runtime,
  required DeviceTrust trust,
}) async {
  final saved = await showDsPanel<bool>(
    context: context,
    builder: (context) => _GrantsPanel(runtime: runtime, trust: trust),
  );
  return saved ?? false;
}

final class _GrantsPanel extends StatefulWidget {
  const _GrantsPanel({required this.runtime, required this.trust});

  final LanSyncRuntime runtime;
  final DeviceTrust trust;

  @override
  State<_GrantsPanel> createState() => _GrantsPanelState();
}

final class _GrantsPanelState extends State<_GrantsPanel> {
  late Set<String> _read = {...widget.trust.readScopes};
  late Set<String> _write = {...widget.trust.writeScopes};
  bool _saving = false;

  List<LanSyncScope> get _scopes => [
    for (final scope in LanSyncScope.values)
      if (widget.runtime.scopes.contains(scope)) scope,
  ];

  void _toggle(Set<String> set, String id) => setState(() {
    if (!set.remove(id)) set.add(id);
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.runtime.trustService.updateGrants(widget.trust.deviceId, readScopes: _read, writeScopes: _write);
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        showDsToast(context: context, title: context.t.settings.lanSyncGrantsFailed, status: DsStatus.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    final scopes = _scopes;
    return DsPanel(
      title: Text(t.settings.lanSyncGrantsTitle(name: widget.trust.displayName)),
      footer: DsButton(
        onPressed: _saving ? null : () => unawaited(_save()),
        child: _saving ? const DsSpinner() : Text(t.common.save),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(t.settings.lanSyncGrantsIntro, style: theme.typography.body.copyWith(color: colors.textMuted)),
          Row(
            spacing: DsSpace.s8,
            children: [
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => setState(() {
                  _read = {for (final scope in scopes) scope.id};
                  _write = {for (final scope in scopes) scope.id};
                }),
                child: Text(t.settings.lanSyncGrantAll),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => setState(() {
                  _read = {};
                  _write = {};
                }),
                child: Text(t.settings.lanSyncGrantNone),
              ),
            ],
          ),
          // One block per scope: its name, then the two grants side by side.
          for (final scope in scopes)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    DsIcon(lanSyncScopeIcon(scope), size: 16),
                    Text(lanSyncScopeLabel(t, scope), style: theme.typography.bodyStrong),
                  ],
                ),
                Text(lanSyncScopeDescription(t, scope), style: muted),
                Row(
                  spacing: DsSpace.s16,
                  children: [
                    DsCheckbox(
                      value: _read.contains(scope.id),
                      onChanged: (_) => _toggle(_read, scope.id),
                      label: Text(t.settings.lanSyncReadAllowed),
                    ),
                    DsCheckbox(
                      value: _write.contains(scope.id),
                      onChanged: (_) => _toggle(_write, scope.id),
                      label: Text(t.settings.lanSyncWriteAllowed),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
