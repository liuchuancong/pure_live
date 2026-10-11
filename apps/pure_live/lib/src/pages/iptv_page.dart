import 'package:flutter/material.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_log/live_log.dart';
import 'package:live_net/live_net.dart';
import 'package:live_uikit/live_uikit.dart';

import 'package:pure_live/src/services.dart';

/// The IPTV library: imported playlists, their channels, favourites.
///
/// The import path is the interesting part. A playlist is fetched with the
/// shared HTTP client, parsed by the IPTV package's tolerant parser, and
/// reconciled into the library by URL — so re-importing an updated playlist
/// keeps the user's favourites, hidden flags and ordering, and only the
/// channels the site actually removed disappear (and only when the user asks
/// for that). Nothing here knows M3U syntax; nothing in `live_iptv` knows
/// about this page.
class IptvPage extends StatefulWidget {
  /// An IPTV page over [services].
  const new({required this.services, super.key});

  /// The service graph.
  final PureLiveServices services;

  @override
  State<IptvPage> createState() => _IptvPageState();
}

class _IptvPageState extends State<IptvPage> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _importing = false;
  String? _importError;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    widget.services.iptv.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _importError = 'Enter a playlist address first.');
      return;
    }
    setState(() {
      _importing = true;
      _importError = null;
    });
    final log = widget.services.log.forCategory('app.iptv');
    final http = widget.services.http.create(profile: ClientProfile.media);
    try {
      final response = await http.send(LiveRequest.get(Uri.parse(url)));
      if (!response.isOk) {
        throw StateError('the server answered ${response.statusCode}');
      }
      final imported = await widget.services.iptv.importFromText(
        response.text,
        name: _name.text.trim().isEmpty ? Uri.parse(url).host : _name.text.trim(),
        url: url,
      );
      log.info('playlist imported', fields: {'imported': imported, 'total': widget.services.iptv.channels.length});
      _url.clear();
      _name.clear();
    } on Object catch (error, stack) {
      log.log(LogLevel.warning, 'importing $url failed', error: error, stackTrace: stack);
      if (mounted) {
        setState(() => _importError = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final environment = LiveEnvironmentScope.of(context);
    final geometry = theme.componentTheme;
    final library = widget.services.iptv;
    final channels = _showHidden ? library.channels : library.channels.where((c) => !c.hidden).toList();
    return Padding(
      padding: geometry.pagePaddingFor(environment.layoutMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'IPTV',
            style: environment.layoutMode == LiveLayoutMode.tv ? theme.typography.display : theme.typography.headline,
          ),
          SizedBox(height: geometry.sectionGap),
          LiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Import a playlist', style: theme.typography.subtitle.copyWith(color: theme.colors.textPrimary)),
                SizedBox(height: geometry.iconGap),
                LiveTextField(
                  controller: _url,
                  label: 'Playlist address',
                  hint: 'https://example.com/list.m3u',
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  errorText: _importError,
                ),
                SizedBox(height: geometry.iconGap),
                LiveTextField(controller: _name, label: 'Name (optional)', textInputAction: TextInputAction.done),
                SizedBox(height: geometry.sectionGap),
                Row(
                  children: [
                    LiveButton(
                      label: 'Import',
                      icon: Icons.download,
                      loading: _importing,
                      onPressed: _importing ? null : _import,
                    ),
                    SizedBox(width: geometry.iconGap),
                    LiveButton(
                      label: _showHidden ? 'Hide hidden channels' : 'Show hidden channels',
                      variant: LiveButtonVariant.text,
                      onPressed: () => setState(() => _showHidden = !_showHidden),
                    ),
                  ],
                ),
                SizedBox(height: geometry.iconGap),
                Text(
                  library.playlists.isEmpty
                      ? 'No playlist imported yet.'
                      : 'Imported: ${library.playlists.map((p) => '${p.name} (${p.channelCount})').join(', ')}',
                  style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(height: geometry.sectionGap),
          Expanded(
            child: channels.isEmpty
                ? const LiveEmptyView(
                    title: 'No channels',
                    message: 'Import an M3U or TXT playlist above; its channels appear here, grouped and favouritable.',
                  )
                : ListView.builder(
                    itemCount: channels.length,
                    itemBuilder: (context, index) => _ChannelTile(
                      channel: channels[index],
                      onToggleFavorite: () => library.toggleFavorite(channels[index].id),
                      onToggleHidden: () => library.toggleHidden(channels[index].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One channel row: name, group, URL, favourite and hide toggles.
class _ChannelTile extends StatelessWidget {
  const new({required this.channel, required this.onToggleFavorite, required this.onToggleHidden});

  final IptvChannel channel;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final entry = channel.entry;
    return Padding(
      padding: EdgeInsets.only(bottom: geometry.iconGap),
      child: LiveCard(
        dense: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name.isEmpty ? entry.url : entry.name,
                    style: theme.typography.body.copyWith(
                      color: channel.hidden ? theme.colors.textDisabled : theme.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${entry.group ?? 'Ungrouped'} · ${streamTypeOf(entry.url).name}',
                    style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
                  ),
                ],
              ),
            ),
            LiveIconButton(
              icon: channel.favorite ? Icons.star : Icons.star_border,
              tooltip: channel.favorite ? 'Remove from favourites' : 'Add to favourites',
              selected: channel.favorite,
              size: LiveControlSize.small,
              onPressed: onToggleFavorite,
            ),
            LiveIconButton(
              icon: channel.hidden ? Icons.visibility_off : Icons.visibility,
              tooltip: channel.hidden ? 'Show this channel' : 'Hide this channel',
              size: LiveControlSize.small,
              onPressed: onToggleHidden,
            ),
          ],
        ),
      ),
    );
  }
}
