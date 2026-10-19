import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/services/image_cache.dart' as image_cache;
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/features/settings/widgets/settings_rows.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The cache & data page (the reference's `CacheDataSettingsPage`): the
/// picture cache's size with its manual clear and its capped auto-clear, and
/// the watch history's size with its clear.
///
/// The size is the picture cache folder measured directly (`ImageCache`) —
/// the one cache this build fills; the download directory of the reference
/// has no download engine wired yet and stays out. The page rides the
/// history repository's change stream, so the count tracks clears made
/// elsewhere.
final class CacheDataPage extends ConsumerStatefulWidget {
  /// The cache & data page.
  const new({super.key});

  @override
  ConsumerState<CacheDataPage> createState() => _CacheDataPageState();
}

final class _CacheDataPageState extends ConsumerState<CacheDataPage> {
  int _count = 0;
  int? _cacheBytes;
  bool _measuring = false;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    unawaited(_measureCache());
    final repository = ref.read(historyRepositoryProvider);
    _count = repository.records.length;
    _changes = repository.changes.listen((_) {
      if (mounted) {
        setState(() => _count = repository.records.length);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _measureCache() async {
    if (_measuring) {
      return;
    }
    setState(() => _measuring = true);
    final bytes = await image_cache.ImageCache.sizeBytes();
    if (mounted) {
      setState(() {
        _cacheBytes = bytes;
        _measuring = false;
      });
    }
  }

  /// 清空缓存: empties the picture cache, reports the bytes it held.
  Future<void> _clearCache() async {
    final t = context.t;
    final freed = await image_cache.ImageCache.clear();
    if (mounted) {
      setState(() => _cacheBytes = 0);
      PureToast.show(
        context,
        t.settings.cacheCleared(count: ((freed ?? 0) / (1024 * 1024)).toStringAsFixed(1)),
        type: PureToastType.success,
      );
    }
    await _measureCache();
  }

  /// 立即刷新封面: empties the picture cache so every cover re-pulls on the
  /// next pass — the reference's row, which clears nothing but this cache.
  Future<void> _refreshCoversNow() async {
    await _clearCache();
  }

  Future<void> _confirmClear() async {
    final t = context.t;
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: t.history.clear,
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), child: Text(t.history.clearConfirm)),
      actions: (dialogContext) => [
        PureButton(
          label: t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: t.history.clear,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(historyRepositoryProvider).clear();
    if (mounted) {
      PureToast.show(context, context.t.settings.historyCleared, type: PureToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return SettingsChrome(
      title: t.settings.cacheAndData,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.sectionCache),
            tiles: [
              SettingsRowTile(
                row: PureListRow(
                  key: const ValueKey('cache-size-row'),
                  leading: const Icon(Icons.sd_storage_outlined, size: 22),
                  title: t.settings.currentCacheSize,
                  subtitle: _measuring
                      ? t.settings.cacheMeasuring
                      : t.settings.cacheSizeValue(count: ((_cacheBytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)),
                  trailing: PureIconButton(
                    key: const ValueKey('cache-size-refresh'),
                    icon: Icons.refresh,
                    tooltip: t.common.refresh,
                    onPressed: () => unawaited(_measureCache()),
                  ),
                ),
              ),
              SettingsTile(
                key: const ValueKey('cache-clear'),
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(t.settings.clearCache),
                description: Text(t.settings.clearCacheDesc),
                onPressed: (_) => unawaited(_clearCache()),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('cache-auto-clear'),
                leading: const Icon(Icons.compress_outlined),
                title: Text(t.settings.cacheAutoClear),
                description: Text(t.settings.cacheAutoClearDesc),
                initialValue: preferences.cacheAutoClear,
                onToggle: (value) => unawaited(update((p) => p.copyWith(cacheAutoClear: value))),
              ),
              SettingsTile.navigation(
                key: const ValueKey('cache-max-mb'),
                leading: const Icon(Icons.straighten_outlined),
                title: Text(t.settings.cacheLimit),
                value: Text(t.settings.mbValue(count: preferences.cacheMaxMB)),
                enabled: preferences.cacheAutoClear,
                onPressed: (_) => unawaited(
                  showSettingsChooser<int>(
                    context,
                    title: t.settings.cacheLimit,
                    current: preferences.cacheMaxMB,
                    options: [
                      for (final mb in const [256, 512, 1024, 2048, 4096]) (mb, t.settings.mbValue(count: mb)),
                    ],
                  ).then((picked) => picked == null ? null : update((p) => p.copyWith(cacheMaxMB: picked))),
                ),
              ),
              SettingsTile(
                key: const ValueKey('cache-refresh-covers'),
                leading: const Icon(Icons.collections_outlined),
                title: Text(t.settings.refreshCoversNow),
                description: Text(t.settings.refreshCoversNowDesc),
                onPressed: (_) => unawaited(_refreshCoversNow()),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.sectionData),
            tiles: [
              // The count is a reading, not a control, so it is a row without a
              // destination — the kit's navigation tile would grow a chevron
              // that promises a page that does not exist.
              SettingsRowTile(
                row: PureListRow(
                  leading: const Icon(Icons.history, size: 22),
                  title: t.settings.historyEntry,
                  subtitle: t.settings.historyCount(count: _count),
                ),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(t.settings.clearHistory),
                description: Text(t.settings.clearHistorySubtitle),
                onPressed: (_) => unawaited(_confirmClear()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
