import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class KeywordBlockPage extends StatefulWidget {
  const KeywordBlockPage({super.key});

  @override
  State<KeywordBlockPage> createState() => _KeywordBlockPageState();
}

class _KeywordBlockPageState extends State<KeywordBlockPage> {
  final TextEditingController textEditingController = TextEditingController();

  final FocusNode _focusNode = FocusNode();
  final RxBool _isFocused = false.obs;

  late final ScrollController _scrollController;

  SettingsService get settingsService => SettingsService.to;

  @override
  void initState() {
    super.initState();

    _scrollController = createPureLiveScrollController();

    _focusNode.addListener(() {
      _isFocused.value = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    textEditingController.dispose();
    _isFocused.close();
    super.dispose();
  }

  void addKeyword() {
    final keyword = textEditingController.text.trim();

    if (keyword.isEmpty) {
      ToastUtil.show(i18n('please_enter_keyword'));
      return;
    }

    settingsService.fav.addShieldList(keyword);

    textEditingController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final labelColor = theme.colorScheme.onSurface;
    final digitColor = theme.colorScheme.primary;

    final dm = settingsService.danmaku;

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // Danmaku similarity filter
            // ============================================================

            context.buildGroupTitle(i18n('danmaku_similarity_filter')),

            const SizedBox(height: 8),

            Obx(
              () => context.buildModernCard([
                _switch(
                  theme,
                  title: i18n('danmaku_similarity_filter_enable'),
                  value: dm.enableDanmakuSimilarityFilter.v,
                  onChanged: (value) {
                    dm.enableDanmakuSimilarityFilter.v = value;
                  },
                  labelColor: labelColor,
                ),

                if (dm.enableDanmakuSimilarityFilter.v) ...[
                  _slider(
                    theme,
                    title: i18n('danmaku_similarity_threshold'),
                    value: dm.danmakuSimilarityThreshold.v.toDouble(),
                    min: 50,
                    max: 100,
                    stepSize: 1,
                    display: '${dm.danmakuSimilarityThreshold.v}%',
                    onChanged: (value) {
                      dm.danmakuSimilarityThreshold.v = value.round();
                    },
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),

                  _slider(
                    theme,
                    title: i18n('danmaku_similarity_cache_duration'),
                    value: dm.danmakuSimilarityCacheDuration.v.toDouble(),
                    min: 1,
                    max: 60,
                    stepSize: 1,
                    display: i18n(
                      'danmaku_similarity_cache_seconds',
                      args: {'seconds': '${dm.danmakuSimilarityCacheDuration.v}'},
                    ),
                    onChanged: (value) {
                      dm.danmakuSimilarityCacheDuration.v = value.round();
                    },
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),

                  _slider(
                    theme,
                    title: i18n('danmaku_similarity_max_cache_size'),
                    value: dm.danmakuSimilarityMaxCacheSize.v.toDouble(),
                    min: 20,
                    max: 1000,
                    stepSize: 10,
                    display: '${dm.danmakuSimilarityMaxCacheSize.v}',
                    onChanged: (value) {
                      dm.danmakuSimilarityMaxCacheSize.v = value.round();
                    },
                    labelColor: labelColor,
                    digitColor: digitColor,
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // ============================================================
            // Keyword input
            // ============================================================
            context.buildGroupTitle(i18n('danmaku_keyword_block')),

            const SizedBox(height: 8),

            Obx(() => context.buildModernCard([_buildInput(theme, labelColor)])),

            const SizedBox(height: 20),

            // ============================================================
            // Blocked keywords
            // ============================================================
            Obx(() {
              final keywords = List<String>.from(settingsService.fav.shieldList);

              if (keywords.isEmpty) {
                return const SizedBox.shrink();
              }

              return context.buildModernCard([
                _buildSectionTitle(theme, i18n('keyword_added_count', args: {'count': '${keywords.length}'})),

                const SizedBox(height: 4),

                for (var index = 0; index < keywords.length; index++)
                  _buildItem(
                    theme,
                    text: keywords[index],
                    icon: Icons.filter_alt_off_rounded,
                    onRemove: () {
                      settingsService.fav.removeShieldList(index);
                    },
                  ),
              ]);
            }),

            const SizedBox(height: 20),

            // ============================================================
            // Blocked users
            // ============================================================
            Obx(() {
              final users = List<String>.from(settingsService.fav.blockedDanmakuUsers);

              if (users.isEmpty) {
                return const SizedBox.shrink();
              }

              return context.buildModernCard([
                _buildSectionTitle(theme, i18n('blocked_danmaku_users', args: {'count': '${users.length}'})),

                const SizedBox(height: 4),

                for (var index = 0; index < users.length; index++)
                  _buildItem(
                    theme,
                    text: users[index],
                    icon: Icons.person_off_rounded,
                    onRemove: () {
                      settingsService.fav.removeBlockedDanmakuUser(index);
                    },
                  ),
              ]);
            }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // Input
  // ================================================================

  Widget _buildInput(ThemeData theme, Color labelColor) {
    final isFocused = _isFocused.value;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: textEditingController,
        focusNode: _focusNode,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => addKeyword(),
        decoration: InputDecoration(
          hintText: i18n('please_enter_keyword'),
          filled: true,
          fillColor: isFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.04)
              : theme.colorScheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          suffixIcon: IconButton(tooltip: i18n('add'), onPressed: addKeyword, icon: const Icon(Remix.add_circle_line)),
        ),
      ),
    );
  }

  // ================================================================
  // Section title
  // ================================================================

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ================================================================
  // Block item
  // ================================================================

  Widget _buildItem(ThemeData theme, {required String text, required IconData icon, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: RepaintBoundary(
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            dense: true,
            leading: Icon(icon, size: 19, color: theme.colorScheme.primary),
            title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: i18n('click_to_remove'),
              icon: const Icon(Remix.close_line, size: 18),
              onPressed: onRemove,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // Slider
  // ================================================================

  Widget _slider(
    ThemeData theme, {
    required String title,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
    required Color labelColor,
    required Color digitColor,
    double? stepSize,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  display,
                  style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold, color: digitColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Transform.translate(
            offset: const Offset(-8, 0),
            child: SizedBox(
              width: double.infinity,
              child: SfSlider(
                min: min,
                max: max,
                value: value,
                stepSize: stepSize,
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                onChanged: (dynamic value) {
                  onChanged(value as double);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // Switch
  // ================================================================

  Widget _switch(
    ThemeData theme, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: labelColor),
            ),
          ),
          Switch(value: value, activeThumbColor: theme.colorScheme.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
