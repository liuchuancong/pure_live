import 'dart:async';
import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';

class CacheDataSettingsPage extends StatefulWidget {
  const CacheDataSettingsPage({super.key});

  @override
  State<CacheDataSettingsPage> createState() => _CacheDataSettingsPageState();
}

class _CacheDataSettingsPageState extends State<CacheDataSettingsPage> {
  bool _clearTransactionBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCacheSize(showFailure: false));
  }

  void _showCacheMessage(String message, {bool failed = false}) {
    if (!mounted) return;
    Get.snackbar(failed ? i18n('error') : i18n('done'), message, snackPosition: SnackPosition.bottom);
  }

  Future<void> _refreshThumbnails() async {
    try {
      await SettingsService.to.cache.refreshImageCache();
      _showCacheMessage(i18n('thumbnails_refreshed'));
    } catch (_) {
      _showCacheMessage(i18n('cache_operation_failed'), failed: true);
    }
  }

  Future<void> _refreshCacheSize({bool showFailure = true}) async {
    try {
      if (showFailure) {
        await SettingsService.to.cache.handleManualRefresh();
      } else {
        await SettingsService.to.cache.getCacheSize();
      }
    } catch (_) {
      if (showFailure) _showCacheMessage(i18n('cache_operation_failed'), failed: true);
    }
  }

  Future<void> _confirmClearCache(ThemeData theme) async {
    if (_clearTransactionBusy || !mounted) return;
    setState(() => _clearTransactionBusy = true);
    final pageContext = context;
    try {
      final ok = await showDialog<bool>(
        context: pageContext,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(i18n('confirm_clear_local_cache')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('confirm_clear_local_cache_desc')),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
              child: Text(i18n('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
              child: Text(i18n('clear')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      try {
        final result = await SettingsService.to.cache.clearCache();
        if (result.succeeded) {
          _showCacheMessage(i18n('cache_cleared'));
        } else {
          _showCacheMessage(
            i18n('cache_clear_incomplete', args: {'size': result.remainingSizeMB.toStringAsFixed(2)}),
            failed: true,
          );
        }
      } catch (_) {
        _showCacheMessage(i18n('cache_operation_failed'), failed: true);
      }
    } finally {
      if (mounted) setState(() => _clearTransactionBusy = false);
    }
  }

  Widget _progressIndicator(Color color) =>
      SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color));

  /// Updates the shared download directory used by app updates, downloaded
  /// files and font bundles.
  Future<void> _pickDownloadDirectory() async {
    try {
      final selected = await FileUtils.pickDirectory();
      if (selected == null || selected.trim().isEmpty) return;

      final cache = SettingsService.to.cache;
      await cache.setDownloadDirectory(selected);

      // An app-sandbox default never needs this; a user-selected public folder
      // may still lack the Android "All files access" grant.
      if (!await CacheController.isCustomDownloadDirectoryUsable()) {
        await FileUtils.requestStoragePermission();
      }
      if (!await CacheController.isCustomDownloadDirectoryUsable()) {
        _showCacheMessage(i18n('download_directory_permission_hint'), failed: true);
        if (Platform.isAndroid) openAppSettings();
        return;
      }

      _showCacheMessage(i18n('download_directory_updated'));
    } catch (_) {
      _showCacheMessage(i18n('download_directory_pick_failed'), failed: true);
    }
  }

  Future<void> _resetDownloadDirectory() async {
    try {
      await SettingsService.to.cache.useDefaultDownloadDirectory();
      _showCacheMessage(i18n('download_directory_updated'));
    } catch (_) {
      _showCacheMessage(i18n('download_directory_pick_failed'), failed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("cache_and_data"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("cache_and_data")),
          context.buildModernCard([
            Obx(() {
              final size = SettingsService.to.cache.cacheSizeMB.value;
              final turns = SettingsService.to.cache.refreshTurns.value;
              final busy = SettingsService.to.cache.isBusy;
              return context.buildTile(
                icon: Remix.database_2_line,
                title: i18n("current_cache_size"),
                subtitle: "",
                onTap: busy ? null : _refreshCacheSize,
                stackTrailingOnNarrow: true,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "${size.toStringAsFixed(2)} MB",
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                    if (SettingsService.to.cache.isScanning.value)
                      _progressIndicator(theme.colorScheme.primary)
                    else
                      AnimatedRotation(
                        turns: turns,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        child: Icon(Remix.refresh_line, size: 16, color: theme.hintColor.withValues(alpha: 0.6)),
                      ),
                  ],
                ),
              );
            }),
            Obx(
              () => context.buildTile(
                icon: Remix.image_2_line,
                title: i18n('refresh_thumbnails'),
                subtitle: i18n('refresh_thumbnails_desc'),
                trailing: SettingsService.to.cache.isRefreshingImages.value
                    ? _progressIndicator(theme.colorScheme.primary)
                    : const Icon(Icons.refresh_rounded),
                onTap: SettingsService.to.cache.isBusy ? null : _refreshThumbnails,
              ),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.delete_bin_6_line,
                title: i18n('clear_local_cache'),
                subtitle: i18n('clear_local_cache_desc'),
                isLong: true,
                trailing: SettingsService.to.cache.isClearing.value
                    ? _progressIndicator(theme.colorScheme.error)
                    : Icon(Remix.delete_bin_6_line, color: theme.colorScheme.error),
                onTap: SettingsService.to.cache.isBusy || _clearTransactionBusy
                    ? null
                    : () => _confirmClearCache(theme),
              ),
            ),
            Obx(() {
              final customDirectory = SettingsService.to.cache.downloadDirectory.value.trim();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  context.buildTile(
                    icon: Remix.folder_2_line,
                    title: i18n('download_directory'),
                    subtitle: customDirectory.isEmpty ? i18n('download_directory_default_label') : customDirectory,
                    isLong: true,
                    onTap: _pickDownloadDirectory,
                  ),
                  if (customDirectory.isNotEmpty)
                    context.buildTile(
                      icon: Remix.refresh_line,
                      title: i18n('download_directory_reset'),
                      onTap: _resetDownloadDirectory,
                    ),
                ],
              );
            }),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
