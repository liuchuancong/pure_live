import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The cache & data page (3.x `CacheDataSettingsPage`, trimmed to the backed
/// control): the watch history's size at a glance and the one destructive
/// action the reference ships a backing for here — clearing it, behind the
/// reference's confirm dialog and a success toast.
///
/// The reference's cache-size row, thumbnail cache and download directory
/// have no backing in this build and stay out. The page rides the history
/// repository's change stream, so the count tracks clears made elsewhere.
final class CacheDataPage extends ConsumerStatefulWidget {
  /// The cache & data page.
  const new({super.key});

  @override
  ConsumerState<CacheDataPage> createState() => _CacheDataPageState();
}

final class _CacheDataPageState extends ConsumerState<CacheDataPage> {
  int _count = 0;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(historyRepositoryProvider);
    _count = repository.records.length;
    _changes = repository.changes.listen((_) {
      if (mounted) {
        setState(() => _count = repository.records.length);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _confirmClear() async {
    final t = context.t;
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: t.history.clear,
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), child: Text(t.history.clearConfirm)),
      actions: (dialogContext) => [
        PureButton(
          label: t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: t.history.clear,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(historyRepositoryProvider).clear();
    if (mounted) {
      PureToast.show(context, context.t.settings.historyCleared, type: PureToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.cacheAndData),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection.card(
            label: t.settings.sectionData,
            tiles: [
              PureListRow(
                leading: const Icon(Icons.history, size: 22),
                title: t.settings.historyEntry,
                subtitle: t.settings.historyCount(count: _count),
              ),
              SettingsEntryTile(
                icon: Icons.delete_sweep_outlined,
                title: t.settings.clearHistory,
                subtitle: t.settings.clearHistorySubtitle,
                onTap: () => unawaited(_confirmClear()),
                divided: false,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
