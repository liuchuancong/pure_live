import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:markdown_widget/config/configs.dart';

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

  List<VersionHistoryModel> _loadHistoryList() {
    return VersionUtil.allReleased
        .map(
          (e) =>
              VersionHistoryModel(version: e['tag_name'].toString().replaceAll('v', ''), updateBody: e['body'] ?? ''),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

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

        final List<VersionHistoryModel> versions = _loadHistoryList();

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

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primaryContainer, width: 3),
                      ),
                    ),
                    if (index != versions.length - 1)
                      Container(width: 2, height: 140, color: theme.dividerColor.withValues(alpha: 0.1)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'v${item.version}',
                          style: AppTextStyles.t18.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        context.buildModernCard([
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(
                              width: double.infinity,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: MarkdownBlock(
                                  data: item.updateBody,
                                  config: baseConfig.copy(
                                    configs: [
                                      PConfig(textStyle: textTheme.bodyMedium ?? const TextStyle()),
                                      H1Config(
                                        style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      H2Config(
                                        style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      H3Config(
                                        style: (textTheme.titleSmall ?? const TextStyle()).copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      PreConfig(
                                        textStyle:
                                            textTheme.bodySmall?.copyWith(fontFamily: 'monospace') ??
                                            const TextStyle(fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}

class VersionHistoryModel {
  final String version;
  final String updateBody;
  VersionHistoryModel({required this.version, required this.updateBody});
}
