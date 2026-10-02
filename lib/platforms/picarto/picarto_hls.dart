import 'dart:convert';

import 'package:pure_live/model/live_play_quality.dart';

import 'picarto_api.dart';

/// Quality identity excludes CDN host, signed path and fluctuating bandwidth.
/// Metadata and URLs are paired while walking the playlist, not by array index.
List<LivePlayQuality> parsePicartoHls(String content, Uri master) {
  if (content.length > 1024 * 1024 || content.trimLeft().split('\n').first.trim() != '#EXTM3U') {
    throw const PicartoException(PicartoFailure.schema);
  }
  final grouped = <String, ({String label, int rank, Set<String> urls})>{};
  Map<String, String>? pending;
  var hasExternalAudio = false;
  var hasMedia = false;
  var hasMediaUri = false;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-MEDIA:') && line.contains('TYPE=AUDIO') && line.contains('URI=')) {
      hasExternalAudio = true;
    }
    if (line.startsWith('#EXTINF:')) hasMedia = true;
    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      if (pending != null) throw const PicartoException(PicartoFailure.schema);
      pending = {
        for (final match in RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(line.substring(18)))
          match.group(1)!: match.group(2)!.replaceAll('"', ''),
      };
      continue;
    }
    if (line.isEmpty || line.startsWith('#')) continue;
    if (pending == null) {
      if (hasMedia) {
        final segment = master.resolve(line);
        if (!{'http', 'https'}.contains(segment.scheme) || segment.host.isEmpty || segment.userInfo.isNotEmpty) {
          throw const PicartoException(PicartoFailure.schema);
        }
        hasMediaUri = true;
      }
      continue;
    }
    final attrs = pending;
    pending = null;
    final uri = master.resolve(line);
    if (!{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const PicartoException(PicartoFailure.schema);
    }
    final bandwidth = int.tryParse(attrs['BANDWIDTH'] ?? '');
    final resolution = attrs['RESOLUTION'] ?? '';
    final size = RegExp(r'^([1-9][0-9]*)x([1-9][0-9]*)$').firstMatch(resolution);
    final fps = double.tryParse(attrs['FRAME-RATE'] ?? '0');
    if (bandwidth == null ||
        bandwidth <= 0 ||
        (resolution.isNotEmpty && size == null) ||
        fps == null ||
        !fps.isFinite ||
        fps < 0) {
      throw const PicartoException(PicartoFailure.schema);
    }
    final codec = attrs['CODECS'] ?? '';
    final id = jsonEncode([resolution, fps, codec, attrs['VIDEO'], attrs['AUDIO'], if (size == null) bandwidth]);
    final label = size == null
        ? 'HLS ${(bandwidth / 1000000).toStringAsFixed(1)} Mbps'
        : '${size.group(2)}p${fps > 0 ? ' ${fps == fps.roundToDouble() ? fps.toInt() : fps}fps' : ''}';
    final previous = grouped[id];
    grouped[id] = (
      label: previous?.label ?? label,
      rank: bandwidth > (previous?.rank ?? 0) ? bandwidth : previous!.rank,
      urls: {...?previous?.urls, uri.toString()},
    );
  }
  if (pending != null || (grouped.isEmpty && !hasMediaUri)) throw const PicartoException(PicartoFailure.schema);
  // A bare video variant would drop external audio. Preserve the master and
  // explicitly expose automatic HLS selection instead of claiming a tier.
  if (hasExternalAudio || grouped.isEmpty) {
    return [
      LivePlayQuality(id: 'master', quality: 'HLS Auto', data: List<String>.unmodifiable([master.toString()])),
    ];
  }
  return grouped.entries
      .map(
        (e) => LivePlayQuality(
          id: e.key,
          quality: e.value.label,
          sort: e.value.rank,
          data: List<String>.unmodifiable(e.value.urls),
        ),
      )
      .toList()
    ..sort((a, b) => b.sort.compareTo(a.sort));
}
