import 'package:live_sites/live_sites.dart';

/// Why a room's stream could not be had for recording.
final class NoRecordableStream implements Exception {
  const NoRecordableStream(this.reason);

  /// The room is not broadcasting; the reference's recorder then keeps the
  /// task as waiting for the room to go live rather than starting a take.
  const NoRecordableStream.offline() : reason = 'offline';

  /// The room, its qualities or its lines could not be read, or offer
  /// nothing playable.
  const NoRecordableStream.noStream() : reason = 'no-stream';

  /// The stable reason word; the page maps it to the viewer's own words.
  final String reason;
}

/// Resolves the room behind [platform]/[roomId] to the line a recording
/// takes: the quality named by [qualityLabel] when the room offers it
/// (otherwise its first, the platform's best), the line beside it with the
/// headers its address needs.
///
/// The room's own API answers — the same call the player makes, run for the
/// recorder so a task whose room is not the open one records the real
/// current stream, not a stale address.
Future<LivePlayLine> resolveRecordableLine({
  required LiveSite site,
  required String platform,
  required String roomId,
  String qualityLabel = '',
}) async {
  final roomProvider = site.capability<LiveRoomProvider>();
  final playbackProvider = site.capability<LivePlaybackProvider>();
  if (roomProvider == null || playbackProvider == null) throw const NoRecordableStream.noStream();
  final roomAnswer = await roomProvider.getRoom(roomId);
  final room = roomAnswer.fold((_) => null, (answer) => answer);
  if (room == null) throw const NoRecordableStream.noStream();
  if (!room.broadcast.isLiveNow) throw const NoRecordableStream.offline();
  final qualitiesAnswer = await playbackProvider.getQualities(room: room);
  final qualities = qualitiesAnswer.fold((_) => const <LivePlayQuality>[], (answer) => answer);
  if (qualities.isEmpty) throw const NoRecordableStream.noStream();
  final wanted = qualityLabel.trim().toLowerCase();
  final quality = wanted.isEmpty
      ? qualities.first
      : qualities.where((item) => item.label.trim().toLowerCase() == wanted).firstOrNull ?? qualities.first;
  final linesAnswer = await playbackProvider.getLines(room: room, quality: quality);
  final lines = linesAnswer.fold((_) => const <LivePlayLine>[], (answer) => answer);
  if (lines.isEmpty) throw const NoRecordableStream.noStream();
  return lines.first;
}
