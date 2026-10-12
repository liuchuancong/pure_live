import 'package:live_iptv/src/library/iptv_library/iptv_library.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_sites/live_sites.dart' as sites;

/// The library as the `live_sites` IPTV site's channel source: the site
/// layer exposes these through [sites.IptvSite] so IPTV channels play
/// through the ordinary playback stack.
///
/// The channels come out in zap order rather than in import order, because
/// the site's directory is what a screen lists and what a remote steps
/// through: the two must agree, or the sixth row of the list is not the
/// sixth channel the down key reaches. Hidden channels and hidden groups
/// are left out unless [includeHidden] asks for them, and the line of each
/// channel is the health-ranked candidate list, so a source that died on
/// the last probe hands the player its mirror instead of a dead URL.
///
/// This is the only place the two vocabularies meet: everything the IPTV
/// side knows about "a channel" stays in `live_iptv`, everything the site
/// side knows about "a room" stays in `live_sites`, and this file is the
/// translation between them.
final class LibraryIptvChannelSource implements sites.IptvChannelSource {
  /// A source over [library]; [includeHidden] keeps hidden channels out
  /// by default.
  new(this.library, {this.includeHidden = false});

  /// The library to read.
  final IptvLibrary library;

  /// Whether hidden channels are exposed.
  final bool includeHidden;

  @override
  List<sites.IptvChannel> get channels => [
    for (final channel in library.zapSequence(includeHidden: includeHidden).channels) _toSiteChannel(channel),
  ];

  @override
  sites.IptvChannel? channelById(String id) {
    // Looked up by id, a hidden channel is still there: [channels] is the
    // list the viewer walks, while an id is something a room already holds.
    // Refusing here would kill a stream the user is watching the moment
    // they hide its channel, and a hidden channel is a request to not be
    // offered it, not a request to be cut off from it.
    final channel = library.channelById(id);
    if (channel == null) {
      return null;
    }
    return _toSiteChannel(channel);
  }

  sites.IptvChannel _toSiteChannel(IptvChannel channel) => sites.IptvChannel(
    id: channel.id,
    name: channel.entry.name,
    url: channel.entry.url,
    group: channel.entry.group,
    headers: channel.entry.headers,
    epgChannelId: channel.entry.tvgId,
    favorite: channel.favorite,
    number: channel.number,
    lines: [
      for (final candidate in library.candidateLines(channel))
        sites.IptvLine(url: candidate.url, headers: candidate.headers, lineId: candidate.isHealthy ? 'healthy' : null),
    ],
  );
}
