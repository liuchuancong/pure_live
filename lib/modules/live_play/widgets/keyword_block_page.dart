import 'package:pure_live/common/index.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

class KeywordBlockPage extends StatefulWidget {
  const KeywordBlockPage({super.key});

  @override
  State<KeywordBlockPage> createState() => _KeywordBlockPageState();
}

class _KeywordBlockPageState extends State<KeywordBlockPage> {
  final TextEditingController textEditingController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final RxBool _isFocused = false.obs;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => _isFocused.value = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    textEditingController.dispose();
    _isFocused.close();
    super.dispose();
  }

  void add() {
    final keyword = textEditingController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n('please_enter_keyword'));
      return;
    }
    SettingsService.to.fav.addShieldList(keyword);
    textEditingController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      physics: const PureLiveScrollPhysics(),
      scrollCacheExtent: const ScrollCacheExtent.pixels(360),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          sliver: SliverToBoxAdapter(child: Obx(() => _buildInput(theme))),
        ),
        Obx(() {
          final keywords = List<String>.from(SettingsService.to.fav.shieldList);
          return _buildBlockSliver(
            theme,
            title: i18n('keyword_added_count', args: {'count': '${keywords.length}'}),
            items: keywords,
            icon: Icons.filter_alt_off_rounded,
            onRemove: SettingsService.to.fav.removeShieldList,
          );
        }),
        Obx(() {
          final users = List<String>.from(SettingsService.to.fav.blockedDanmakuUsers);
          return _buildBlockSliver(
            theme,
            title: i18n('blocked_danmaku_users', args: {'count': '${users.length}'}),
            items: users,
            icon: Icons.person_off_rounded,
            onRemove: SettingsService.to.fav.removeBlockedDanmakuUser,
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildInput(ThemeData theme) {
    final isFocused = _isFocused.value;
    return TextField(
      keyboardType: TextInputType.text,
      controller: textEditingController,
      focusNode: _focusNode,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => add(),
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
        suffixIcon: IconButton(onPressed: add, icon: const Icon(Remix.add_circle_line), tooltip: i18n('add')),
      ),
    );
  }

  Widget _buildBlockSliver(
    ThemeData theme, {
    required String title,
    required List<String> items,
    required IconData icon,
    required ValueChanged<int> onRemove,
  }) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          sliver: SliverToBoxAdapter(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) => RepaintBoundary(
              child: Material(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  leading: Icon(icon, size: 19, color: theme.colorScheme.primary),
                  title: Text(items[index], maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: i18n('click_to_remove'),
                    icon: const Icon(Remix.close_line, size: 18),
                    onPressed: () => onRemove(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
