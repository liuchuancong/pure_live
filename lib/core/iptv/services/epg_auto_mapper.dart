import '../models/epg.dart';
import '../models/channel.dart';
import 'package:string_similarity/string_similarity.dart';

/// Automatically maps provider channels to EPG channels using multiple
/// fuzzy matching strategies. Designed for epg.best and other XMLTV sources.
class EpgAutoMapper {
  /// Minimum confidence to auto-apply a mapping.
  static const double autoApplyThreshold = 0.70;

  /// Minimum confidence to suggest a mapping for user review.
  static const double suggestThreshold = 0.40;

  /// Run auto-mapping for a list of channels against available EPG channels.
  MappingStats mapAll({
    required List<Channel> channels,
    required List<EpgChannel> epgChannels,
    required Map<String, EpgMapping> existingMappings,
    required String epgSourceId,
    required Function(EpgMapping) onMapping,
  }) {
    final stopwatch = Stopwatch()..start();
    int mapped = 0, suggested = 0, unmapped = 0;

    // Build lookup indices for EPG channels
    final index = _EpgIndex.build(epgChannels);

    for (final channel in channels) {
      final key = '${channel.id}:${channel.providerId}';
      final existing = existingMappings[key];

      // Skip locked (manual) mappings
      if (existing != null && existing.locked) {
        mapped++;
        continue;
      }

      // 24/7 channels should not be matched with EPG guide at all —
      // they loop content and don't have scheduled programming.
      final is247 =
          channel.displayName.contains('24/7') ||
          channel.displayName.contains('24-7') ||
          (channel.groupTitle != null &&
              (channel.groupTitle!.contains('24/7') || channel.groupTitle!.contains('24-7')));

      if (is247) {
        unmapped++;
        continue;
      }

      final candidates = findCandidates(
        channel: channel,
        epgChannels: epgChannels,
        index: index,
        epgSourceId: epgSourceId,
      );

      if (candidates.isEmpty) {
        unmapped++;
        continue;
      }

      final best = candidates.first;

      // 0% confidence is not a real match — skip
      if (best.confidence <= 0.0) {
        unmapped++;
        continue;
      }

      final source = best.confidence >= autoApplyThreshold ? MappingSource.auto : MappingSource.suggested;

      if (source == MappingSource.auto) {
        mapped++;
      } else {
        suggested++;
      }

      onMapping(
        EpgMapping(
          playlistChannelId: channel.id,
          providerId: channel.providerId,
          epgChannelId: best.epgChannelId,
          epgSourceId: best.epgSourceId,
          confidence: best.confidence,
          source: source,
          locked: false,
          updatedAt: DateTime.now(),
        ),
      );
    }

    stopwatch.stop();
    return MappingStats(
      totalChannels: channels.length,
      mapped: mapped,
      suggested: suggested,
      unmapped: unmapped,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Find EPG channel candidates for a single provider channel.
  /// Returns candidates sorted by confidence (highest first).
  List<MappingCandidate> findCandidates({
    required Channel channel,
    required List<EpgChannel> epgChannels,
    Object? index,
    required String epgSourceId,
    bool exactOnly = false,
  }) {
    final idx = index is _EpgIndex ? index : _EpgIndex.build(epgChannels);
    final results = <String, _CandidateScore>{};

    // Strategy 1: Exact tvg-id match
    if (channel.tvgId != null && channel.tvgId!.isNotEmpty) {
      final exact = idx.byId[channel.tvgId!];
      if (exact != null) {
        _addScore(results, exact, 1.0, 'exact_tvg_id');
      }
    }

    // Strategy 2: Normalized ID match
    if (channel.tvgId != null && channel.tvgId!.isNotEmpty) {
      final normalized = _normalizeId(channel.tvgId!);
      final match = idx.byNormalizedId[normalized];
      if (match != null && !results.containsKey(match.id)) {
        _addScore(results, match, 0.95, 'normalized_id');
      }
    }

    // For 24/7 channels, skip fuzzy/number/logo matching
    if (!exactOnly) {
      // Strategy 3: Fuzzy name matching
      final channelName = _cleanChannelName(channel.displayName);
      if (channelName.isNotEmpty) {
        final nameResults = _fuzzyNameMatch(channelName, epgChannels);
        for (final (epgCh, score) in nameResults) {
          _addScore(results, epgCh, score, 'fuzzy_name');
        }
      }

      // Strategy 4: Channel number match
      if (channel.channelNumber != null) {
        final numStr = channel.channelNumber.toString();
        final match = idx.byNumber[numStr];
        if (match != null) {
          _addScore(results, match, 0.50, 'channel_number');
        }
      }

      // Strategy 5: Logo URL match
      if (channel.tvgLogo != null && channel.tvgLogo!.isNotEmpty) {
        final match = idx.byIconUrl[channel.tvgLogo!];
        if (match != null) {
          _addScore(results, match, 0.40, 'logo_url');
        }
      }
    }

    // Compute final confidence with corroboration boost
    final candidates = results.entries.map((entry) {
      final score = entry.value;
      final baseConfidence = score.maxScore;
      final corroboration = score.scores.where((s) => s > 0.3).fold(0.0, (sum, s) => sum + s * 0.1);
      final finalConfidence = (baseConfidence + corroboration).clamp(0.0, 1.0);

      return MappingCandidate(
        epgChannelId: entry.key,
        epgSourceId: epgSourceId,
        epgDisplayName: score.epgChannel.primaryName,
        confidence: finalConfidence,
        matchReasons: score.reasons,
      );
    }).toList();

    // Sort by confidence descending
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Return top 10 candidates
    return candidates.take(10).toList();
  }

  void _addScore(Map<String, _CandidateScore> results, EpgChannel epgChannel, double score, String reason) {
    final existing = results[epgChannel.id];
    if (existing != null) {
      existing.scores.add(score);
      existing.reasons.add(reason);
    } else {
      results[epgChannel.id] = _CandidateScore(epgChannel: epgChannel, scores: [score], reasons: [reason]);
    }
  }

  /// Clean channel name for matching.
  /// Handles pipe-separated names like "NY | New York | ABC 7 WABC"
  /// by using the most specific (last) segment.
  /// Also extracts parenthesized call signs for matching.
  String _cleanChannelName(String name) {
    // Split on pipe separators and use the last (most specific) segment
    final segments = name.split(RegExp(r'\s*\|\s*'));
    var cleaned = segments.last.trim();
    if (cleaned.isEmpty && segments.length > 1) {
      cleaned = segments[segments.length - 2].trim();
    }

    // Remove common prefixes: "US: ", "UK:", "USA - ", country codes
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z]{2,3}\s*[:|/\-]\s*', caseSensitive: false), '');
    // Remove "24/7" prefix
    cleaned = cleaned.replaceAll(RegExp(r'^24[/\-]7\s*', caseSensitive: false), '');

    // Extract call sign from parentheses like "(WABC)" and prepend it
    final callSignMatch = RegExp(r'\(([A-Z]{3,5})\)', caseSensitive: false).firstMatch(cleaned);
    if (callSignMatch != null) {
      final callSign = callSignMatch.group(1)!;
      // Use call sign as the primary name for matching
      cleaned = callSign;
    } else {
      // Remove quality suffixes
      cleaned = cleaned.replaceAll(RegExp(r'\s*(HD|FHD|UHD|4K|SD|HEVC|H\.?265|H\.?264)\s*', caseSensitive: false), ' ');
      // Remove parenthesized content like "(USA)", "(FHD)"
      cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    }

    // Collapse whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Normalize an ID for comparison.
  /// "ESPN_US_HD" → "espnus", "ESPN.us" → "espnus"
  /// Also extracts call signs: "abcwabc.us" → "wabcus", "ABC.(WABC).New.York,.NY.us" → "wabcus"
  String _normalizeId(String id) {
    var normalized = id.toLowerCase();

    // Extract call sign from parenthesized patterns like "ABC.(WABC).New.York"
    final parenMatch = RegExp(r'\((\w+)\)').firstMatch(normalized);
    if (parenMatch != null) {
      final callSign = parenMatch.group(1)!;
      // Extract country suffix (.us, .uk, etc.)
      final suffix = RegExp(r'\.(us|uk|ca|au|nz|de|fr|es|it|mx)$').firstMatch(normalized)?.group(0) ?? '';
      return (callSign + suffix).replaceAll(RegExp(r'[._\-\s]'), '');
    }

    // Handle "abcwabc.us" pattern — strip network prefix before call sign
    // Common US networks: abc, cbs, nbc, fox, pbs, cw
    final prefixMatch = RegExp(
      r'^(abc|cbs|nbc|fox|pbs|cw)(\w{3,})(.*)$',
    ).firstMatch(normalized.replaceAll(RegExp(r'[._\-\s]'), ''));
    if (prefixMatch != null) {
      final callSign = prefixMatch.group(2)!;
      final rest = prefixMatch.group(3)!;
      return callSign + rest;
    }

    // Remove separators
    normalized = normalized.replaceAll(RegExp(r'[._\-\s,]'), '');
    // Remove quality suffixes
    normalized = normalized.replaceAll(RegExp(r'(hd|fhd|uhd|4k|sd|hevc|h265|h264)'), '');
    // Remove geographic info (state, city fragments)
    normalized = normalized.replaceAll(
      RegExp(
        r'(newyork|losangeles|chicago|sanfrancisco|washington|detroit|denver|boston|houston|dallas|philadelphia|atlanta|miami|seattle|portland|phoenix|tampa)',
      ),
      '',
    );
    return normalized;
  }

  /// Fuzzy match a channel name against EPG channels.
  /// Returns (EpgChannel, score) pairs for matches above threshold.
  List<(EpgChannel, double)> _fuzzyNameMatch(String channelName, List<EpgChannel> epgChannels) {
    final results = <(EpgChannel, double)>[];
    final normalizedInput = channelName.toLowerCase();

    for (final epgCh in epgChannels) {
      double bestScore = 0;

      for (final epgName in epgCh.displayNames) {
        final normalizedEpg = epgName.toLowerCase();

        // Exact (case-insensitive)
        if (normalizedInput == normalizedEpg) {
          bestScore = 0.95;
          break;
        }

        // Contains match (one name contains the other)
        if (normalizedInput.contains(normalizedEpg) || normalizedEpg.contains(normalizedInput)) {
          final containsScore = 0.80;
          if (containsScore > bestScore) bestScore = containsScore;
        }

        // Token overlap (word set comparison)
        final inputTokens = normalizedInput.split(RegExp(r'\s+')).toSet();
        final epgTokens = normalizedEpg.split(RegExp(r'\s+')).toSet();
        if (inputTokens.isNotEmpty && epgTokens.isNotEmpty) {
          final intersection = inputTokens.intersection(epgTokens).length;
          final union = inputTokens.union(epgTokens).length;
          final jaccard = intersection / union;
          if (jaccard > bestScore) bestScore = jaccard;
        }

        // Jaro-Winkler similarity
        final jw = normalizedInput.similarityTo(normalizedEpg);
        if (jw > bestScore) bestScore = jw;
      }

      // Only include if score is genuinely high
      if (bestScore >= 0.55) {
        results.add((epgCh, bestScore.clamp(0.0, 0.95)));
      }
    }

    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results.take(20).toList();
  }
}

/// Internal score accumulator for a candidate.
class _CandidateScore {
  final EpgChannel epgChannel;
  final List<double> scores;
  final List<String> reasons;

  _CandidateScore({required this.epgChannel, required this.scores, required this.reasons});

  double get maxScore => scores.reduce((a, b) => a > b ? a : b);
}

/// Pre-built lookup indices for efficient EPG channel matching.
class _EpgIndex {
  final Map<String, EpgChannel> byId;
  final Map<String, EpgChannel> byNormalizedId;
  final Map<String, EpgChannel> byNumber;
  final Map<String, EpgChannel> byIconUrl;

  _EpgIndex._({required this.byId, required this.byNormalizedId, required this.byNumber, required this.byIconUrl});

  factory _EpgIndex.build(List<EpgChannel> channels) {
    final byId = <String, EpgChannel>{};
    final byNormalizedId = <String, EpgChannel>{};
    final byNumber = <String, EpgChannel>{};
    final byIconUrl = <String, EpgChannel>{};

    for (final ch in channels) {
      byId[ch.id] = ch;

      // Normalized ID
      var normalized = ch.id.toLowerCase().replaceAll(RegExp(r'[._\-\s]'), '');
      normalized = normalized.replaceAll(RegExp(r'(hd|fhd|uhd|4k|sd|hevc|h265|h264)'), '');
      byNormalizedId[normalized] = ch;

      if (ch.number != null) byNumber[ch.number!] = ch;
      if (ch.iconUrl != null) byIconUrl[ch.iconUrl!] = ch;
    }

    return _EpgIndex._(byId: byId, byNormalizedId: byNormalizedId, byNumber: byNumber, byIconUrl: byIconUrl);
  }
}
