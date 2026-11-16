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

/// Picks [candidates]' same song as [target], the way lx-music's `findMusic`
/// does: the strictest reading first, then one concession at a time, and
/// never a candidate whose duration contradicts the target's.
///
/// A strict name+singer+album test alone loses the song to a site that writes
/// the featured artist differently (`A vs B`, `A、B`, a missing album field) —
/// which is exactly when 换源 matters most. The passes below are ordered by
/// how much they may be wrong: same everything, then singer allowed to differ
/// by one side's omission, then the name alone with the duration still held
/// as the hard gate. Search answers are ranked, so the first candidate of the
/// best pass wins.
audio.MusicTrack? findSameSong(audio.MusicTrack target, Iterable<audio.MusicTrack> candidates) {
  final pool = [
    for (final candidate in candidates)
      if (candidate.sourceId != target.sourceId) candidate,
  ];
  if (pool.isEmpty) return null;
  for (final pass in _passes) {
    for (final candidate in pool) {
      if (pass(target, candidate)) return candidate;
    }
  }
  return null;
}

/// Whether the two durations agree, or one side has none to disagree with.
/// The tolerance is a named value so the lyric walk can read wider — a
/// 重制版 between platforms drifts further than a plain re-encode.
bool _durationsAgree(audio.MusicTrack target, audio.MusicTrack candidate, {int toleranceMs = 5000}) {
  final targetDuration = target.duration?.inMilliseconds;
  final candidateDuration = candidate.duration?.inMilliseconds;
  if (targetDuration == null || candidateDuration == null) return true;
  return (targetDuration - candidateDuration).abs() <= toleranceMs;
}

/// The concession ladder, strictest first: everything the target names, then
/// the album allowed to go missing on one side, then the singer.
const List<bool Function(audio.MusicTrack, audio.MusicTrack)> _passes = [isSameSong, _sameNameAndSinger, _sameName];

/// Name and singer agree; an album is only compared when both sides have one.
bool _sameNameAndSinger(audio.MusicTrack target, audio.MusicTrack candidate) {
  if (normalizeSongName(target.title) != normalizeSongName(candidate.title)) return false;
  final targetSinger = normalizeSongName(target.artist);
  final candidateSinger = normalizeSongName(candidate.artist);
  if (targetSinger.isNotEmpty && candidateSinger.isNotEmpty && targetSinger != candidateSinger) return false;
  return _durationsAgree(target, candidate);
}

/// The name alone, with the duration as the only remaining gate — the reading
/// that still finds a song whose singer string no two sites write alike.
bool _sameName(audio.MusicTrack target, audio.MusicTrack candidate) =>
    normalizeSongName(target.title) == normalizeSongName(candidate.title) && _durationsAgree(target, candidate);

/// The singers, read as a set: the platforms write the same credits in every
/// order (`A、B` vs `B、A` vs `A/B`), and a feat. is a credit, not a new song.
Set<String> _artistSet(String artist) {
  final split = artist.replaceAll(RegExp(r'feat\.?|ft\.', caseSensitive: false), ',');
  return {
    for (final part in split.split(RegExp('[,、，/&+]')))
      if (normalizeSongName(part).isNotEmpty) normalizeSongName(part),
  };
}

/// Whether the two singer sets share a name, or one side named none to
/// disagree with.
bool _artistsAgree(audio.MusicTrack target, audio.MusicTrack candidate) {
  final targetSet = _artistSet(target.artist);
  final candidateSet = _artistSet(candidate.artist);
  if (targetSet.isEmpty || candidateSet.isEmpty) return true;
  return targetSet.intersection(candidateSet).isNotEmpty;
}

/// lx-music's `findMusic` with the lyric walk's own concessions: the singers
/// may write the same credits in any order and a 重制版's twelve seconds of
/// drift still counts as the song — a lyric needs the right *words*, and the
/// strict gate was refusing the recording that had them.
///
/// Used only where the answer is a lyric (the cross-source fallback and the
/// lyric walk); 换源 keeps [findSameSong]'s strict ladder, where a wrong
/// recording plays instead of merely singing the wrong words.
audio.MusicTrack? findSameSongLenient(audio.MusicTrack target, Iterable<audio.MusicTrack> candidates) {
  for (final candidate in candidates) {
    if (candidate.sourceId == target.sourceId) continue;
    if (normalizeSongName(target.title) != normalizeSongName(candidate.title)) continue;
    if (!_artistsAgree(target, candidate)) continue;
    if (!_durationsAgree(target, candidate, toleranceMs: 12000)) continue;
    return candidate;
  }
  return null;
}
