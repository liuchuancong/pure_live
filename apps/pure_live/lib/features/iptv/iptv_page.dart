import 'dart:async' show StreamSubscription, unawaited;

import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel, IptvLibrary, iptvFetcherFor;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/iptv/iptv_routes.dart';
import 'package:pure_live/features/iptv/iptv_preferences.dart' show IptvPreferences;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// IPTV: the imported playlists, their channels grouped and searchable, and
/// the way a new playlist enters the library — a name and a URL fetched
/// through the shared client, or a local M3U/TXT file.
///
/// The group, favourites filter and last-played channel are viewer state and
/// persist through [IptvPreferencesNotifier] (the appearance-preferences
/// document pattern); the playlists themselves persist in the library's own
/// box. Opening a channel joins with the play page, which teaches the engine
/// IPTV lines; this page is the library and its management.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV page.
  const new({super.key});

  @override
  ConsumerState<IptvPage> createState() => _IptvPageState();
}

final class _IptvPageState extends ConsumerState<IptvPage> {
  StreamSubscription<void>? _changes;
  StreamSubscription<IptvPreferences>? _preferencesChanges;
  final TextEditingController _search = TextEditingController();
  String? _selectedGroup;
  bool _favoritesOnly = false;
  bool _importing = false;

  IptvLibrary get _library => ref.read(iptvLibraryProvider);

  @override
  void initState() {
    super.initState();
    // The resting state — group and favourites filter — is the persisted
    // document's, so a session opens where the last one left off.
    final preferences = ref.read(iptvPreferencesProvider);
    _selectedGroup = preferences.lastGroup.isEmpty ? null : preferences.lastGroup;
    _favoritesOnly = preferences.favoritesOnly;
    _preferencesChanges = ref.read(iptvPreferencesStoreProvider).changes.listen((_) {
      // Another window's change re-points this page too; the search text,
      // being session-local, is left alone.
      if (!mounted) {
        return;
      }
      final fresh = ref.read(iptvPreferencesProvider);
      setState(() {
        _selectedGroup = fresh.lastGroup.isEmpty ? null : fresh.lastGroup;
        _favoritesOnly = fresh.favoritesOnly;
      });
    });
    unawaited(_library.load());
    _changes = _library.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    unawaited(_preferencesChanges?.cancel());
    _search.dispose();
    super.dispose();
  }

  Future<void> _setPreferences(IptvPreferences Function(IptvPreferences preferences) transform) =>
      ref.read(iptvPreferencesProvider.notifier).update(transform);

  Future<void> _importFromUrl() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final form = await showPureDialog<({String name, String url})>(
      context: context,
      title: context.t.iptv.addSource,
      // A Builder so the submit pops the dialog route, not the page under it.
      child: Builder(
        builder: (fieldContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              autofocus: true,
              child: PureTextField(controller: name, placeholder: fieldContext.t.iptv.sourceName),
            ),
            const SizedBox(height: 8),
            PureTextField(
              controller: url,
              placeholder: fieldContext.t.iptv.sourceUrl,
              onSubmitted: (_) => Navigator.of(fieldContext).pop((name: name.text.trim(), url: url.text.trim())),
            ),
          ],
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
          onPressed: () => Navigator.of(dialogContext).pop((name: name.text.trim(), url: url.text.trim())),
        ),
      ],
    );
    if (form == null || form.name.isEmpty || form.url.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(form.url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        PureToast.show(context, context.t.errors.network, type: PureToastType.error);
      }
      return;
    }
    await _runImport(() async {
      final fetch = iptvFetcherFor(ref.read(httpProvider));
      final text = await fetch(uri);
      return await _library.importFromText(text, name: form.name, url: form.url);
    });
  }

  Future<void> _importFromFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'playlist', extensions: ['m3u', 'm3u8', 'txt']),
      ],
    );
    if (file == null) {
      return;
    }
    final name = file.name.replaceFirst(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '').trim();
    await _runImport(() async {
      final text = await file.readAsString();
      return await _library.importFromText(text, name: name.isEmpty ? file.name : name);
    });
  }

  /// Runs [import_], toasting the channel count or the failure; the busy
  /// spinner covers both import paths.
  Future<void> _runImport(Future<int> Function() import_) async {
    setState(() => _importing = true);
    try {
      final count = await import_();
      if (mounted) {
        PureToast.show(context, context.t.iptv.imported(count: count), type: PureToastType.success);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, context.t.iptv.importFailed, type: PureToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deleteSource(String id) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.iptv.deleteSource,
      child: const SizedBox.shrink(),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.common.confirm,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed == true) {
      await _library.deletePlaylist(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    final playlists = library.playlists;
    final groups = library.groupNames;
    final group = _selectedGroup;
    final needle = _search.text.trim().toLowerCase();
    final channels = [
      for (final channel in library.orderedChannels)
        if ((group == null || channel.entry.group == group) &&
            (!_favoritesOnly || channel.favorite) &&
            (needle.isEmpty || channel.entry.name.toLowerCase().contains(needle)))
          channel,
    ];
    final showGroups = groups.any((name) => name.isNotEmpty);
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.iptv.title,
        actions: [
          PureIconButton(
            tooltip: context.t.iptv.favoritesOnly,
            icon: _favoritesOnly ? Icons.favorite : Icons.favorite_border,
            onPressed: () {
              final next = !_favoritesOnly;
              setState(() => _favoritesOnly = next);
              unawaited(_setPreferences((preferences) => preferences.copyWith(favoritesOnly: next)));
            },
          ),
          PureIconButton(
            tooltip: context.t.iptv.importFromFile,
            icon: Icons.file_open_outlined,
            onPressed: _importing ? null : () => unawaited(_importFromFile()),
          ),
          PureIconButton(
            tooltip: context.t.iptv.addSource,
            icon: Icons.add_link,
            onPressed: _importing ? null : () => unawaited(_importFromUrl()),
          ),
          const SettingsEntryButton(),
        ],
        bottom: showGroups
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      for (final name in groups)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(name.isEmpty ? context.t.iptv.allGroups : name),
                            selected: _selectedGroup == name || (_selectedGroup == null && name.isEmpty),
                            onSelected: (_) {
                              setState(() => _selectedGroup = name);
                              unawaited(_setPreferences((preferences) => preferences.copyWith(lastGroup: name)));
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (playlists.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: PureTextField(
                controller: _search,
                placeholder: context.t.iptv.search,
                prefix: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (playlists.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final playlist in playlists)
                    InputChip(
                      label: Text('${playlist.name} (${playlist.channelCount})'),
                      onDeleted: () => unawaited(_deleteSource(playlist.id)),
                    ),
                ],
              ),
            ),
          Expanded(child: _channelList(context, channels, hasSources: playlists.isNotEmpty)),
        ],
      ),
    );
  }

  Widget _channelList(BuildContext context, List<IptvChannel> channels, {required bool hasSources}) {
    if (_importing) {
      return const Center(child: PureSpinner(size: 40));
    }
    if (!hasSources) {
      return PureEmpty(title: context.t.iptv.empty);
    }
    if (channels.isEmpty) {
      return PureEmpty(title: context.t.iptv.noMatch);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return PureListRow(
          leading: channel.number == null
              ? const Icon(Icons.live_tv_outlined)
              : SizedBox(
                  width: 40,
                  child: Text(
                    '${channel.number}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
          title: channel.entry.name,
          subtitle: channel.entry.group ?? '',
          onTap: () {
            unawaited(_setPreferences((preferences) => preferences.copyWith(lastChannelId: channel.id)));
            unawaited(IptvPlayRoute(channelId: channel.id, name: channel.entry.name).push<void>(context));
          },
          trailing: PureIconButton(
            tooltip: context.t.iptv.favorite,
            icon: channel.favorite ? Icons.favorite : Icons.favorite_border,
            onPressed: () => unawaited(_library.toggleFavorite(channel.id)),
          ),
          divided: false,
        );
      },
    );
  }
}
