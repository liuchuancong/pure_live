import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/room/room_providers.dart' show danmakuSessionProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/feed_chip.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The shield's editable lists, as a panel the room's block tab can embed and
/// the standalone page can host — the reference's `KeywordBlockPage`, whose
/// whole body lives inside the danmaku tab strip.
///
/// One caveat the reference shares: rules reach a running session through a
/// fresh one, so every mutation invalidates the room's danmaku providers and
/// the room reconnects with the new chain.
final class ShieldListsPanel extends ConsumerStatefulWidget {
  /// The panel.
  const new({super.key});

  @override
  ConsumerState<ShieldListsPanel> createState() => _ShieldListsPanelState();
}

final class _ShieldListsPanelState extends ConsumerState<ShieldListsPanel> {
  HiveStorageRepository<List<String>>? _repository;
  final Map<_ShieldKind, List<String>> _lists = {
    _ShieldKind.keywords: <String>[],
    _ShieldKind.users: <String>[],
    _ShieldKind.regexes: <String>[],
  };
  final TextEditingController _keywordInput = TextEditingController();
  bool _loaded = false;

  static String _keyOf(_ShieldKind kind) => switch (kind) {
    _ShieldKind.keywords => 'shield.keywords',
    _ShieldKind.users => 'shield.users',
    _ShieldKind.regexes => 'shield.regexes',
  };

  String _titleOf(_ShieldKind kind) => switch (kind) {
    _ShieldKind.keywords => context.t.shield.keywords,
    _ShieldKind.users => context.t.shield.users,
    _ShieldKind.regexes => context.t.shield.regexes,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _keywordInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = HiveStorageRepository<List<String>>(
      box: await StorageBoxManager().keyed<List<String>>('settings.shield'),
    );
    for (final kind in _ShieldKind.values) {
      _lists[kind] = repository.get(_keyOf(kind)) ?? <String>[];
    }
    _repository = repository;
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _save(_ShieldKind kind) async {
    final list = _lists[kind];
    if (list != null) {
      await _repository?.save(_keyOf(kind), list);
    }
    _reconnectRooms();
  }

  /// The rules only bite on a fresh session — the same contract the standalone
  /// page already keeps.
  void _reconnectRooms() {
    ref.invalidate(danmakuSessionProvider);
  }

  Future<void> _add(_ShieldKind kind, {String? value}) async {
    final field = TextEditingController();
    final text =
        value ??
        await showPureDialog<String>(
          context: context,
          title: '${context.t.shield.add} — ${_titleOf(kind)}',
          // A Builder so the submit pops the dialog route, not the page under it.
          child: Builder(
            builder: (fieldContext) => Focus(
              autofocus: true,
              child: PureTextField(
                controller: field,
                onSubmitted: (submitted) => Navigator.of(fieldContext).pop(submitted.trim()),
              ),
            ),
          ),
          actions: (dialogContext) => [
            PureButton(
              label: dialogContext.t.common.cancel,
              variant: ButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            PureButton(
              label: dialogContext.t.common.confirm,
              onPressed: () => Navigator.of(dialogContext).pop(field.text.trim()),
            ),
          ],
        );
    field.dispose();
    final raw = text?.trim() ?? '';
    // The reference caps a keyword at 64 characters; the field does not
    // enforce it, the store does.
    final trimmed = raw.length > 64 ? raw.substring(0, 64) : raw;
    if (trimmed.isEmpty) {
      return;
    }
    final list = _lists[kind] ?? [];
    if (list.contains(trimmed)) {
      return;
    }
    setState(() => _lists[kind] = [...list, trimmed]);
    await _save(kind);
  }

  Future<void> _remove(_ShieldKind kind, String value) async {
    setState(() => _lists[kind] = [...?_lists[kind]]..remove(value));
    await _save(kind);
  }

  void _submitKeyword() {
    final value = _keywordInput.text.trim();
    if (value.isEmpty) {
      PureToast.show(context, context.t.shield.emptyKeyword);
      return;
    }
    unawaited(_add(_ShieldKind.keywords, value: value));
    _keywordInput.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: PureSpinner(size: 40));
    }
    final t = context.t;
    final theme = PureTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // The reference's keyword entry: type it where you read the list.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: PureTextField(
                  controller: _keywordInput,
                  placeholder: t.shield.keywordHint,
                  onSubmitted: (_) => _submitKeyword(),
                ),
              ),
              const SizedBox(width: 8),
              PureIconButton(icon: Icons.add_circle_outline, tooltip: t.shield.add, onPressed: _submitKeyword),
            ],
          ),
        ),
        for (final kind in _ShieldKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PureCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kind == _ShieldKind.keywords
                              ? '${t.shield.keywords} (${(_lists[_ShieldKind.keywords] ?? const []).length})'
                              : _titleOf(kind),
                          style: theme.text.title,
                        ),
                      ),
                      if (kind != _ShieldKind.keywords)
                        PureIconButton(tooltip: t.shield.add, icon: Icons.add, onPressed: () => unawaited(_add(kind))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in _lists[kind] ?? const <String>[])
                        FeedChip(label: value, onDeleted: () => unawaited(_remove(kind, value))),
                      if ((_lists[kind] ?? const []).isEmpty)
                        Text(t.shield.none, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The three shield lists.
enum _ShieldKind { keywords, users, regexes }
