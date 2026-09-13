import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/models/release_model.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/plugins/update.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ReleaseHistoryLoader = Future<List<ReleaseModel>> Function();
typedef ReleaseHistoryExternalLauncher = Future<bool> Function(Uri uri);
typedef ReleaseHistoryDownloadHandler = Future<void> Function(String url, {String? fileName});

const _releaseHistoryHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
  'Accept': 'application/json,text/plain,*/*',
};

Future<List<ReleaseModel>> loadConfiguredReleaseHistory() async {
  final mirror = VersionUtil.mirror;
  final sourceUrls = SettingsService.to.app.useGitHubOriginForUpdates.v
      ? [mirror.rawUrl('assets/releases.json')]
      : mirror.mirrors('assets/releases.json');
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final urls = sourceUrls
      .map((source) {
        final uri = Uri.parse(source);
        return uri.replace(queryParameters: {...uri.queryParameters, 'ts': timestamp}).toString();
      })
      .toList(growable: false);
  final url = await RaceHttp.findFastestUrl(urls, headers: _releaseHistoryHeaders);
  if (url == null) throw StateError('No release history source responded');

  final response = await HttpClient.instance.getJson(url, header: _releaseHistoryHeaders);
  final decoded = response is String ? json.decode(response) : response;
  return parseReleaseHistoryPayload(decoded);
}

List<ReleaseModel> parseReleaseHistoryPayload(Object? decoded) {
  final rawReleases = switch (decoded) {
    List values => values,
    Map values when values['releases'] is List => values['releases'] as List,
    _ => null,
  };
  if (rawReleases == null) throw const FormatException('Invalid release history payload');

  final releases = <ReleaseModel>[];
  for (final entry in rawReleases) {
    if (entry is! Map) continue;
    final release = ReleaseModel.fromJson(Map<String, dynamic>.from(entry));
    if (release.version.trim().isEmpty) continue;
    releases.add(release);
  }
  releases.sort((left, right) {
    final byDate = right.date.compareTo(left.date);
    return byDate != 0 ? byDate : right.version.compareTo(left.version);
  });
  return List.unmodifiable(releases);
}

Uri? releaseHistoryWebUri(String rawUrl) => updateDownloadUri(rawUrl);

class VersionHistoryPage extends StatefulWidget {
  const VersionHistoryPage({super.key, this.releaseLoader, this.openExternalUrl, this.downloadRelease});

  final ReleaseHistoryLoader? releaseLoader;
  final ReleaseHistoryExternalLauncher? openExternalUrl;
  final ReleaseHistoryDownloadHandler? downloadRelease;

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> {
  final RxList<ReleaseModel> allReleased = <ReleaseModel>[].obs;
  final RxBool historyLoading = false.obs;
  final RxBool historyError = false.obs;
  final RxInt _selectedHistoryIndex = 0.obs;
  bool _downloadInProgress = false;

  @override
  void initState() {
    super.initState();
    unawaited(loadReleaseHistory());
  }

  Future<void> loadReleaseHistory({bool forceRefresh = false}) async {
    if (allReleased.isNotEmpty && !forceRefresh) return;
    if (historyLoading.value) return;

    final selectedIndex = _selectedHistoryIndex.value;
    final selectedVersion = selectedIndex >= 0 && selectedIndex < allReleased.length
        ? allReleased[selectedIndex].version
        : null;
    historyLoading.value = true;
    historyError.value = false;
    try {
      final releases = await (widget.releaseLoader ?? loadConfiguredReleaseHistory)();
      if (!mounted) return;
      allReleased.assignAll(releases);
      final preservedIndex = selectedVersion == null
          ? -1
          : releases.indexWhere((release) => release.version == selectedVersion);
      _selectedHistoryIndex.value = preservedIndex >= 0 ? preservedIndex : 0;
    } catch (_) {
      if (!mounted) return;
      historyError.value = true;
      if (allReleased.isNotEmpty) _showMessage(context, 'version_history_load_failed');
    } finally {
      if (mounted) historyLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScale = mediaQuery.textScaler.scale(1);
    final isDesktopLayout = screenWidth > 760 && textScale <= 1.5;
    final toolbarHeight = textScale <= 1.5 ? kToolbarHeight : math.min(152.0, 44 + 36 * textScale);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: toolbarHeight,
        title: Text(i18n('version_history_desc'), maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Obx(
              () => IconButton(
                onPressed: historyLoading.value ? null : () => loadReleaseHistory(forceRefresh: true),
                icon: historyLoading.value
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Remix.refresh_line, size: 20),
                tooltip: i18n('refresh'),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final versions = allReleased.toList(growable: false);
        final loading = historyLoading.value;
        if (loading && versions.isEmpty) return const AppStatusView(type: AppStatusType.loading);
        if (historyError.value && versions.isEmpty) {
          return AppStatusView(
            type: AppStatusType.error,
            onButtonPressed: () => loadReleaseHistory(forceRefresh: true),
          );
        }
        if (versions.isEmpty) return const AppStatusView(type: AppStatusType.empty);

        final selectedIndex = math.min(_selectedHistoryIndex.value, versions.length - 1);
        final content = isDesktopLayout
            ? _buildDesktopHistory(context, versions, selectedIndex)
            : _buildMobileHistory(context, versions);
        return Stack(
          children: [
            Positioned.fill(child: content),
            if (loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(key: ValueKey('release-history-refresh-progress'), minHeight: 2),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildDesktopHistory(BuildContext context, List<ReleaseModel> versions, int selectedIndex) {
    final theme = Theme.of(context);
    return Row(
      key: const ValueKey('release-history-desktop-layout'),
      children: [
        Container(
          width: 320,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: 1)),
          ),
          child: ListView.builder(
            key: const ValueKey('release-history-desktop-list'),
            physics: const PureLiveScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final item = versions[index];
              final isCurrent = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: ValueKey('release-history-desktop-${item.version}'),
                  onTap: () => _selectedHistoryIndex.value = index,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCurrent ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'v${item.version}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.date,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Remix.arrow_right_s_line,
                          size: 16,
                          color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _DesktopChangelogDetailPanel(
            key: ValueKey('release-history-detail-${versions[selectedIndex].version}'),
            item: versions[selectedIndex],
            isDark: Theme.of(context).brightness == Brightness.dark,
            onOpenRelease: _releaseAction(context, versions[selectedIndex].github),
            onCopy: (file) => _copyDownloadLink(context, file),
            onDownload: (file) => _confirmDownload(context, file),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHistory(BuildContext context, List<ReleaseModel> versions) {
    final theme = Theme.of(context);
    return ListView.separated(
      key: const ValueKey('release-history-mobile-list'),
      physics: const PureLiveScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: versions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = versions[index];
        final fileSize = item.files.isNotEmpty ? item.files.first.size : '--';
        return InkWell(
          key: ValueKey('release-history-mobile-${item.version}'),
          onTap: () => _showMobileDetailsDialog(context, item),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 380 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
                if (stacked) {
                  return Column(
                    key: ValueKey('release-history-mobile-stacked-${item.version}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _VersionBadge(version: item.version)),
                          const SizedBox(width: 8),
                          Icon(Remix.arrow_right_s_line, size: 18, color: theme.colorScheme.outline),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(item.date, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                        i18n('version_file_size', args: {'size': fileSize}),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    _VersionBadge(version: item.version),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.date, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(
                            i18n('version_file_size', args: {'size': fileSize}),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Remix.arrow_right_s_line, size: 18, color: theme.colorScheme.outline),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMobileDetailsDialog(BuildContext context, ReleaseModel item) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final dialogHeight = math.max(
          240.0,
          math.min(640.0, mediaQuery.size.height - mediaQuery.padding.vertical - 48),
        );
        return SafeArea(
          child: Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            child: SizedBox(
              width: math.min(680, mediaQuery.size.width - 32),
              height: dialogHeight,
              child: SingleChildScrollView(
                key: const ValueKey('release-history-detail-scroll'),
                physics: const PureLiveScrollPhysics(),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VersionAuthorHeaderWidget(item: item, onOpenRelease: _releaseAction(dialogContext, item.github)),
                    const SizedBox(height: 8),
                    _VersionChangelogAndFilesWidget(
                      item: item,
                      isDark: Theme.of(dialogContext).brightness == Brightness.dark,
                      onCopy: (file) => _copyDownloadLink(dialogContext, file),
                      onDownload: (file) => _confirmDownload(dialogContext, file),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const ValueKey('release-history-close-details'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          i18n('close'),
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  VoidCallback? _releaseAction(BuildContext context, String rawUrl) {
    final uri = releaseHistoryWebUri(rawUrl);
    return uri == null ? null : () => _openRelease(context, uri);
  }

  Future<void> _openRelease(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await (widget.openExternalUrl?.call(uri) ?? launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (context.mounted && !opened) _showMessage(context, 'external_browser_not_opened');
  }

  Future<void> _copyDownloadLink(BuildContext context, ReleaseFileModel file) async {
    final uri = releaseHistoryWebUri(file.url);
    if (uri == null) return;
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (context.mounted) _showMessage(context, 'copied_to_clipboard');
  }

  Future<void> _confirmDownload(BuildContext context, ReleaseFileModel file) async {
    if (_downloadInProgress || !mounted || !context.mounted) return;
    final uri = releaseHistoryWebUri(file.url);
    if (uri == null) return;
    _downloadInProgress = true;
    try {
      final declaredName = file.name.trim();
      final pathName = uri.pathSegments.reversed
          .map((segment) => segment.trim())
          .firstWhere((segment) => segment.isNotEmpty, orElse: () => '');
      final displayName = declaredName.isNotEmpty
          ? declaredName
          : pathName.isNotEmpty
          ? pathName
          : i18n('version_history_unnamed_file');
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(i18n('download')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('open_download_confirm_named', args: {'name': displayName})),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(i18n('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(i18n('download'), textAlign: TextAlign.center),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || !context.mounted) return;

      final handler = widget.downloadRelease;
      if (handler != null) {
        await handler(uri.toString(), fileName: file.name);
      } else {
        await downloadAndInstallApk(uri.toString(), fileName: file.name);
      }
    } catch (_) {
      if (mounted && context.mounted) _showMessage(context, 'version_history_download_failed');
    } finally {
      _downloadInProgress = false;
    }
  }

  void _showMessage(BuildContext context, String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n(key))));
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'v$version',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _DesktopChangelogDetailPanel extends StatelessWidget {
  const _DesktopChangelogDetailPanel({
    super.key,
    required this.item,
    required this.isDark,
    required this.onOpenRelease,
    required this.onCopy,
    required this.onDownload,
  });

  final ReleaseModel item;
  final bool isDark;
  final VoidCallback? onOpenRelease;
  final ValueChanged<ReleaseFileModel> onCopy;
  final ValueChanged<ReleaseFileModel> onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VersionAuthorHeaderWidget(item: item, onOpenRelease: onOpenRelease),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                physics: const PureLiveScrollPhysics(),
                child: _VersionChangelogAndFilesWidget(
                  item: item,
                  isDark: isDark,
                  onCopy: onCopy,
                  onDownload: onDownload,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionAuthorHeaderWidget extends StatelessWidget {
  const _VersionAuthorHeaderWidget({required this.item, required this.onOpenRelease});

  final ReleaseModel item;
  final VoidCallback? onOpenRelease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReleaseAvatar(url: item.author.avatar),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v${item.version}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                i18n('version_published_at', args: {'date': item.date}),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('release-history-open-release'),
            onPressed: onOpenRelease,
            icon: const Icon(Remix.link, size: 16),
            label: Text(i18n('version_history_open_release'), textAlign: TextAlign.center),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: identity),
        IconButton(
          key: const ValueKey('release-history-open-release'),
          tooltip: i18n('version_history_open_release'),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          onPressed: onOpenRelease,
          icon: const Icon(Remix.link, size: 16),
        ),
      ],
    );
  }
}

class _ReleaseAvatar extends StatelessWidget {
  const _ReleaseAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = releaseHistoryWebUri(url);
    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: uri == null
          ? Icon(Remix.user_line, size: 18, color: theme.colorScheme.onSurfaceVariant)
          : ClipOval(
              child: Image.network(
                uri.toString(),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Remix.user_line, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
    );
  }
}

class _VersionChangelogAndFilesWidget extends StatelessWidget {
  const _VersionChangelogAndFilesWidget({
    required this.item,
    required this.isDark,
    required this.onCopy,
    required this.onDownload,
  });

  final ReleaseModel item;
  final bool isDark;
  final ValueChanged<ReleaseFileModel> onCopy;
  final ValueChanged<ReleaseFileModel> onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: MarkdownBlock(
            data: item.changelog,
            config: baseConfig.copy(
              configs: [
                PConfig(
                  textStyle:
                      theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5) ??
                      const TextStyle(),
                ),
              ],
            ),
          ),
        ),
        if (item.files.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(i18n('download_files'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (var index = 0; index < item.files.length; index++)
            _ReleaseFileCard(
              key: ValueKey('release-history-file-$index'),
              file: item.files[index],
              onCopy: () => onCopy(item.files[index]),
              onDownload: () => onDownload(item.files[index]),
            ),
        ],
      ],
    );
  }
}

class _ReleaseFileCard extends StatelessWidget {
  const _ReleaseFileCard({super.key, required this.file, required this.onCopy, required this.onDownload});

  final ReleaseFileModel file;
  final VoidCallback onCopy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLink = releaseHistoryWebUri(file.url) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final compact = constraints.maxWidth < 420 || textScale > 1.5;
          final verticalActions = constraints.maxWidth < 300 || textScale > 2;
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Remix.box_3_line, color: theme.colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: compact ? null : 3,
                      overflow: compact ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i18n('version_downloads_count', args: {'size': file.size, 'count': file.downloads.toString()}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (!compact) {
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: i18n('copy_link'),
                  style: _fileActionStyle(theme),
                  onPressed: hasLink ? onCopy : null,
                  icon: const Icon(Remix.file_copy_2_fill, size: 16),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: i18n('download'),
                  style: _fileActionStyle(theme),
                  onPressed: hasLink ? onDownload : null,
                  icon: const Icon(Remix.download_2_line, size: 16),
                ),
              ],
            );
          }

          final copyButton = Tooltip(
            message: i18n('copy_link'),
            child: OutlinedButton.icon(
              onPressed: hasLink ? onCopy : null,
              icon: const Icon(Remix.file_copy_2_fill, size: 16),
              label: Text(i18n('copy_link'), textAlign: TextAlign.center),
            ),
          );
          final downloadButton = Tooltip(
            message: i18n('download'),
            child: OutlinedButton.icon(
              onPressed: hasLink ? onDownload : null,
              icon: const Icon(Remix.download_2_line, size: 16),
              label: Text(i18n('download'), textAlign: TextAlign.center),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: 10),
              if (verticalActions) ...[
                copyButton,
                const SizedBox(height: 8),
                downloadButton,
              ] else
                Row(
                  children: [
                    Expanded(child: copyButton),
                    const SizedBox(width: 8),
                    Expanded(child: downloadButton),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  ButtonStyle _fileActionStyle(ThemeData theme) {
    return IconButton.styleFrom(
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      foregroundColor: theme.colorScheme.primary,
    );
  }
}
