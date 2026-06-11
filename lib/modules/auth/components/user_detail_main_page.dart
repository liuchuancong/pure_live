import 'dart:convert';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter_json/flutter_json.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/modules/auth/models/user_config_model.dart';

class UserDetailConfigMainPage extends StatefulWidget {
  final String documentId;
  const UserDetailConfigMainPage({super.key, required this.documentId});

  @override
  State<UserDetailConfigMainPage> createState() => _UserDetailConfigMainPageState();
}

class _UserDetailConfigMainPageState extends State<UserDetailConfigMainPage> {
  UserFullModel? _userModel;
  bool _isLoading = true;
  String _errorMsg = '';
  Map<String, dynamic> _parsedBackupMap = {};

  int _favoriteCount = 0;
  int _historyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(widget.documentId).get();
      if (!docSnap.exists) throw Exception(i18n('user_not_found'));

      final data = docSnap.data()!;
      final model = UserFullModel.fromFirestore(data);

      final configMap = json.decode(docSnap['config'] as String) as Map<String, dynamic>;

      final favoriteData = configMap['favorite'] as Map<String, dynamic>? ?? {};
      final roomsList = favoriteData['favoriteRooms'] as List? ?? [];

      final historyData = configMap['history'] as Map<String, dynamic>? ?? {};
      final historyList = historyData['historyRooms'] ?? historyData['historyList'] ?? [];

      setState(() {
        _userModel = model;
        _parsedBackupMap = configMap;
        _favoriteCount = roomsList.length;
        _historyCount = (historyList is List) ? historyList.length : 0;
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

    final createDt = _userModel!.createdAt.toDate();
    final createTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(createDt);
    final syncTimeStr = _userModel!.updateAt ?? i18n('never_sync');
    final verText = _userModel!.version != null ? 'v${_userModel!.version}' : i18n('unknown_version');

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(i18n('user_profile'), style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                        child: Icon(Remix.user_settings_line, color: theme.colorScheme.onPrimaryContainer, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _userModel!.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    verText,
                                    style: AppTextStyles.t11.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
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
                            child: _buildCompactMeta(Remix.time_line, i18n('created_time'), createTimeStr, theme),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCompactMeta(
                              Remix.heart_3_line,
                              i18n('favorites'),
                              '$_favoriteCount',
                              theme,
                              isPrimaryColor: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildCompactMeta(Remix.refresh_line, i18n('sync_time'), syncTimeStr, theme)),
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
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: context.buildGroupTitle(i18n('config_raw_preview')),
          ),
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
              child: _parsedBackupMap.isEmpty
                  ? Center(child: AppStatusView(type: AppStatusType.empty))
                  : JsonWidget(json: _parsedBackupMap, initialExpandDepth: 2),
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
