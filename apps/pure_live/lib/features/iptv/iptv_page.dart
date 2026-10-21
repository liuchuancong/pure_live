import 'dart:async' show StreamSubscription, unawaited;

import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel, IptvLibrary, IptvPlaylist, iptvFetcherFor;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/shell/home_views.dart' show HomeLayoutScope;
import 'package:pure_live/app/shell/shell_actions.dart' show HomeMenuButton;
import 'package:pure_live/features/iptv/iptv_preferences.dart' show IptvPreferences, IptvXtreamSource;
import 'package:pure_live/features/iptv/iptv_xtream.dart'
    show importXtreamChannels, isXtreamCredentialError, isXtreamPlaylistUrl, xtreamCatalogProvider, xtreamPlaylistId;
import 'package:pure_live/features/settings/widgets/settings_entry_button.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/feed_chip.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The two shapes a source can have, as the add dialog's segmented control
/// splits them: a playlist file or address, and an Xtream Codes account.
enum _SourceKind { playlist, xtream }

/// IPTV: the imported playlists, their channels grouped and searchable, and
/// the way a new source enters the library — an M3U/TXT playlist fetched
/// through the shared client or picked as a local file, or an Xtream
/// account whose live catalogue the player API serves.
///
/// The group, favourites filter and last-played channel are viewer state and
/// persist through [IptvPreferencesNotifier] (the appearance-preferences
/// document pattern); the playlists themselves persist in the library's own
/// box, and the Xtream accounts' credentials in the preferences document.
/// Opening a channel joins with the play page, which teaches the engine
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

  /// Asks for a new source and files it: the playlist kinds keep their old
  /// path (name and URL fetched as text), an Xtream account is stored in
  /// the preferences document and its catalogue pulled through the player
  /// API right away — a failed first fetch keeps the record, so a retry is
  /// the refresh button and not a re-typing of the credentials.
  Future<void> _addSource() async {
    final name = TextEditingController();
    final url = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final epgUrl = TextEditingController();
    var kind = _SourceKind.playlist;
    // The playlist kind's answer: the same two-field record the dialog has
    // always popped with, its blank fields read again as a cancellation.
    void submitPlaylist(BuildContext fieldContext) {
      Navigator.of(fieldContext)
          .pop((name: name.text.trim(), url: url.text.trim(), username: null, password: null, epgUrl: null));
    }

    final form = await showPureDialog<({String name, String url, String? username, String? password, String? epgUrl})>(
      context: context,
      title: context.t.iptv.addSource,
      // A Builder so the submit pops the dialog route, not the page under it.
      child: StatefulBuilder(
        builder: (fieldContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PureSegmented(
              labels: [fieldContext.t.iptv.kindPlaylist, fieldContext.t.iptv.kindXtream],
              index: kind == _SourceKind.playlist ? 0 : 1,
              onChanged: (index) => setDialogState(() => kind = index == 0 ? _SourceKind.playlist : _SourceKind.xtream),
            ),
            const SizedBox(height: 8),
            Focus(
              autofocus: true,
              child: PureTextField(controller: name, placeholder: fieldContext.t.iptv.sourceName),
            ),
            const SizedBox(height: 8),
            if (kind == _SourceKind.playlist)
              PureTextField(
                controller: url,
                placeholder: fieldContext.t.iptv.sourceUrl,
                onSubmitted: (_) => submitPlaylist(fieldContext),
              )
            else ...[
              PureTextField(controller: url, placeholder: fieldContext.t.iptv.xtreamServer),
              const SizedBox(height: 8),
              PureTextField(controller: username, placeholder: fieldContext.t.iptv.xtreamUsername),
              const SizedBox(height: 8),
              PureTextField(controller: password, placeholder: fieldContext.t.iptv.xtreamPassword, obscure: true),
              const SizedBox(height: 8),
              PureTextField(controller: epgUrl, placeholder: fieldContext.t.iptv.epgUrl),
            ],
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
          onPressed: () {
            if (kind == _SourceKind.playlist) {
              submitPlaylist(dialogContext);
            } else {
              Navigator.of(dialogContext).pop((
                name: name.text.trim(),
                url: url.text.trim(),
                username: username.text.trim(),
                password: password.text,
                epgUrl: epgUrl.text.trim(),
              ));
            }
          },
        ),
      ],
    );
    for (final controller in [name, url, username, password, epgUrl]) {
      controller.dispose();
    }
    if (form == null) {
      return;
    }
    if (form.username == null) {
      await _importFromUrl(form.name, form.url);
      return;
    }
    // The Xtream half: the fields are submitted as a triple with the
    // username set, so null means the playlist kind was on.
    if (form.url.isEmpty || form.username!.isEmpty || form.password!.isEmpty) {
      return;
    }
    final parsed = Uri.tryParse(form.url);
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https') || parsed.host.isEmpty) {
      if (mounted) {
        PureToast.show(context, context.t.errors.network, type: PureToastType.error);
      }
      return;
    }
    final source = IptvXtreamSource(
      id: 'x${DateTime.now().microsecondsSinceEpoch}',
      name: form.name.isNotEmpty ? form.name : (parsed.host.isNotEmpty ? parsed.host : form.username!),
      url: form.url,
      username: form.username!,
      password: form.password!,
      epgUrl: form.epgUrl ?? '',
    );
    await _setPreferences((preferences) => preferences.copyWith(xtreamSources: [...preferences.xtreamSources, source]));
    await _refreshXtream(source);
  }

  /// The playlist path the page has always had: fetch [formUrl] as text and
  /// let the library parse and reconcile it.
  Future<void> _importFromUrl(String formName, String formUrl) async {
    if (formName.isEmpty || formUrl.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(formUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        PureToast.show(context, context.t.errors.network, type: PureToastType.error);
      }
      return;
    }
    await _runImport(() async {
      final fetch = iptvFetcherFor(ref.read(httpProvider));
      final text = await fetch(uri);
      return await _library.importFromText(text, name: formName, url: formUrl);
    });
  }

  /// Reads [source]'s catalogue again and writes it over the source's own
  /// playlist record; the busy spinner and the toasts are [_runImport]'s.
  Future<void> _refreshXtream(IptvXtreamSource source) => _runImport(
    () => importXtreamChannels(library: _library, catalog: ref.read(xtreamCatalogProvider), source: source),
  );

  /// How many channels [source]'s last import served, 0 while none has —
  /// the number its chip carries.
  int _xtreamChannelCount(IptvXtreamSource source) {
    final playlistId = xtreamPlaylistId(_library, source);
    return playlistId == null ? 0 : (_library.playlistById(playlistId)?.channelCount ?? 0);
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
  /// spinner covers both import paths. A refused Xtream account gets its
  /// own words, because retyping the credentials is the fix.
  Future<void> _runImport(Future<int> Function() import_) async {
    setState(() => _importing = true);
    try {
      final count = await import_();
      if (mounted) {
        PureToast.show(context, context.t.iptv.imported(count: count), type: PureToastType.success);
      }
    } on Object catch (error) {
      if (mounted) {
        final message = isXtreamCredentialError(error) ? context.t.iptv.xtreamAuthFailed : context.t.iptv.importFailed;
        PureToast.show(context, message, type: PureToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  /// Reads [playlist]'s URL again and reconciles it (the reference's card
  /// "同步"): channels that vanished with the file are removed, new ones
  /// arrive, the record keeps its place.
  Future<void> _syncPlaylist(IptvPlaylist playlist) => _runImport(() async {
    final url = playlist.url;
    if (url == null) {
      return 0;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return 0;
    }
    final fetch = iptvFetcherFor(ref.read(httpProvider));
    final text = await fetch(uri);
    return await _library.importFromText(text, name: playlist.name, url: url, removeMissing: true);
  });

  Future<void> _deleteSource(String id) async {
    if (!await _confirmDeleteSource()) {
      return;
    }
    await _library.deletePlaylist(id);
  }

  /// Removes an Xtream source: the stored record and, when its import ever
  /// landed, the playlist record with it — the channels themselves follow
  /// the library's own delete discipline, as for any playlist.
  Future<void> _deleteXtreamSource(IptvXtreamSource source) async {
    if (!await _confirmDeleteSource()) {
      return;
    }
    final playlistId = xtreamPlaylistId(_library, source);
    if (playlistId != null) {
      await _library.deletePlaylist(playlistId);
    }
    await _setPreferences(
      (preferences) => preferences.copyWith(
        xtreamSources: [
          for (final kept in preferences.xtreamSources)
            if (kept.id != source.id) kept,
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteSource() async {
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
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    final playlists = library.playlists;
    final groups = library.groupNames;
    final group = _selectedGroup;
    final needle = _search.text.trim().toLowerCase();
    final xtreamSources = ref.watch(iptvPreferencesProvider).xtreamSources;
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
        // The IPTV tab is a chrome branch: a phone home tab carries the
        // top-left menu on its bar, a wide layout leaves it to the column.
        leading: HomeLayoutScope.maybeOf(context)?.phone == true ? const HomeMenuButton() : null,
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
            onPressed: _importing ? null : () => unawaited(_addSource()),
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
                          child: FeedChip(
                            label: name.isEmpty ? context.t.iptv.allGroups : name,
                            selected: _selectedGroup == name || (_selectedGroup == null && name.isEmpty),
                            onTap: () {
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
          if (playlists.isNotEmpty || xtreamSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: PureTextField(
                controller: _search,
                placeholder: context.t.iptv.search,
                prefix: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (playlists.isNotEmpty || xtreamSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final playlist in playlists)
                    if (!isXtreamPlaylistUrl(playlist.url))
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FeedChip(
                            label: '${playlist.name} (${playlist.channelCount})',
                            onDeleted: _importing ? null : () => unawaited(_deleteSource(playlist.id)),
                          ),
                          // A local file has no URL to read again — only a
                          // remote playlist gets the sync button (the
                          // reference's card, c4).
                          if (playlist.url != null && playlist.url!.isNotEmpty)
                            PureIconButton(
                              tooltip: context.t.iptv.refreshSource,
                              icon: Icons.sync,
                              onPressed: _importing ? null : () => unawaited(_syncPlaylist(playlist)),
                            ),
                        ],
                      ),
                  for (final source in xtreamSources)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FeedChip(
                          label: '${source.name} (${_xtreamChannelCount(source)})',
                          onDeleted: _importing ? null : () => unawaited(_deleteXtreamSource(source)),
                        ),
                        PureIconButton(
                          tooltip: context.t.iptv.refreshSource,
                          icon: Icons.refresh,
                          onPressed: _importing ? null : () => unawaited(_refreshXtream(source)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          // The guide sources (the reference's guide cards, trimmed to the
          // backed operations): each stored XMLTV source with its channel
          // count and a delete.
          if (library.guideSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.t.iptv.epgTitle,
                    style: PureTheme.of(context).text.caption
                        .copyWith(color: PureTheme.of(context).colors.textSecondary),
                  ),
                  for (final guide in library.guideSources)
                    FeedChip(
                      label: '${guide.name} (${library.guideChannels(guide.id).length})',
                      onDeleted: () => unawaited(library.deleteGuideSource(guide.id)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _channelList(context, channels, hasSources: playlists.isNotEmpty || xtreamSources.isNotEmpty),
          ),
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
