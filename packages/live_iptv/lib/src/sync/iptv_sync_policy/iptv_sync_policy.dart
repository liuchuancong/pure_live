// ignore_for_file: unnecessary_type_name_in_constructor -- this SDK has no
// `new.named` shorthand: a named constructor must repeat its type name.
import 'package:meta/meta.dart';

/// What a refresh round was told to do.
///
/// The policy is a value rather than a set of parameters because the app's
/// preferences own it: intervals, and whether automatic refresh is on at all.
/// Keeping it a plain record means `live_iptv` never imports the preferences
/// package — the caller reads its settings and hands over the decision, so a
/// test can ask for "every list, every hour" without a settings stack.
@immutable
class IptvSyncPolicy {
  /// A policy naming each interval and whether it is in force.
  const IptvSyncPolicy({
    required this.playlistInterval,
    required this.guideInterval,
    this.playlists = true,
    this.guides = true,
  });

  /// Nothing automatic: only a round the viewer starts by hand.
  const IptvSyncPolicy.manual()
    : playlistInterval = Duration.zero,
      guideInterval = Duration.zero,
      playlists = false,
      guides = false;

  /// How old a playlist's last import must be before it is re-downloaded.
  ///
  /// Zero means "every round", which is what a start-up refresh wants on a
  /// device whose clock may have been off for a week.
  final Duration playlistInterval;

  /// How old a guide's last refresh must be. Shorter than the playlists' by
  /// default: a programme list moves constantly while a channel list rarely
  /// changes at all.
  final Duration guideInterval;

  /// Whether playlists are refreshed automatically.
  final bool playlists;

  /// Whether guides are refreshed automatically.
  final bool guides;

  /// Whether this policy asks for anything at all.
  bool get isIdle => !playlists && !guides;

  /// A copy with the switches changed; the intervals ride along.
  IptvSyncPolicy copyWith({bool? playlists, bool? guides}) => IptvSyncPolicy(
    playlistInterval: playlistInterval,
    guideInterval: guideInterval,
    playlists: playlists ?? this.playlists,
    guides: guides ?? this.guides,
  );

  @override
  bool operator ==(Object other) =>
      other is IptvSyncPolicy &&
      other.playlistInterval == playlistInterval &&
      other.guideInterval == guideInterval &&
      other.playlists == playlists &&
      other.guides == guides;

  @override
  int get hashCode => Object.hash(playlistInterval, guideInterval, playlists, guides);

  @override
  String toString() {
    final playlist = playlists ? '${playlistInterval.inMinutes}min' : 'off';
    final guide = guides ? '${guideInterval.inMinutes}min' : 'off';
    return 'IptvSyncPolicy(playlists: $playlist, guides: $guide)';
  }
}
