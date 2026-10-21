import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel, IptvLibrary;
import 'package:pure_live/app/app_providers.dart' show iptvLibraryProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_pill.dart';
import 'package:pure_live/system/navigation/app_router.dart' show IptvPlayRoute;
import 'package:pure_uikit/pure_uikit.dart';

/// IPTV on the ten-foot screen: the imported channels as a focus grid, the
/// favourites first when the switch is on — importing and editing stay on the
/// phone page, because a remote has no file picker.
///
/// One pill row: 刷新 re-reads the library, 收藏限 the wall to favourites.
/// Select plays the channel through the same route the phone list uses.
final class TvIptvView extends ConsumerStatefulWidget {
  /// The TV IPTV pane.
  const new({super.key});

  @override
  ConsumerState<TvIptvView> createState() => _TvIptvViewState();
}

final class _TvIptvViewState extends ConsumerState<TvIptvView> {
  bool _favoritesOnly = false;

  IptvLibrary get _library => ref.read(iptvLibraryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _library.load();
    if (mounted) {
      setState(() {});
    }
  }

  void _play(IptvChannel channel) {
    unawaited(IptvPlayRoute(channelId: channel.id, name: channel.entry.name).push<void>(context));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final channels =
        [
          for (final channel in _library.channels)
            if (!channel.hidden && (!_favoritesOnly || channel.favorite)) channel,
        ]..sort((a, b) {
          // Favourites and pins lead, then the file's own order.
          final aRank = (a.favorite ? 2 : 0) + (a.pinned ? 1 : 0);
          final bRank = (b.favorite ? 2 : 0) + (b.pinned ? 1 : 0);
          final rank = bRank.compareTo(aRank);
          return rank != 0 ? rank : a.position.compareTo(b.position);
        });

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.iptv.title, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(width: 12),
                Text('${channels.length}', style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
                const Spacer(),
                TvPill(
                  key: const ValueKey('tv-iptv-favorites'),
                  label: t.iptv.favoritesOnly,
                  selected: _favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                ),
                const SizedBox(width: 12),
                TvPill(
                  key: const ValueKey('tv-iptv-refresh'),
                  label: t.common.refresh,
                  onTap: () => unawaited(_load()),
                ),
              ],
            ),
          ),
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: PureEmpty(title: t.iptv.empty, icon: Icons.dns_outlined),
                  )
                : FocusTraversalGroup(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1600 ? 6 : (constraints.maxWidth >= 1100 ? 5 : 4);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(48, 16, 48, 48),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 3.2,
                          ),
                          itemCount: channels.length,
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            return TvPill(
                              key: ValueKey('tv-iptv-${channel.id}'),
                              label: channel.entry.name.isEmpty ? channel.entry.url : channel.entry.name,
                              autofocus: index == 0,
                              onTap: () => _play(channel),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
