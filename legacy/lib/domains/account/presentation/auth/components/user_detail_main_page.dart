import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:flutter_json/flutter_json.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/domains/account/presentation/auth/models/user_config_model.dart';

class FirebaseUserConfigDocumentLoader {
  const FirebaseUserConfigDocumentLoader();

  Future<Map<String, dynamic>?> load(String documentId) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(documentId).get();
    return snapshot.exists ? snapshot.data() : null;
  }
}

class UserDetailConfigMainPage extends StatefulWidget {
  final String documentId;
  final FirebaseUserConfigDocumentLoader loader;

  const UserDetailConfigMainPage({
    super.key,
    required this.documentId,
    this.loader = const FirebaseUserConfigDocumentLoader(),
  });

  @override
  State<UserDetailConfigMainPage> createState() => _UserDetailConfigMainPageState();
}

enum _ProfileLoadError { notFound, requestFailed }

class _UserDetailConfigMainPageState extends State<UserDetailConfigMainPage> {
  UserFullModel? _userModel;
  bool _isLoading = true;
  _ProfileLoadError? _loadError;
  Map<String, dynamic> _parsedBackupMap = const {};
  int _favoriteCount = 0;
  int _historyCount = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUserData(showLoading: false));
  }

  @override
  void didUpdateWidget(covariant UserDetailConfigMainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId || oldWidget.loader != widget.loader) {
      unawaited(_loadUserData());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _loadUserData({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    final documentId = widget.documentId.trim();

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    if (documentId.isEmpty) {
      _publishError(generation, _ProfileLoadError.notFound);
      return;
    }

    try {
      final data = await widget.loader.load(documentId);
      if (data == null) {
        _publishError(generation, _ProfileLoadError.notFound);
        return;
      }

      final model = UserFullModel.fromFirestore(data);
      final backupMap = model.backupMap;
      final favoriteCount = _listCount(backupMap, 'favorite', const ['favoriteRooms']);
      final historyCount = _listCount(backupMap, 'history', const ['historyRooms', 'historyList']);

      if (!_isCurrent(generation)) return;
      setState(() {
        _userModel = model;
        _parsedBackupMap = backupMap;
        _favoriteCount = favoriteCount;
        _historyCount = historyCount;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('[FirebaseUserConfig] Failed to load $documentId: $error');
      _publishError(generation, _ProfileLoadError.requestFailed);
    }
  }

  void _publishError(int generation, _ProfileLoadError error) {
    if (!_isCurrent(generation)) return;
    setState(() {
      _userModel = null;
      _parsedBackupMap = const {};
      _favoriteCount = 0;
      _historyCount = 0;
      _loadError = error;
      _isLoading = false;
    });
  }

  bool _isCurrent(int generation) => mounted && generation == _loadGeneration;

  int _listCount(Map<String, dynamic> backupMap, String sectionName, List<String> listKeys) {
    final section = backupMap[sectionName];
    if (section is! Map) return 0;
    for (final key in listKeys) {
      final value = section[key];
      if (value is List) return value.length;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(i18n('user_profile'), style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return _buildScrollableStatus(AppStatusView(type: AppStatusType.loading));
    }

    final loadError = _loadError;
    if (loadError != null) {
      final notFound = loadError == _ProfileLoadError.notFound;
      return _buildScrollableStatus(
        AppStatusView(
          type: AppStatusType.error,
          title: i18n(notFound ? 'user_not_found' : 'firebase_profile_load_failed'),
          subtitle: i18n(notFound ? 'firebase_profile_not_found_subtitle' : 'firebase_profile_load_failed_subtitle'),
          buttonText: notFound ? null : i18n('retry'),
          onButtonPressed: notFound ? null : () => unawaited(_loadUserData()),
        ),
      );
    }

    final model = _userModel!;
    final createTimeStr = model.createdAt == null
        ? i18n('firebase_profile_unknown_time')
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(model.createdAt!);
    final syncTimeStr = model.updateAt ?? i18n('never_sync');
    final verText = model.version == null ? i18n('unknown_version') : 'v${model.version}';
    final email = model.email.isEmpty ? i18n('firebase_profile_unknown_email') : model.email;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawPreviewHeight = constraints.maxHeight < 520 ? 280.0 : constraints.maxHeight * 0.58;
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          physics: const PureLiveScrollPhysics(),
          children: [
            _buildProfileCard(theme, email, verText, createTimeStr, syncTimeStr),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: context.buildGroupTitle(i18n('config_raw_preview')),
            ),
            Container(
              height: rawPreviewHeight,
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
              child: _buildRawPreview(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollableStatus(Widget status) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final contentHeight = constraints.maxHeight > 260 * scale ? constraints.maxHeight : 260 * scale;
        return SingleChildScrollView(
          child: SizedBox(width: constraints.maxWidth, height: contentHeight, child: status),
        );
      },
    );
  }

  Widget _buildProfileCard(ThemeData theme, String email, String version, String createdTime, String syncTime) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  children: [
                    Text(email, style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          version,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stackItems = constraints.maxWidth < 600 || textScale > 1.5;
              final itemWidth = stackItems ? constraints.maxWidth : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildMeta(Remix.time_line, i18n('created_time'), createdTime, theme),
                  ),
                  SizedBox(width: itemWidth, child: _buildMeta(Remix.refresh_line, i18n('sync_time'), syncTime, theme)),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMeta(
                      Remix.heart_3_line,
                      i18n('favorites'),
                      '$_favoriteCount',
                      theme,
                      isPrimaryColor: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMeta(
                      Remix.history_line,
                      i18n('history'),
                      '$_historyCount',
                      theme,
                      isPrimaryColor: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRawPreview() {
    if (_parsedBackupMap.isEmpty) {
      return Center(child: Text(i18n('no_data'), textAlign: TextAlign.center));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final contentWidth = constraints.maxWidth > 220 * scale ? constraints.maxWidth : 220 * scale;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: JsonWidget(json: _parsedBackupMap, initialExpandDepth: 2),
          ),
        );
      },
    );
  }

  Widget _buildMeta(IconData icon, String label, String value, ThemeData theme, {bool isPrimaryColor = false}) {
    final foreground = isPrimaryColor ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 12, color: isPrimaryColor ? theme.colorScheme.primary : theme.hintColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.bold, color: foreground),
                ),
                const SizedBox(height: 1),
                Text(label, style: AppTextStyles.t11.copyWith(color: theme.hintColor, height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
