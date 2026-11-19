import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The channel the module's embedded player is showing right now, by library
/// id — the channel list reads it to keep the on-air row marked and revealed,
/// and clears it when the player closes. Null while nothing plays.
final class IptvNowPlayingController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Marks [channelId] as the one on air.
  // ignore: use_setters_to_change_properties — reads as a verb at the call sites.
  void set(String channelId) => state = channelId;

  /// Clears the mark — the player went away.
  void clear() => state = null;

  /// Clears the mark only when it still names [channelId]: a player leaving
  /// while another has already taken the air leaves the newer mark be.
  void clearIf(String channelId) {
    if (state == channelId) state = null;
  }
}

/// The channel on air in the module's own player.
final iptvNowPlayingProvider = NotifierProvider<IptvNowPlayingController, String?>(IptvNowPlayingController.new);
