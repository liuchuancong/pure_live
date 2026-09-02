import 'dart:async';

import 'package:remixicon/remixicon.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/multiview/multiview_room_search_controller.dart';
import 'package:pure_live/modules/multiview/widgets/multiview_room_picker.dart';

/// Non-modal "search and add" panel for one multi-view cell.
///
/// Rendered by `MultiviewPage` as a plain `Stack` child rather than a route,
/// dialog or overlay entry: only the panel's own rectangle absorbs hits, so the
/// other cells keep responding while the user picks. When [onPicked] fires the
/// page fills the cell that opened this panel and advances its target, which is
/// what makes consecutive channel-surfing work without re-opening anything.
class MultiviewRoomSearchPanel extends StatefulWidget {
  const MultiviewRoomSearchPanel({
    super.key,
    required this.cellIndex,
    required this.onPicked,
    this.onDragUpdate,
    this.onClose,
    this.embedded = false,
    this.search,
  });

  /// Cell this panel fills; shown in the title so the target is never ambiguous.
  final int cellIndex;
  final ValueChanged<LiveRoom> onPicked;

  /// Set only for the floating (desktop) form — the embedded sheet has no chrome.
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onClose;

  /// `true` when hosted inside a bottom sheet (mobile): no drag bar, fills parent.
  final bool embedded;

  /// Injectable for widget tests; production creates its own.
  final MultiviewRoomSearchController? search;

  @override
  State<MultiviewRoomSearchPanel> createState() => _MultiviewRoomSearchPanelState();
}

class _MultiviewRoomSearchPanelState extends State<MultiviewRoomSearchPanel> {
  late final MultiviewRoomSearchController _search;
  final TextEditingController _keyword = TextEditingController();
  final TextEditingController _direct = TextEditingController();
  String _platformId = '';
  late final bool _ownsSearch = widget.search == null;

  @override
  void initState() {
    super.initState();
    _search = widget.search ?? MultiviewRoomSearchController();
  }

  @override
  void dispose() {
    _keyword.dispose();
    _direct.dispose();
    if (_ownsSearch) _search.clear();
    super.dispose();
  }

  Future<void> _runSearch() => _search.search(_keyword.text, platformId: _platformId);

  Future<void> _addDirect() async {
    final room = await _search.resolveDirect(_direct.text, platformId: _platformId);
    if (room != null && mounted) widget.onPicked(room);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material rather than a decorated Container: the results list holds ListTile
    // ink features, which assert when nothing visible provides a Material surface.
    return Material(
      elevation: widget.embedded ? 0 : 6,
      color: theme.colorScheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          _buildKeywordRow(theme),
          _buildDirectRow(theme),
          _buildMessage(theme),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return GestureDetector(
      // 只在标题栏拖动，避免与列表滚动、文本选择冲突。
      onPanUpdate: widget.onDragUpdate == null ? null : (event) => widget.onDragUpdate!(event.delta),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Remix.search_line, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${i18n('multiview_search_rooms')} · ${i18n('multiview_cell')} ${widget.cellIndex + 1}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.t13Medium,
              ),
            ),
            if (!widget.embedded)
              Tooltip(
                message: i18n('multiview_panel_drag_hint'),
                child: Icon(Remix.drag_move_line, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: i18n('multiview_close_panel'),
              icon: const Icon(Remix.close_line, size: 18),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keyword,
              style: AppTextStyles.t13,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_runSearch()),
              decoration: InputDecoration(
                isDense: true,
                hintText: i18n('multiview_search_placeholder'),
                prefixIcon: const Icon(Remix.search_line, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _PlatformDropdown(
            platforms: _search.selectablePlatforms,
            value: _platformId,
            onChanged: (value) => setState(() => _platformId = value),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            onPressed: () => unawaited(_runSearch()),
            child: Text(i18n('multiview_search_start'), style: AppTextStyles.t13),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _direct,
              style: AppTextStyles.t13,
              onSubmitted: (_) => unawaited(_addDirect()),
              decoration: InputDecoration(
                isDense: true,
                hintText: i18n('multiview_room_id_or_link'),
                prefixIcon: const Icon(Remix.tv_2_line, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: i18n('multiview_room_id_or_link'),
            onPressed: () => unawaited(_addDirect()),
            icon: const Icon(Remix.add_line, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ThemeData theme) {
    return Obx(() {
      final message = _search.message.value;
      if (message.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Text(message, style: AppTextStyles.t12.copyWith(color: theme.colorScheme.error)),
      );
    });
  }

  Widget _buildResults(ThemeData theme) {
    return Obx(() {
      if (_search.loading.value) {
        return const AppStatusView(type: AppStatusType.loading, isMini: true);
      }
      final rooms = _search.results.toList(growable: false);
      if (rooms.isEmpty) {
        return AppStatusView(
          type: AppStatusType.empty,
          icon: Remix.tv_2_line,
          title: i18n('multiview_search_no_result'),
          subtitle: i18n('multiview_search_placeholder'),
          isMini: true,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        itemCount: rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final room = rooms[index];
          return ListTile(
            dense: true,
            leading: MultiviewRoomTileLeading(room: room),
            title: Text(room.nick ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.t13Medium),
            subtitle: Text(
              room.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.t12Muted,
            ),
            trailing: MultiviewLiveStatusBadge(room: room),
            onTap: () => widget.onPicked(room),
          );
        },
      );
    });
  }
}

/// Platform filter shared by the keyword and direct-entry rows. An empty value
/// means "all searchable platforms"; for direct entry a link input already
/// carries its own platform and wins over this choice.
class _PlatformDropdown extends StatelessWidget {
  const _PlatformDropdown({required this.platforms, required this.value, required this.onChanged});

  final List<Site> platforms;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = platforms.where((site) => site.id == value).firstOrNull;
    return PopupMenuButton<String>(
      tooltip: i18n('prefer_platform'),
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '',
          child: Text(i18n('site_all'), style: AppTextStyles.t13),
        ),
        for (final site in platforms)
          PopupMenuItem(
            value: site.id,
            child: Row(
              children: [
                Image.asset(site.logo, width: 16, height: 16),
                const SizedBox(width: 8),
                Text(site.name, style: AppTextStyles.t13),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected?.name ?? i18n('site_all'), style: AppTextStyles.t13),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
