import 'dart:convert';

import 'package:flutter_json/flutter_json.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/backup/backup_controller.dart';
import 'package:remixicon/remixicon.dart';

class LocalConfigPreviewPage extends StatefulWidget {
  const LocalConfigPreviewPage({super.key});

  @override
  State<LocalConfigPreviewPage> createState() => _LocalConfigPreviewPageState();
}

class _LocalConfigPreviewPageState extends State<LocalConfigPreviewPage> {
  Map<String, dynamic> _configData = {};
  bool _isLoading = true;
  String _errorMsg = '';

  int _favoriteCount = 0;
  int _historyCount = 0;
  int _tagCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalConfig();
  }

  void _loadLocalConfig() {
    try {
      final data = BackupController.to.exportAllSettings();
      final favoriteData = data['favorite'] as Map<String, dynamic>? ?? {};
      final favoriteRooms = favoriteData['favoriteRooms'] as List? ?? [];
      final historyData = data['history'] as Map<String, dynamic>? ?? {};
      final historyList = historyData['historyRooms'] ?? historyData['historyList'] ?? [];
      final tagData = data['tags'] as Map<String, dynamic>? ?? {};
      final tagList = tagData['tags'] as List? ?? [];

      _favoriteCount = favoriteRooms.length;
      _historyCount = historyList is List ? historyList.length : 0;
      _tagCount = tagList.length;
      _configData = json.decode(json.encode(data)) as Map<String, dynamic>;
    } catch (error) {
      _errorMsg = error.toString();
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: AppStatusView(type: AppStatusType.loading)),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: AppStatusView(type: AppStatusType.error, title: _errorMsg),
        ),
      );
    }

    final backupVersion = _configData['backupVersion'] ?? 0;
    final moduleCount = BackupController.countConfigSections(_configData);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          i18n('local_config_preview'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: LayoutBuilder(
        builder: (context, viewportConstraints) {
          final rawPreviewHeight = (viewportConstraints.maxHeight * 0.7).clamp(320.0, 720.0).toDouble();
          return CustomScrollView(
            key: const ValueKey('local-config-scroll-view'),
            physics: const PureLiveScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildSummaryCard(context, theme: theme, backupVersion: backupVersion, moduleCount: moduleCount),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: context.buildGroupTitle(i18n('local_config_raw_preview')),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: rawPreviewHeight,
                  child: Container(
                    key: const ValueKey('local-config-raw-preview'),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: JsonWidget(json: _configData, initialExpandDepth: 2),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required ThemeData theme,
    required Object backupVersion,
    required int moduleCount,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = textScale > 1.5
            ? 1
            : constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const spacing = 8.0;

        final items = [
          _buildMeta(
            key: 'favorites',
            icon: Remix.heart_3_line,
            label: i18n('favorites'),
            value: '$_favoriteCount',
            theme: theme,
            isPrimaryColor: true,
          ),
          _buildMeta(
            key: 'history',
            icon: Remix.history_line,
            label: i18n('history'),
            value: '$_historyCount',
            theme: theme,
            isPrimaryColor: true,
          ),
          _buildMeta(
            key: 'tags',
            icon: Remix.price_tag_3_line,
            label: i18n('tags'),
            value: '$_tagCount',
            theme: theme,
            isPrimaryColor: true,
          ),
          _buildMeta(
            key: 'modules',
            icon: Remix.file_list_3_line,
            label: i18n('config_modules'),
            value: '$moduleCount',
            theme: theme,
          ),
        ];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15), width: 0.5),
          ),
          child: LayoutBuilder(
            builder: (context, contentConstraints) {
              final itemWidth = (contentConstraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Remix.settings_3_line, color: theme.colorScheme.onPrimaryContainer, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              i18n('local_backup_config'),
                              style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  'backup v$backupVersion',
                                  style: AppTextStyles.t11.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: items.map((item) => SizedBox(width: itemWidth, child: item)).toList(growable: false),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMeta({
    required String key,
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    bool isPrimaryColor = false,
  }) {
    final color = isPrimaryColor ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Container(
      key: ValueKey('local-config-meta-$key'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: isPrimaryColor ? theme.colorScheme.primary : theme.hintColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(label, style: AppTextStyles.t11.copyWith(color: theme.hintColor, height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
