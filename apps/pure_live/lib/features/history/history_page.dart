import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show HistoryRepository;
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The history domain's shell page: what the user watched, newest first.
/// An entry re-opens its room; one entry or the whole list can be
/// cleared. The list renders from the repository's own change stream, so
/// a second window's watches appear here too.
final class HistoryPage extends ConsumerStatefulWidget {
  /// The history page.
  const new({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

final class _HistoryPageState extends ConsumerState<HistoryPage> {
  StreamSubscription<void>? _changes;

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_repository.load());
    _changes = _repository.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.history.clear),
        content: Text(context.t.history.clearConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t.history.clear, style: TextStyle(color: LiveTheme.of(context).colors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _repository.records;
    return LiveScaffold(
      appBar: LiveAppBar(
        title: context.t.tabs.history,
        actions: [
          if (records.isNotEmpty)
            IconButton(
              tooltip: context.t.history.clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
          const SettingsEntryButton(),
        ],
      ),
      body: records.isEmpty
          ? LiveEmpty(title: context.t.history.empty)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final room = record.room;
                final watchedAt = record.watchedAt.toLocal();
                final when =
                    '${watchedAt.month}-${watchedAt.day.toString().padLeft(2, '0')} '
                    '${watchedAt.hour.toString().padLeft(2, '0')}:${watchedAt.minute.toString().padLeft(2, '0')}';
                return LiveListRow(
                  leading: const Icon(Icons.live_tv_outlined),
                  title: room.content.title.isEmpty ? room.ref.roomId : room.content.title,
                  subtitle: '${room.anchor?.name ?? room.ref.platform} · $when',
                  trailing: IconButton(
                    tooltip: context.t.common.cancel,
                    icon: const Icon(Icons.close),
                    onPressed: () => unawaited(_repository.remove(room)),
                  ),
                  divided: false,
                  onTap: () => RoomRoute(
                    siteId: room.ref.platform,
                    roomId: room.ref.roomId,
                    roomName: room.content.title,
                  ).push<void>(context),
                );
              },
            ),
    );
  }
}
