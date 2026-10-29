import 'package:media_core_audio/media_core_audio.dart' as audio;

/// lx-music's cross-source matching (`findMusic`): when a track's own source
/// cannot serve it, another platform's search answer is accepted only when it
/// is *the same song* — name, singers and album normalized, version suffixes
/// ignored, durations within five seconds.

/// Version suffixes lx-music strips before comparing titles.
const List<String> _versionChars = [
  '（live）',
  '(live)',
  ' live',
  '_live',
  '-live',
  '/live',
  '.live',
  '（inst）',
  '(inst)',
  '（acoustic）',
  '(acoustic)',
  '（remix）',
  '(remix)',
  '（cover）',
  '(cover)',
  '（demo）',
  '(demo)',
];

/// Normalizes a name the way lx-music compares songs: lowercased, spaces and
/// decorations dropped, version suffixes and bracketed extras stripped.
String normalizeSongName(String name) {
  var value = name.trim().toLowerCase();
  if (value.isEmpty) return value;
  for (final suffix in _versionChars) {
    if (value.endsWith(suffix)) value = value.substring(0, value.length - suffix.length);
  }
  return value
      .replaceAll(RegExp(r'[\(\[（【].*?[\)\]）】]'), '')
      .replaceAll(RegExp(r"[\s'：·，、—\-~/|]+"), '')
      .replaceAll('&nbsp;', '');
}

/// Whether [candidate] is the same song as [target] under lx-music's rule:
/// normalized name, singer and album (when both have one) must agree and the
/// durations must sit within five seconds.
bool isSameSong(audio.MusicTrack target, audio.MusicTrack candidate) {
  if (normalizeSongName(target.title) != normalizeSongName(candidate.title)) return false;
  if (normalizeSongName(target.artist) != normalizeSongName(candidate.artist)) return false;
  final targetAlbum = normalizeSongName(target.album);
  final candidateAlbum = normalizeSongName(candidate.album);
  if (targetAlbum.isNotEmpty && candidateAlbum.isNotEmpty && targetAlbum != candidateAlbum) return false;
  final targetDuration = target.duration?.inMilliseconds;
  final candidateDuration = candidate.duration?.inMilliseconds;
  if (targetDuration == null || candidateDuration == null) return true;
  return (targetDuration - candidateDuration).abs() <= 5000;
}

/// Picks [candidates]' same song as [target], preferring the earliest hit —
/// search answers are ranked, so lx-music takes the first match it sees.
audio.MusicTrack? findSameSong(audio.MusicTrack target, Iterable<audio.MusicTrack> candidates) {
  for (final candidate in candidates) {
    if (candidate.sourceId == target.sourceId) continue;
    if (isSameSong(target, candidate)) return candidate;
  }
  return null;
}
