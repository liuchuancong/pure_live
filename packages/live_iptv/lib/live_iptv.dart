/// IPTV for Pure Live.
///
/// `parsePlaylist` reads M3U (EXTINF attributes, EXTGRP, EXTVLCOPT/
/// KODIPROP options, `url|headers` tails) and TXT (`name,url`,
/// `group,#genre#`, `#` alternatives) playlists tolerantly; `IptvLibrary`
/// persists the channels and playlists through the `IptvStore` seam
/// (live_storage preferences in production), reconciles re-imports by URL
/// so favourites, hiding and ordering survive a playlist update, and
/// `LibraryIptvChannelSource` exposes the library through the live_sites
/// IPTV site so channels play through the ordinary playback stack.
library;

export 'src/catchup/catchup.dart';
export 'src/library/iptv_library.dart';
export 'src/library/iptv_store.dart';
export 'src/model/iptv_models.dart';
export 'src/playlist/playlist_parser.dart';
