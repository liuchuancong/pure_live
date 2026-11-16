import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart' show MusicPlaylistInfo;
import 'package:pure_live/modules/music/pages/music_online_playlists_view.dart'
    show MusicOnlinePlaylistBrowse, MusicOnlinePlaylistDetail;

/// 精选: the plaza's own browser on a rail entry of its own — the page the
/// 歌单 keeps behind its 在线 tab — with a playlist's detail opening in place.
final class MusicFeaturedView extends ConsumerStatefulWidget {
  const MusicFeaturedView({this.initialOnlineOpen, this.onOpened, super.key});

  /// The playlist another view (推荐's card) asked to open; taken once, when
  /// the view mounts.
  final MusicPlaylistInfo? initialOnlineOpen;

  /// Called as [initialOnlineOpen] is taken, so a later visit does not re-run
  /// it.
  final VoidCallback? onOpened;

  @override
  ConsumerState<MusicFeaturedView> createState() => MusicFeaturedViewState();
}

final class MusicFeaturedViewState extends ConsumerState<MusicFeaturedView> {
  /// The playlist opened to its tracks; null browses the plaza.
  MusicPlaylistInfo? _open;

  @override
  void initState() {
    super.initState();
    final info = widget.initialOnlineOpen;
    if (info == null) return;
    _open = info;
    widget.onOpened?.call();
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) return MusicOnlinePlaylistDetail(info: open, onBack: () => setState(() => _open = null));
    return MusicOnlinePlaylistBrowse(
      showTabs: false,
      heading: context.t.music.featuredTitle,
      onOpen: (info) => setState(() => _open = info),
    );
  }
}
