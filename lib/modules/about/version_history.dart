import 'dart:convert';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/models/release_model.dart';

class VersionHistoryPage extends StatefulWidget {
  const VersionHistoryPage({super.key});

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> with SingleTickerProviderStateMixin {
  var allReleased = [].obs;

  RxBool historyLoading = false.obs;
  RxBool historyError = false.obs;
  final RxInt _selectedHistoryIndex = 0.obs;
  // 折叠状态管理
  final Map<String, RxBool> _expandMap = {};

  RxBool getExpandStatus(String version) {
    if (!_expandMap.containsKey(version)) {
      _expandMap[version] = false.obs;
    }
    return _expandMap[version]!;
  }

  @override
  void initState() {
    super.initState();
    loadReleaseHistory();
  }

  Future<void> loadReleaseHistory({bool forceRefresh = false}) async {
    if (allReleased.isNotEmpty && !forceRefresh) return;
    if (historyLoading.value) return;

    try {
      GitHubMirror mirror = GitHubMirror(owner: 'liuchuancong', repo: 'pure_live', branch: 'master');
      historyLoading.value = true;
      historyError.value = false;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urls = mirror.mirrors('assets/releases.json').map((e) => '$e?ts=$timestamp').toList();
      String? url = await RaceHttp.findFastestUrl(urls);
      if (url == null) {
        throw Exception("无法获取版本历史");
      }
      var result = await HttpClient.instance.getJson(
        url,
        header: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51',
          'Accept': 'application/json',
        },
      );
      allReleased.value = (List.from(json.decode(result) ?? []).map((e) => ReleaseModel.fromJson(e)).toList());
      allReleased.value.sort((a, b) => b.date.compareTo(a.date));
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      historyError.value = true;
    } finally {
      historyLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktopLayout = screenWidth > 760;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(i18n("version_history_desc")),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () => loadReleaseHistory(forceRefresh: true),
              icon: const Icon(Remix.refresh_line, size: 20),
              tooltip: i18n("refresh"),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (historyLoading.value) {
          return const AppStatusView(type: AppStatusType.loading);
        }

        final versions = allReleased.value;

        if (historyError.value && versions.isEmpty) {
          return AppStatusView(
            type: AppStatusType.error,
            onButtonPressed: () => loadReleaseHistory(forceRefresh: true),
          );
        }

        if (versions.isEmpty) {
          return const AppStatusView(type: AppStatusType.empty);
        }
        if (_selectedHistoryIndex.value >= versions.length) {
          _selectedHistoryIndex.value = 0;
        }

        if (isDesktopLayout) {
          return Row(
            children: [
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: 1),
                  ),
                ),
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: versions.length,
                  itemBuilder: (context, index) {
                    final item = versions[index];
                    return Obx(() {
                      final bool isCurrent = _selectedHistoryIndex.value == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
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
                              border: Border.all(
                                color: isCurrent ? theme.colorScheme.primary : Colors.transparent,
                                width: 1.5,
                              ),
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
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.date,
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
                    });
                  },
                ),
              ),
              Expanded(
                child: Obx(() {
                  final activeItem = versions[_selectedHistoryIndex.value];
                  return _DesktopChangelogDetailPanel(
                    item: activeItem,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  );
                }),
              ),
            ],
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: versions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = versions[index];
            final hasFiles = item.files.isNotEmpty;
            final String fileSize = hasFiles ? item.files.first.size : '--';

            return InkWell(
              onTap: () => _showMobileDetailsDialog(context, item, Theme.of(context).brightness == Brightness.dark),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'v${item.version}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.date, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(
                            i18n("version_file_size", args: {"size": fileSize}),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Remix.arrow_right_s_line, size: 18, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _showMobileDetailsDialog(BuildContext context, dynamic item, bool isDark) {
    final theme = Theme.of(context);

    Get.dialog(
      Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VersionAuthorHeaderWidget(item: item),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _VersionChangelogAndFilesWidget(item: item, isDark: isDark),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(Get.context!).pop();
                    },
                    child: Text(
                      i18n("close"),
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopChangelogDetailPanel extends StatelessWidget {
  final dynamic item;
  final bool isDark;

  const _DesktopChangelogDetailPanel({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VersionAuthorHeaderWidget(item: item),
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
                physics: const BouncingScrollPhysics(),
                child: _VersionChangelogAndFilesWidget(item: item, isDark: isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionAuthorHeaderWidget extends StatelessWidget {
  final dynamic item;

  const _VersionAuthorHeaderWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: NetworkImage(item.author.avatar),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('v${item.version}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                // 【Core Fix】: Localized published date text template wrapper
                i18n("version_published_at", args: {"date": item.date}),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          onPressed: () => launchUrlString(item.github),
          icon: const Icon(Remix.github_fill, size: 16),
        ),
      ],
    );
  }
}

class _VersionChangelogAndFilesWidget extends StatelessWidget {
  final dynamic item;
  final bool isDark;

  const _VersionChangelogAndFilesWidget({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          alignment: Alignment.topLeft,
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
          Text(i18n("download_files"), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...item.files
              .map<Widget>(
                (file) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: theme.colorScheme.surfaceContainer,
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Row(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              // 【Core Fix】: Localized dynamic download count template line
                              i18n(
                                "version_downloads_count",
                                args: {"size": file.size, "count": file.downloads.toString()},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        onPressed: () => launchUrlString(file.url),
                        icon: const Icon(Remix.download_2_line, size: 16),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ],
    );
  }
}
