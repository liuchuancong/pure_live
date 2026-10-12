/// IPTV for Pure Live.
///
/// `parsePlaylist` reads M3U (EXTINF attributes, EXTGRP, EXTVLCOPT/
/// KODIPROP options, `url|headers` tails, `tvg-chno`) and TXT (`name,url`,
/// `group,#genre#`, `#` alternatives) playlists tolerantly; `IptvLibrary`
/// persists the channels, playlists, group arrangement and line probe
/// verdicts through the `IptvStore` seam (a Hivez box in production),
/// reconciles re-imports by URL so favourites, numbers, hiding and ordering
/// survive a playlist update, and `LibraryIptvChannelSource` exposes the
/// library through the live_sites IPTV site so channels play through the
/// ordinary playback stack.
///
/// Two things a remote control needs are modelled separately from the
/// playlist, because they belong to the viewer rather than to the source:
/// `IptvZapSequence`, the wrap-around walk the up and down keys take, and
/// `IptvChannel.number`, the number a viewer types. `IptvLineProber` asks a
/// channel's addresses how alive they are over an `IptvLineProbe` seam, and
/// the library turns the answers into the candidate order a player is handed.
/// The one implementation of that seam lives in `live_net_line_probe.dart`,
/// which adapts live_net's `MediaProbe` and is the only file here that knows
/// a transport exists.
library;

export 'src/catchup/catchup.dart';
export 'src/guide/guide.dart';
export 'src/import/iptv_import_result.dart';
export 'src/import/iptv_importer.dart';
export 'src/import/live_net_fetch.dart';
export 'src/library/library.dart';
export 'src/model/model.dart';
export 'src/order/iptv_channel_ordering.dart';
export 'src/order/iptv_zap_sequence.dart';
export 'src/playlist/playlist.dart';
export 'src/probe/probe.dart';
export 'src/sync/sync.dart';
