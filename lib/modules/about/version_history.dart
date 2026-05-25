import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:url_launcher/url_launcher_string.dart';

class VersionHistoryPage extends StatefulWidget {
  const VersionHistoryPage({super.key});

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> {
  @override
  void initState() {
    super.initState();
    VersionUtil().loadReleaseHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    final versions = VersionUtil.allReleased;
    return Scaffold(
      appBar: AppBar(title: Text(i18n("version_history_desc"))),
      body: Obx(() {
        if (VersionUtil.historyLoading.value) {
          return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
        }

        if (VersionUtil.historyError.value && VersionUtil.allReleased.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Remix.error_warning_line, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(i18n("history_load_failed"), style: AppTextStyles.t14.copyWith(color: theme.hintColor)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => VersionUtil().loadReleaseHistory(forceRefresh: true),
                  icon: const Icon(Remix.refresh_line, size: 16),
                  label: Text(i18n("retry")),
                ),
              ],
            ),
          );
        }

        if (versions.isEmpty) {
          return EmptyView(
            icon: Remix.history_line,
            title: i18n("empty_history_title"),
            subtitle: i18n("empty_history_subtitle"),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: versions.length,
          itemBuilder: (context, index) {
            final item = versions[index];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: context.buildModernCard([
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// 顶部信息
                        Row(
                          children: [
                            CircleAvatar(radius: 18, backgroundImage: NetworkImage(item.author.avatar)),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'v${item.version}',
                                    style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold),
                                  ),

                                  const SizedBox(height: 2),

                                  Text(item.date, style: AppTextStyles.t12.copyWith(color: theme.hintColor)),
                                ],
                              ),
                            ),

                            IconButton(
                              onPressed: () {
                                launchUrlString(item.github);
                              },
                              icon: const Icon(Remix.github_fill),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        /// 更新日志
                        MarkdownBlock(
                          data: item.changelog,
                          config: baseConfig.copy(
                            configs: [PConfig(textStyle: textTheme.bodyMedium ?? const TextStyle())],
                          ),
                        ),

                        /// 安装包列表
                        if (item.files.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          Text(i18n("download_files"), style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),

                          const SizedBox(height: 12),

                          ...item.files.map(
                            (file) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              ),
                              child: Row(
                                children: [
                                  Icon(Remix.android_fill, color: theme.colorScheme.primary),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(file.name, style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w600)),

                                        const SizedBox(height: 2),

                                        Text(
                                          '${file.size} · ${file.downloads} downloads',
                                          style: AppTextStyles.t12.copyWith(color: theme.hintColor),
                                        ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: () {
                                      launchUrlString(file.url);
                                    },
                                    icon: const Icon(Remix.download_2_line),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      }),
    );
  }
}
