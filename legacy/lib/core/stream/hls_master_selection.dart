import 'dart:convert';

/// Explicit video/rendition selection, never a guessed ABR choice. The selected
/// master retains external audio rather than handing native a video-only child.
final class HlsMasterSelection {
  HlsMasterSelection._(this.source, this.video, this.audio);
  final Uri source;
  final Uri video;
  final Uri? audio;

  static HlsMasterSelection fromMaster(String text, {required Uri source, required Uri video, Uri? audio}) {
    return HlsMasterPlaylist.parse(source, text).select(video: video, audio: audio);
  }

  String rewrite(Uri source, String text) {
    if (source != this.source) throw const FormatException('Selected HLS master source changed');
    final master = HlsMasterPlaylist.parse(source, text);
    final (variant, rendition) = master._select(video, audio);
    return [
      ...master._prefix,
      if (rendition != null) rendition.line,
      variant.line,
      variant.uri.toString(),
      '',
    ].join('\n');
  }
}

final class HlsMasterVariant {
  HlsMasterVariant._(this.uri, this.line, Map<String, String> attributes) : attributes = Map.unmodifiable(attributes);
  final Uri uri;
  final String line;
  final Map<String, String> attributes;
}

/// Bounded ordinary HLS master contract used only by explicit selection.
/// Unsupported renditions/session tags fail closed here; legacy ABR inputs are
/// untouched. No language, camera, subtitle or encryption contract is discarded.
final class HlsMasterPlaylist {
  HlsMasterPlaylist._(this.source, this._prefix, List<HlsMasterVariant> variants, this._audio)
    : variants = List.unmodifiable(variants);
  final Uri source;
  final List<String> _prefix;
  final List<HlsMasterVariant> variants;
  final List<({Uri uri, String line, String group})> _audio;

  static HlsMasterPlaylist parse(Uri source, String text) {
    _resolve(source, source.toString());
    if (text.length > 4 * 1024 * 1024 || utf8.encode(text).length > 4 * 1024 * 1024) {
      throw const FormatException('HLS master exceeds byte budget');
    }
    final lines = const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.first != '#EXTM3U') throw const FormatException('Expected HLS master');
    final prefix = <String>['#EXTM3U'];
    final variants = <HlsMasterVariant>[];
    final audio = <({Uri uri, String line, String group})>[];
    final audioNames = <(String, String)>{};
    final audioUris = <Uri>{};
    final videoUris = <Uri>{};
    String? pending;
    var version = false;
    var independent = false;
    for (final line in lines.skip(1)) {
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        if (pending != null || variants.length >= 32) throw const FormatException('Invalid HLS variant count');
        pending = line;
      } else if (line.startsWith('#EXT-X-MEDIA:')) {
        if (pending != null || audio.length >= 32) throw const FormatException('Invalid HLS rendition placement');
        final attrs = _attributes(line.substring(13));
        if (attrs['TYPE'] != 'AUDIO' ||
            (attrs['GROUP-ID'] ?? '').isEmpty ||
            (attrs['NAME'] ?? '').isEmpty ||
            attrs.keys.any(
              (key) => !const {
                'TYPE',
                'GROUP-ID',
                'NAME',
                'URI',
                'DEFAULT',
                'AUTOSELECT',
                'LANGUAGE',
                'CHANNELS',
                'CHARACTERISTICS',
              }.contains(key),
            )) {
          throw const FormatException('Unsupported HLS rendition');
        }
        for (final key in ['DEFAULT', 'AUTOSELECT']) {
          if (attrs.containsKey(key) && !const {'YES', 'NO'}.contains(attrs[key])) {
            throw const FormatException('Invalid HLS audio flags');
          }
        }
        final uri = _resolve(source, attrs['URI'] ?? '');
        if (!audioNames.add((attrs['GROUP-ID']!, attrs['NAME']!)) || !audioUris.add(uri)) {
          throw const FormatException('Ambiguous HLS rendition identity');
        }
        audio.add((uri: uri, line: line, group: attrs['GROUP-ID']!));
      } else if (line.startsWith('#EXT-X-VERSION:')) {
        if (pending != null || version || !RegExp(r'^[1-9]\d*$').hasMatch(line.substring(15))) {
          throw const FormatException('Invalid HLS version');
        }
        version = true;
        prefix.add(line);
      } else if (line == '#EXT-X-INDEPENDENT-SEGMENTS') {
        if (pending != null || independent) throw const FormatException('Invalid HLS independence tag');
        independent = true;
        prefix.add(line);
      } else if (line.startsWith('#')) {
        if (line.startsWith('#EXT')) throw const FormatException('Unsupported HLS master tag');
      } else {
        if (pending == null) throw const FormatException('Unexpected HLS URI');
        final attrs = _attributes(pending.substring(18));
        final rate = int.tryParse(attrs['BANDWIDTH'] ?? '');
        if (rate == null ||
            rate <= 0 ||
            rate > 9007199254740991 ||
            attrs.keys.any(
              (key) => !const {
                'BANDWIDTH',
                'AVERAGE-BANDWIDTH',
                'RESOLUTION',
                'CODECS',
                'FRAME-RATE',
                'AUDIO',
                'CLOSED-CAPTIONS',
              }.contains(key),
            ) ||
            (attrs.containsKey('CLOSED-CAPTIONS') && attrs['CLOSED-CAPTIONS'] != 'NONE')) {
          throw const FormatException('Unsupported HLS variant');
        }
        if (attrs.containsKey('AVERAGE-BANDWIDTH')) {
          final average = int.tryParse(attrs['AVERAGE-BANDWIDTH']!);
          if (average == null || average <= 0 || average > 9007199254740991) {
            throw const FormatException('Invalid HLS average bandwidth');
          }
        }
        if (attrs.containsKey('RESOLUTION') && !RegExp(r'^[1-9]\d{0,4}x[1-9]\d{0,4}$').hasMatch(attrs['RESOLUTION']!)) {
          throw const FormatException('Invalid HLS resolution');
        }
        if (attrs.containsKey('FRAME-RATE')) {
          final frames = double.tryParse(attrs['FRAME-RATE']!);
          if (frames == null || !frames.isFinite || frames <= 0 || frames > 1000) {
            throw const FormatException('Invalid HLS frame rate');
          }
        }
        if (attrs['CODECS'] == '') throw const FormatException('Empty HLS codecs');
        final uri = _resolve(source, line);
        if (!videoUris.add(uri)) throw const FormatException('Ambiguous HLS variant identity');
        variants.add(HlsMasterVariant._(uri, pending, attrs));
        pending = null;
      }
    }
    if (pending != null || variants.isEmpty) throw const FormatException('Incomplete HLS master');
    if (videoUris.contains(source) || audioUris.contains(source) || videoUris.any(audioUris.contains)) {
      throw const FormatException('Cyclic or overlapping HLS media selection');
    }
    for (final variant in variants) {
      final group = variant.attributes['AUDIO'];
      if (group != null && (group.isEmpty || !audio.any((item) => item.group == group))) {
        throw const FormatException('Missing HLS audio group');
      }
    }
    return HlsMasterPlaylist._(source, prefix, variants, audio);
  }

  /// Select from an already parsed master when inspecting all offered variants.
  HlsMasterSelection select({required Uri video, Uri? audio}) {
    final selected = _select(video, audio);
    return HlsMasterSelection._(source, video, selected.$2?.uri);
  }

  (HlsMasterVariant, ({Uri uri, String line, String group})?) _select(Uri video, Uri? selectedAudio) {
    final matches = variants.where((variant) => variant.uri == video).toList();
    if (matches.length != 1) throw const FormatException('Selected HLS video is unavailable');
    final variant = matches.single;
    final group = variant.attributes['AUDIO'];
    if (group == null) {
      if (selectedAudio != null) throw const FormatException('Selected HLS audio is not associated with video');
      return (variant, null);
    }
    final choices = _audio
        .where((item) => item.group == group && (selectedAudio == null || item.uri == selectedAudio))
        .toList();
    if (choices.length != 1) throw const FormatException('Explicit HLS audio selection required');
    return (variant, choices.single);
  }
}

Uri _resolve(Uri source, String text) {
  final uri = source.resolve(text);
  if (!const {'http', 'https'}.contains(source.scheme) ||
      source.host.isEmpty ||
      source.userInfo.isNotEmpty ||
      source.hasFragment ||
      text.isEmpty ||
      text.length > 65536 ||
      text.contains(RegExp(r'[\x00-\x20\x7f]')) ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (source.scheme == 'https' && uri.scheme != 'https')) {
    throw const FormatException('Invalid HLS master URI');
  }
  return uri;
}

Map<String, String> _attributes(String text) {
  final values = <String, String>{};
  final pattern = RegExp(r'([A-Z0-9-]+)=("[^"\r\n\x00]*"|[^,\s"]+)(?:,|$)');
  var offset = 0;
  while (offset < text.length) {
    final match = pattern.matchAsPrefix(text, offset);
    if (match == null || values.containsKey(match[1])) throw const FormatException('Malformed HLS attributes');
    final value = match[2]!;
    values[match[1]!] = value.startsWith('"') ? value.substring(1, value.length - 1) : value;
    offset = match.end;
  }
  if (text.endsWith(',')) throw const FormatException('Incomplete HLS attributes');
  return values;
}
