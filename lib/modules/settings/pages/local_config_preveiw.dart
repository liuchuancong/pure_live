import 'dart:convert';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter_json/flutter_json.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';

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

  Future<void> _loadLocalConfig() async {
    try {
      final backupCtrl = BackupController.to;
      final data = backupCtrl.exportAllSettings();
      final favoriteData = data['favorite'] as Map<String, dynamic>? ?? {};
      final favoriteRooms = favoriteData['favoriteRooms'] as List? ?? [];
      _favoriteCount = favoriteRooms.length;

      final historyData = data['history'] as Map<String, dynamic>? ?? {};
      final historyList = historyData['historyRooms'] ?? historyData['historyList'] ?? [];
      _historyCount = historyList is List ? historyList.length : 0;

      final tagData = data['tags'] as Map<String, dynamic>? ?? {};
      final tagList = tagData['tags'] as List? ?? [];
      _tagCount = tagList.length;

      setState(() {
        _configData = json.decode(json.encode(data)) as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _isLoading = false;
      });
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

    final backupVer = _configData['backupVersion'] ?? 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(i18n('local_config_preview'), style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = MediaQuery.of(context).size.width <= 680;

              if (isCompact) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'backup v$backupVer',
                                    style: AppTextStyles.t11.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSecondaryContainer,
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactMeta(
                              Remix.heart_3_line,
                              i18n('favorites'),
                              '$_favoriteCount',
                              theme,
                              isPrimaryColor: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactMeta(
                              Remix.history_line,
                              i18n('history'),
                              '$_historyCount',
                              theme,
                              isPrimaryColor: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactMeta(
                              Remix.price_tag_3_line,
                              i18n('tags'),
                              '$_tagCount',
                              theme,
                              isPrimaryColor: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactMeta(
                              Remix.file_list_3_line,
                              i18n('config_modules'),
                              '${_configData.length - 1}',
                              theme,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15), width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'backup v$backupVer',
                                    style: AppTextStyles.t11.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 0.5,
                      height: 64,
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      flex: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactMeta(
                                  Remix.heart_3_line,
                                  i18n('favorites'),
                                  '$_favoriteCount',
                                  theme,
                                  isPrimaryColor: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactMeta(
                                  Remix.history_line,
                                  i18n('history'),
                                  '$_historyCount',
                                  theme,
                                  isPrimaryColor: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactMeta(
                                  Remix.price_tag_3_line,
                                  i18n('tags'),
                                  '$_tagCount',
                                  theme,
                                  isPrimaryColor: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactMeta(
                                  Remix.file_list_3_line,
                                  i18n('config_modules'),
                                  '${_configData.length - 1}',
                                  theme,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: context.buildGroupTitle(i18n('config_raw_preview')),
          ),
          // Json预览区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
        ],
      ),
    );
  }

  Widget _buildCompactMeta(IconData icon, String label, String value, ThemeData theme, {bool isPrimaryColor = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: isPrimaryColor ? theme.colorScheme.primary : theme.hintColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.t11.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPrimaryColor ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.t11.copyWith(color: theme.hintColor, height: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
