import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel, IptvLibrary, iptvFetcherFor;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/iptv/iptv_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// IPTV: the imported playlists, their channels grouped, and the way a new
/// playlist enters the library — a name and a URL, fetched through the
/// shared client and reconciled into the library by URL.
///
/// Playback of a channel joins with the player-wave slice that teaches the
/// engine IPTV lines; this page is the library and its management.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV page.
  const new({super.key});

  @override
  ConsumerState<IptvPage> createState() => _IptvPageState();
}

final class _IptvPageState extends ConsumerState<IptvPage> {
  StreamSubscription<void>? _changes;
  String? _selectedGroup;
  bool _importing = false;

  IptvLibrary get _library => ref.read(iptvLibraryProvider);

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _addSource() async {
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
    setState(() => _importing = true);
    try {
      final fetch = iptvFetcherFor(ref.read(httpProvider));
      final text = await fetch(Uri.parse(form.url));
      final count = await _library.importFromText(text, name: form.name, url: form.url);
      if (mounted) {
        PureToast.show(context, context.t.iptv.imported(count: count), type: PureToastType.success);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, context.t.errors.network, type: PureToastType.error);
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
    final channels = [
      for (final channel in library.orderedChannels)
        if (group == null || channel.entry.group == group) channel,
    ];
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.iptv.title,
        actions: [
          PureIconButton(
            tooltip: context.t.iptv.addSource,
            icon: Icons.add_link,
            onPressed: _importing ? null : _addSource,
          ),
          const SettingsEntryButton(),
        ],
        bottom: groups.length > 1
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
                            onSelected: (_) => setState(() => _selectedGroup = name),
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
          Expanded(child: _channelList(context, channels)),
        ],
      ),
    );
  }

  Widget _channelList(BuildContext context, List<IptvChannel> channels) {
    if (_importing) {
      return const Center(child: PureSpinner(size: 40));
    }
    if (channels.isEmpty) {
      return PureEmpty(title: context.t.iptv.empty);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return PureListRow(
          leading: const Icon(Icons.live_tv_outlined),
          title: channel.entry.name,
          subtitle: channel.entry.group ?? '',
          onTap: () => IptvPlayRoute(channelId: channel.id, name: channel.entry.name).push<void>(context),
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
