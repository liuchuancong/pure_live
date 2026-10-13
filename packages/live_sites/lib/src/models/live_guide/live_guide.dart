// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_catch_up/live_catch_up.dart';
import 'package:meta/meta.dart';

/// Everything IPTV-like about a room: the guide channel and programme on air,
/// the catch-up (time-shift) state, and the headers its media requests need.
///
/// These fields belong together — a plain live room has none — so the room
/// holds one `LiveGuide` rather than five loose IPTV fields. [httpHeaders] is
/// normalized (lower-cased names); it comes from the playlist, not a platform
/// response.
@immutable
final class LiveGuide {
  /// Creates the IPTV guide state.
  const LiveGuide({
    this.epgId,
    this.currentProgramme = '',
    this.currentProgrammeDescription,
    this.catchUp = const LiveCatchUp(),
    this.httpHeaders = const {},
  });

  /// Guide channel id.
  final String? epgId;

  /// Programme on air.
  final String currentProgramme;

  /// Description of the programme on air.
  final String? currentProgrammeDescription;

  /// Catch-up (time-shift) playback.
  final LiveCatchUp catchUp;

  /// Headers the channel's media requests need, normalized.
  final Map<String, String> httpHeaders;

  /// Whether a time-shifted programme is playing.
  bool get isCatchUpActive => catchUp.isActive;

  /// The guide with the played catch-up interval removed (back to live), so a
  /// later guide render never highlights a retired programme.
  LiveGuide withoutCatchUpInterval() => LiveGuide(
    epgId: epgId,
    currentProgramme: currentProgramme,
    currentProgrammeDescription: currentProgrammeDescription,
    catchUp: catchUp.withoutInterval(),
    httpHeaders: httpHeaders,
  );

  @override
  String toString() => 'LiveGuide($epgId, $currentProgramme)';
}
