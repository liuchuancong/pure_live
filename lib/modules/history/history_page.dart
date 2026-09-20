import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.loadRoom});

  final Future<LiveRoom> Function(LiveRoom room)? loadRoom;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);
  Future<void>? _refreshTask;
  bool _historyMutationBusy = false;

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  Future<void> onRefresh() => _refreshTask ??= _refreshHistory().whenComplete(() => _refreshTask = null);

  Future<void> _refreshHistory() async {
    bool result = true;
    final history = SettingsService.to.history;
    final list = List<LiveRoom>.from(history.historyRooms.v);
    final concurrency = RefreshConfigController.normalizeMaxConcurrentRefresh(
      SettingsService.to.refreshConfig.maxConcurrentRefresh.v,
    );
    final refreshed = await boundedAsyncMap<LiveRoom, LiveRoom>(
      list,
      maxConcurrent: concurrency,
      task: (room) async {
        final platform = room.platform;
        final roomId = room.roomId;
        if (platform == null || platform.isEmpty || roomId == null || roomId.isEmpty) {
          result = false;
          return room;
        }
        try {
          final newRoom =
              await (widget.loadRoom?.call(room) ??
                      Sites.of(platform).liveSite.getRoomDetail(roomId: roomId, platform: platform))
                  .timeout(const Duration(seconds: 12));
          return preserveHistoryMetadata(newRoom, room);
        } catch (_) {
          result = false;
          return room;
        }
      },
      shouldCancel: () => !mounted,
    );
    if (!mounted || history.isClosed) return;
    try {
      await history.applyRefreshedRoomsDurably(list, refreshed);
    } catch (error) {
      debugPrint('History refresh persistence failed: $error');
      result = false;
      if (mounted) ToastUtil.show(i18n('history_changes_save_failed'));
    }
    if (result) {
      refreshController.finishRefresh(IndicatorResult.success);
      refreshController.resetFooter();
    } else {
      refreshController.finishRefresh(IndicatorResult.fail);
    }
  }

  void _showHistoryLimitDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _HistoryLimitDialog(controller: SettingsService.to.history),
    );
  }

  Future<void> _clearHistory() async {
    final controller = SettingsService.to.history;
    if (_historyMutationBusy || controller.historyRooms.v.isEmpty || !mounted) return;
    final snapshot = List<LiveRoom>.from(controller.historyRooms.v);
    setState(() => _historyMutationBusy = true);
    try {
      final confirmed = await _showDestructiveConfirmation(
        title: i18n('clear_history'),
        message: i18n('clear_history_confirm_named', args: {'count': snapshot.length.toString()}),
        actionLabel: i18n('clear'),
      );
      if (confirmed && mounted && !controller.isClosed) {
        await controller.clearHistorySnapshotDurably(snapshot);
      }
    } catch (error) {
      debugPrint('Clearing history failed: $error');
      if (mounted) ToastUtil.show(i18n('history_changes_save_failed'));
    } finally {
      if (mounted) setState(() => _historyMutationBusy = false);
    }
  }

  Future<void> _deleteHistoryRoom(LiveRoom room) async {
    final controller = SettingsService.to.history;
    if (_historyMutationBusy || !mounted || !controller.historyRooms.v.any((entry) => identical(entry, room))) return;
    final title = _historyRoomLabel(room);
    setState(() => _historyMutationBusy = true);
    try {
      final confirmed = await _showDestructiveConfirmation(
        title: i18n('delete'),
        message: i18n('remove_history_confirm_named', args: {'title': title}),
        actionLabel: i18n('delete'),
      );
      if (confirmed && mounted && !controller.isClosed) {
        await controller.clearHistorySnapshotDurably([room]);
      }
    } catch (error) {
      debugPrint('Deleting history item failed: $error');
      if (mounted) ToastUtil.show(i18n('history_changes_save_failed'));
    } finally {
      if (mounted) setState(() => _historyMutationBusy = false);
    }
  }

  Future<bool> _showDestructiveConfirmation({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            title: Text(title, style: AppTextStyles.t16Bold),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(message, style: AppTextStyles.t14),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
                child: Text(i18n('cancel'), style: AppTextStyles.t14Muted),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() {
          final controller = SettingsService.to.history;
          return Text(
            '${i18n("history")} '
            '(${controller.historyRooms.v.length}/${_historyLimitLabel(controller.historyLimit.v)})',
          );
        }),
        actions: [
          IconButton(
            tooltip: i18n("history_limit"),
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _showHistoryLimitDialog(context),
          ),
          Obx(() {
            if (SettingsService.to.history.historyRooms.v.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: i18n("clear_history"),
              icon: const Icon(Icons.delete_forever),
              onPressed: _historyMutationBusy ? null : _clearHistory,
            );
          }),
        ],
      ),
      body: Obx(() {
        const dense = true;
        final rooms = SettingsService.to.history.historyRooms.v;
        return LayoutBuilder(
          builder: (context, constraint) {
            final width = constraint.maxWidth;
            int crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
            if (dense) crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
            final indicators = appRefreshIndicators(context, maxWidth: width);
            return EasyRefresh(
              header: indicators.header,
              footer: indicators.footer,
              controller: refreshController,
              onRefresh: onRefresh,
              onLoad: () => refreshController.finishLoad(IndicatorResult.noMore),
              child: rooms.isEmpty
                  ? EmptyView(icon: Icons.history_rounded, title: i18n("empty_history"), subtitle: '')
                  : WaterfallFlow.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                        lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                        mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) => RoomCard(
                        room: rooms[index],
                        dense: dense,
                        showDelete: true,
                        deleteTooltip: i18n(
                          'remove_history_entry_named',
                          args: {'title': _historyRoomLabel(rooms[index])},
                        ),
                        onDelete: _historyMutationBusy ? null : () => _deleteHistoryRoom(rooms[index]),
                      ),
                    ),
            );
          },
        );
      }),
    );
  }
}

String _historyLimitLabel(int limit) => limit == unlimitedHistoryLimit ? i18n('history_unlimited') : '$limit';

String _historyRoomLabel(LiveRoom room) {
  for (final candidate in [room.title, room.nick, room.roomId]) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return i18n('untitled_room');
}

class _HistoryLimitDialog extends StatefulWidget {
  const _HistoryLimitDialog({required this.controller});
  final HistoryController controller;
  @override
  State<_HistoryLimitDialog> createState() => _HistoryLimitDialogState();
}

class _HistoryLimitDialogState extends State<_HistoryLimitDialog> {
  late int draftLimit;
  final customController = TextEditingController();
  String? customErrorKey;
  bool _saving = false;
  static const presetOptions = <int>[20, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    draftLimit = widget.controller.historyLimit.v;
  }

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  void _selectLimit(int value) {
    setState(() {
      draftLimit = value;
      customErrorKey = null;
    });
  }

  void _applyCustomLimit() {
    if (_saving) return;
    final value = int.tryParse(customController.text.trim());
    if (value == null || value < 0) {
      setState(() => customErrorKey = 'history_limit_invalid');
      return;
    }
    setState(() {
      draftLimit = normalizeHistoryLimit(value);
      customErrorKey = null;
      customController.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.setHistoryLimitDurably(draftLimit);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      debugPrint('Saving history limit failed: $error');
      if (mounted) ToastUtil.show(i18n('history_changes_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text(i18n("history_limit"), style: AppTextStyles.t16Bold),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n('history_limit_presets'), style: AppTextStyles.t12Muted),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...presetOptions.map(
                    (value) => ChoiceChip(
                      label: Text('$value', style: AppTextStyles.t12),
                      selected: draftLimit == value,
                      onSelected: _saving ? null : (_) => _selectLimit(value),
                    ),
                  ),
                  ChoiceChip(
                    label: Text(i18n('history_unlimited'), style: AppTextStyles.t12),
                    selected: draftLimit == unlimitedHistoryLimit,
                    onSelected: _saving ? null : (_) => _selectLimit(unlimitedHistoryLimit),
                  ),
                  if (!presetOptions.contains(draftLimit) && draftLimit != unlimitedHistoryLimit)
                    ChoiceChip(
                      label: Text('$draftLimit', style: AppTextStyles.t12),
                      selected: true,
                      onSelected: _saving ? null : (_) {},
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(i18n('history_limit_custom'), style: AppTextStyles.t13Medium),
              const SizedBox(height: 12),
              TextField(
                controller: customController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _applyCustomLimit(),
                onChanged: (_) {
                  if (customErrorKey != null) setState(() => customErrorKey = null);
                },
                style: AppTextStyles.t14,
                decoration: InputDecoration(
                  hintText: '50',
                  suffixText: i18n("items"),
                  suffixStyle: AppTextStyles.t12Muted,
                  errorText: customErrorKey == null ? null : i18n(customErrorKey!),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _applyCustomLimit,
                  child: Text(i18n("apply"), style: AppTextStyles.t13Medium.copyWith(color: theme.colorScheme.primary)),
                ),
              ),
              const SizedBox(height: 16),
              Text('${i18n("current_value")}: ${_historyLimitLabel(draftLimit)}', style: AppTextStyles.t12Muted),
              const SizedBox(height: 6),
              Text(i18n('history_limit_desc'), style: AppTextStyles.t12Muted),
            ],
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(i18n("cancel"), style: AppTextStyles.t14Muted),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(i18n("confirm"), style: AppTextStyles.t14Primary),
        ),
      ],
    );
  }
}
