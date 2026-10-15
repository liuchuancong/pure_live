import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_uikit/styling.dart' show LiveButton;

import 'package:pure_live/app/fonts/font_library.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The font manager (3.x `FontManagerPage`, app-font slice): the system
/// default plus every family in the cloud manifest — download, apply and
/// delete.
///
/// Applying writes the family id into the persisted appearance
/// (`fontFamily`), which the mapper carries into the uikit's `UiConfig`;
/// the engine learns the family's glyphs live through `FontLoader`, so no
/// restart is needed. Danmaku fonts join with the danmaku wave.
final class FontManagerPage extends ConsumerStatefulWidget {
  /// The font manager.
  const new({super.key});

  @override
  ConsumerState<FontManagerPage> createState() => _FontManagerPageState();
}

final class _FontManagerPageState extends ConsumerState<FontManagerPage> {
  List<FontFamily>? _families;
  Object? _error;
  final Set<String> _downloading = {};

  FontLibrary get _library => ref.read(fontLibraryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_loadFamilies());
  }

  Future<void> _loadFamilies() async {
    try {
      final families = await _library.fetchManifest();
      if (!mounted) {
        return;
      }
      setState(() => _families = families);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _error = StateError('manifest'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearancePreferencesProvider);
    final update = ref.read(appearancePreferencesProvider.notifier).update;
    final families = _families;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.settings.fonts), actions: const [SettingsEntryButton()]),
      body: families == null
          ? Center(
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.t.errors.network, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _loadFamilies),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _row(
                  context,
                  title: context.t.fonts.system,
                  selected: appearance.fontFamily?.isEmpty ?? true,
                  action: (appearance.fontFamily?.isEmpty ?? true)
                      ? null
                      : () => update((a) => a.copyWith(fontFamily: '')),
                ),
                for (final family in families)
                  _row(
                    context,
                    title: family.name,
                    selected: appearance.fontFamily == family.id,
                    action: _library.isDownloaded(family.id)
                        ? () => update((a) => a.copyWith(fontFamily: family.id))
                        : null,
                    trailing: _familyAction(context, family),
                  ),
              ],
            ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String title,
    required bool selected,
    required VoidCallback? action,
    String? subtitle,
    Widget? trailing,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked),
      title: Text(title),
      subtitle: (subtitle == null || subtitle.isEmpty)
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: action,
    ),
  );

  Widget? _familyAction(BuildContext context, FontFamily family) {
    if (_downloading.contains(family.id)) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_library.isDownloaded(family.id)) {
      return IconButton(
        tooltip: context.t.fonts.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: ref.read(appearancePreferencesProvider).fontFamily == family.id
            ? null
            : () => unawaited(_delete(family)),
      );
    }
    return IconButton(
      tooltip: context.t.fonts.download,
      icon: const Icon(Icons.download_outlined),
      onPressed: () => unawaited(_download(family)),
    );
  }

  Future<void> _download(FontFamily family) async {
    setState(() => _downloading.add(family.id));
    try {
      await _library.download(family);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.errors.network)));
      }
    } finally {
      if (mounted) {
        setState(() => _downloading.remove(family.id));
      }
    }
  }

  Future<void> _delete(FontFamily family) async {
    final active = ref.read(appearancePreferencesProvider).fontFamily == family.id;
    if (active) {
      return;
    }
    await _library.delete(family.id);
    if (mounted) {
      setState(() {});
    }
  }
}
