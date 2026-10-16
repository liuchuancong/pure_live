import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The danmaku shield (3.x `ShieldPage`, trimmed to the three lists): the
/// keywords, the viewers and the regexes whose messages never render.
///
/// The similarity filter belongs to the danmaku pipeline's own matching and
/// joins with the danmaku wave. The lists persist through the live_storage
/// keyed family — one box, one key per list — and the page keeps its own
/// edited copies, saving on every mutation.
final class ShieldPage extends ConsumerStatefulWidget {
  /// The shield page.
  const new({super.key});

  @override
  ConsumerState<ShieldPage> createState() => _ShieldPageState();
}

final class _ShieldPageState extends ConsumerState<ShieldPage> {
  HiveStorageRepository<List<String>>? _repository;
  final Map<_ShieldKind, List<String>> _lists = {
    _ShieldKind.keywords: <String>[],
    _ShieldKind.users: <String>[],
    _ShieldKind.regexes: <String>[],
  };
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
  }

  Future<void> _add(_ShieldKind kind) async {
    final field = TextEditingController();
    final value = await showLiveDialog<String>(
      context: context,
      title: '${context.t.shield.add} — ${_titleOf(kind)}',
      // A Builder so the submit pops the dialog route, not the page under it.
      child: Builder(
        builder: (fieldContext) => Focus(
          autofocus: true,
          child: LiveTextField(
            controller: field,
            onSubmitted: (submitted) => Navigator.of(fieldContext).pop(submitted.trim()),
          ),
        ),
      ),
      actions: (dialogContext) => [
        LiveButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        LiveButton(
          label: dialogContext.t.common.confirm,
          onPressed: () => Navigator.of(dialogContext).pop(field.text.trim()),
        ),
      ],
    );
    if (value == null || value.isEmpty) {
      return;
    }
    final list = _lists[kind] ?? [];
    if (list.contains(value)) {
      return;
    }
    setState(() => _lists[kind] = [...list, value]);
    await _save(kind);
  }

  Future<void> _remove(_ShieldKind kind, String value) async {
    setState(() => _lists[kind] = [...?_lists[kind]]..remove(value));
    await _save(kind);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return LiveScaffold(
        appBar: LiveAppBar(title: context.t.shield.title, actions: const [SettingsEntryButton()]),
        body: const Center(child: LiveSpinner(size: 40)),
      );
    }
    return LiveScaffold(
      appBar: LiveAppBar(title: context.t.shield.title, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final kind in _ShieldKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LiveCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(_titleOf(kind), style: Theme.of(context).textTheme.titleSmall)),
                        LiveIconButton(
                          tooltip: context.t.shield.add,
                          icon: Icons.add,
                          onPressed: () => unawaited(_add(kind)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in _lists[kind] ?? const <String>[])
                          InputChip(label: Text(value), onDeleted: () => unawaited(_remove(kind, value))),
                        if ((_lists[kind] ?? const []).isEmpty) Text(context.t.shield.none),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The three shield lists.
enum _ShieldKind { keywords, users, regexes }
