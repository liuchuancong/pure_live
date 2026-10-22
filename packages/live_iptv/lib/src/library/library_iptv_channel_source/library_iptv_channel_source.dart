import 'package:live_iptv/src/library/iptv_library/iptv_library.dart';
import 'package:live_iptv/src/model/model.dart';

/// The library in zap order, as a screen lists and a remote steps through
/// it.
///
/// The channels come out in zap order rather than in import order, because
/// the list a screen shows and the order the remote steps must agree, or the
/// sixth row of the list is not the sixth channel the down key reaches.
/// Hidden channels and hidden groups are left out unless [includeHidden]
/// asks for them.
///
/// Lookup by id answers regardless of visibility: [channels] is the list the
/// viewer walks, while an id is something a player already holds. Refusing
/// here would kill a stream the user is watching the moment they hide its
/// channel, and a hidden channel is a request to not be offered it, not a
/// request to be cut off from it.
final class LibraryIptvChannelSource {
  /// A source over [library]; [includeHidden] keeps hidden channels out by
  /// default.
  new(this.library, {this.includeHidden = false});

  /// The library to read.
  final IptvLibrary library;

  /// Whether hidden channels are exposed.
  final bool includeHidden;

  /// The channels in zap order.
  List<IptvChannel> get channels => library.zapSequence(includeHidden: includeHidden).channels;

  /// The channel with [id], hidden or not; null when the id names nothing.
  IptvChannel? channelById(String id) => library.channelById(id);
}
