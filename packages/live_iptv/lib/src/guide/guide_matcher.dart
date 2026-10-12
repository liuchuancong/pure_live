import 'package:live_iptv/src/model/model.dart';

/// Unique-only matching of playlist channels to the channels of one guide.
///
/// The rule that makes this safe to run unsupervised: a key that fits several
/// guide channels matches *none* of them. A playlist claiming "CCTV 1" where
/// the guide lists both CCTV 1 and CCTV 1 HD must not silently pick one — the
/// wrong programme list is worse than none, because it looks right.
///
/// The steps, in order: the channel's `tvg-id` equals a guide channel id
/// (case-insensitive); the channel's own id equals a guide id (older
/// playlists carry the guide id there); the normalized name equals a guide
/// name exactly; or one normalized name contains the other. Every step
/// requires its answer to be unique.
class GuideIndex {
  /// An index over the channels of one guide source.
  new(Iterable<EpgChannel> channels) {
    for (final channel in channels) {
      final id = channel.channelId.trim().toLowerCase();
      if (id.isNotEmpty) {
        (_byId[id] ??= []).add(channel.key);
      }
      final name = _name(channel.displayName);
      if (name.isNotEmpty) {
        (_byName[name] ??= []).add(channel.key);
      }
    }
  }

  final Map<String, List<String>> _byId = {};
  final Map<String, List<String>> _byName = {};
  final Map<String, String?> _nameMatches = {};

  static final RegExp _nonWord = RegExp('[^a-zA-Z0-9\u4e00-\u9fa5]');

  static String _name(String value) => value.toLowerCase().replaceAll(_nonWord, '');

  static String? _unique(List<String> keys) => keys.length == 1 ? keys.single : null;

  /// The guide channel key for [channel], or null.
  ///
  /// Name results are remembered per name: a playlist has hundreds of
  /// channels and testing each against every guide name is the expensive
  /// part, while many channels repeat a name family.
  String? match(IptvChannel channel) {
    final tvgId = channel.entry.tvgId?.trim().toLowerCase();
    final byTvgId = tvgId == null ? null : _byId[tvgId];
    if (byTvgId != null) {
      return _unique(byTvgId);
    }
    final legacy = _byId[channel.id.trim().toLowerCase()];
    if (legacy != null) {
      return _unique(legacy);
    }
    final name = _name(channel.entry.name);
    if (name.isEmpty) {
      return null;
    }
    if (_nameMatches.containsKey(name)) {
      return _nameMatches[name];
    }
    final exact = _byName[name];
    if (exact != null) {
      return _nameMatches[name] = _unique(exact);
    }
    String? found;
    for (final MapEntry(:key, :value) in _byName.entries) {
      if (name.contains(key) || key.contains(name)) {
        if (found != null || value.length != 1) {
          return _nameMatches[name] = null;
        }
        found = value.single;
      }
    }
    return _nameMatches[name] = found;
  }
}

/// The mapping changes for one playlist against one guide source.
///
/// Three rules, in the order they matter: a mapping the user locked or made
/// by hand is never touched; an automatic one follows the matcher (and is
/// rewritten when the matcher now prefers another channel); and an automatic
/// one that no longer matches anything is deleted. Missing input changes
/// nothing at all — an empty playlist or an empty guide is a download that
/// failed, and losing the user's mappings over it would be the opposite of
/// careful.
({List<EpgMapping> upserts, List<EpgMapping> deletes}) rebuildMappings({
  required String playlistId,
  required String sourceId,
  required List<IptvChannel> channels,
  required List<EpgChannel> guideChannels,
  required List<EpgMapping> previous,
}) {
  if (sourceId.isEmpty || channels.isEmpty || guideChannels.isEmpty) {
    return (upserts: const [], deletes: const []);
  }
  final byChannel = {for (final mapping in previous) mapping.channelId: mapping};
  final index = GuideIndex(guideChannels);
  final matched = <String>{};
  final upserts = <EpgMapping>[];
  for (final channel in channels) {
    final old = byChannel[channel.id];
    if (old != null && (old.locked || old.origin != epgAutoMappingOrigin)) {
      continue;
    }
    final key = index.match(channel);
    if (key == null) {
      continue;
    }
    matched.add(channel.id);
    if (old?.epgChannelKey == key && old?.epgSourceId == sourceId) {
      continue;
    }
    upserts.add(EpgMapping(channelId: channel.id, playlistId: playlistId, epgChannelKey: key, epgSourceId: sourceId));
  }
  final deletes = [
    for (final old in previous)
      if (!old.locked && old.origin == epgAutoMappingOrigin && !matched.contains(old.channelId)) old,
  ];
  return (upserts: upserts, deletes: deletes);
}

/// The guide channel key a room of [channel] takes its programmes from.
///
/// The order encodes the trust: a saved mapping first (and a locked one is
/// final even when its channel is gone — the user asked for that channel);
/// then `tvg-id`, which is the playlist's own claim about which guide
/// channel it is; then the name, normalized and with the words that every
/// Chinese channel shares (`综合`, `高清`, `中央`, …) removed, because a
/// guide's "CCTV1 综合" and a playlist's "CCTV-1 高清" are the same channel
/// while a plain substring test would pair "CCTV1" with "CCTV10".
String? resolveGuideChannel({
  required IptvChannel channel,
  required String sourceId,
  required List<EpgChannel> guideChannels,
  EpgMapping? mapping,
}) {
  if (sourceId.isEmpty) {
    return null;
  }
  if (mapping != null && mapping.epgSourceId == sourceId) {
    final resolved = resolveGuideReference(sourceId, mapping.epgChannelKey, guideChannels);
    if (resolved != null || mapping.locked) {
      return resolved;
    }
  }
  if (guideChannels.isEmpty) {
    return null;
  }
  final tvgId = channel.entry.tvgId?.trim().toLowerCase();
  if (tvgId != null && tvgId.isNotEmpty) {
    for (final guide in guideChannels) {
      if (guide.channelId.trim().toLowerCase() == tvgId) {
        return guide.key;
      }
    }
  }
  final target = _roomName(channel.entry.name);
  if (target.isEmpty) {
    return null;
  }
  final candidates = [
    for (final guide in guideChannels)
      if (_roomName(guide.displayName) case final name
          when name.isNotEmpty && (target.contains(name) || name.contains(target)))
        (guide: guide, name: name),
  ];
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort((a, b) {
    final aPerfect = a.name == target;
    final bPerfect = b.name == target;
    if (aPerfect != bPerfect) {
      return aPerfect ? -1 : 1;
    }
    if (aPerfect) {
      return 0;
    }
    return fuzzyScore(
      channel.entry.name,
      b.guide.displayName,
    ).compareTo(fuzzyScore(channel.entry.name, a.guide.displayName));
  });
  return candidates.first.guide.key;
}

/// The guide channel [reference] names inside [sourceId]: a storage key, or a
/// raw guide id.
///
/// Raw ids are accepted because rooms and mappings written before keys
/// existed carry them; the id counts only when exactly one channel has it,
/// for the same reason the matcher refuses ambiguous answers.
String? resolveGuideReference(String sourceId, String reference, Iterable<EpgChannel> guideChannels) {
  final matches = [
    for (final guide in guideChannels)
      if (guide.sourceId == sourceId && (guide.key == reference || guide.channelId == reference)) guide,
  ];
  for (final guide in matches) {
    if (guide.key == reference) {
      return guide.key;
    }
  }
  return matches.length == 1 ? matches.single.key : null;
}

final RegExp _roomSuffix = RegExp('(综合|高清|超清|中央|电视台|频道|hd)', caseSensitive: false);

/// A channel name reduced to what identifies it: the first word, lower case,
/// letters/digits/CJK only, with the words every channel shares removed.
String _roomName(String value) => value
    .trim()
    .split(' ')
    .first
    .toLowerCase()
    .replaceAll(RegExp('[^a-zA-Z0-9\u4e00-\u9fa5]'), '')
    .replaceAll(_roomSuffix, '')
    .trim();

/// How well [text] answers the words of [query]: 1 per word found, 0.5 per
/// word matched fuzzily, and 0 when any word is neither — a name that only
/// covers half the query is not a candidate at all.
double fuzzyScore(String query, String text) {
  final split = RegExp(r'[\s,|]+');
  final tokens = query.toLowerCase().split(split).where((token) => token.isNotEmpty).toList();
  if (tokens.isEmpty) {
    return 0;
  }
  final blob = text.toLowerCase();
  final words = blob.split(split).where((word) => word.isNotEmpty).toList();
  var score = 0.0;
  for (final token in tokens) {
    if (blob.contains(token)) {
      score += 1;
      continue;
    }
    var best = 0.0;
    for (final word in words) {
      final similarity = diceCoefficient(token, word);
      if (similarity > best) {
        best = similarity;
      }
    }
    if (best <= 0.6) {
      return 0;
    }
    score += 0.5;
  }
  return score;
}

/// Dice's coefficient over the letter pairs of [a] and [b], whitespace
/// removed: a cheap similarity that survives a typo, which is what a guide
/// name with a stray letter needs.
double diceCoefficient(String a, String b) {
  final first = a.replaceAll(RegExp(r'\s+'), '');
  final second = b.replaceAll(RegExp(r'\s+'), '');
  if (first == second) {
    return 1;
  }
  if (first.length < 2 || second.length < 2) {
    return 0;
  }
  final pairs = <String, int>{};
  for (var i = 0; i < first.length - 1; i++) {
    final pair = first.substring(i, i + 2);
    pairs[pair] = (pairs[pair] ?? 0) + 1;
  }
  var shared = 0;
  for (var i = 0; i < second.length - 1; i++) {
    final pair = second.substring(i, i + 2);
    final count = pairs[pair] ?? 0;
    if (count > 0) {
      pairs[pair] = count - 1;
      shared++;
    }
  }
  return 2 * shared / (first.length + second.length - 2);
}
