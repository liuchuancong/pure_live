/// IPTV for Pure Live.
///
/// `parsePlaylist` reads M3U (EXTINF attributes, EXTGRP, EXTVLCOPT/
/// KODIPROP options, `url|headers` tails, `tvg-chno`) and TXT (`name,url`,
/// `group,#genre#`, `#` alternatives) playlists tolerantly; `IptvLibrary`
/// persists the channels, playlists, group arrangement and line probe
/// verdicts through the `IptvStore` seam (the app's shared JSON store in production),
/// reconciles re-imports by URL so favourites, numbers, hiding and ordering
/// survive a playlist update, and `LibraryIptvChannelSource` reads the
/// library back in zap order, as the player and the screens list it.
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
///
/// An Xtream Codes account is read without a playlist at all:
/// `XtreamCatalogService` asks the server's player API for its live streams
/// and hands back ordinary `IptvChannel`s. A downloaded programme guide
/// becomes an `EpgGuide`, whose lookups answer what is on a channel now and
/// what comes next.
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
export 'src/xtream/xtream_catalog_service/xtream_catalog_service.dart';
