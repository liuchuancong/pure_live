/// The action represented by an IPTV programme at a specific wall-clock time.
///
/// Programme intervals are half-open: the start instant belongs to the live
/// programme, while the stop instant belongs to catch-up/history. Keeping this
/// rule in one pure helper prevents the schedule highlight and tap action from
/// disagreeing at exact EPG boundaries.
enum IptvProgrammePhase { scheduled, live, catchup }

enum CatchupUrlType { default_, playseek, offset }

enum IptvCatchupAvailability { available, disabled, outsideWindow, unsupported }

enum IptvProgrammeSelectionResult {
  scheduled,
  live,
  catchupStarted,
  catchupUnavailable,
  superseded,
  busy,
  invalidUrl,
  failed,
}

IptvProgrammePhase classifyIptvProgramme({required DateTime start, required DateTime stop, required DateTime now}) {
  if (now.isBefore(start)) return IptvProgrammePhase.scheduled;
  if (now.isBefore(stop)) return IptvProgrammePhase.live;
  return IptvProgrammePhase.catchup;
}

IptvCatchupAvailability evaluateIptvCatchupAvailability({
  required DateTime programmeStop,
  required DateTime now,
  String? mode,
  String? source,
  double? days,
  String? catchupId,
}) {
  final normalizedMode = mode?.trim().toLowerCase();
  if (const {'0', 'false', 'off', 'none', 'disabled'}.contains(normalizedMode) || days == 0) {
    return IptvCatchupAvailability.disabled;
  }
  final hasSource = source?.trim().isNotEmpty ?? false;
  final normalizedCatchupId = catchupId?.trim();
  if ((source?.contains('{catchup-id}') ?? false) && (normalizedCatchupId == null || normalizedCatchupId.isEmpty)) {
    return IptvCatchupAvailability.unsupported;
  }
  if (normalizedMode == 'vod' && !hasSource && (normalizedCatchupId == null || normalizedCatchupId.isEmpty)) {
    return IptvCatchupAvailability.unsupported;
  }
  const builtInModes = {
    'default',
    'append',
    'shift',
    'timeshift',
    'playseek',
    'offset',
    'flussonic',
    'flussonic-hls',
    'flussonic-ts',
    'fs',
    'xc',
    'vod',
  };
  if (normalizedMode != null && normalizedMode.isNotEmpty && !builtInModes.contains(normalizedMode) && !hasSource) {
    return IptvCatchupAvailability.unsupported;
  }
  if (days != null && days.isFinite && days > 0) {
    final window = Duration(microseconds: (days * Duration.microsecondsPerDay).round());
    if (programmeStop.isBefore(now.subtract(window))) {
      return IptvCatchupAvailability.outsideWindow;
    }
  }
  return IptvCatchupAvailability.available;
}

/// Builds the three legacy catch-up URL shapes without losing an existing
/// fragment or repeated query parameter.
///
/// [now] is injectable so offset URLs and their tests use one deterministic
/// clock snapshot. A future programme produces a zero offset rather than a
/// negative provider request.
String buildIptvCatchupUrl({
  required String originalUrl,
  required DateTime start,
  required DateTime stop,
  CatchupUrlType type = CatchupUrlType.default_,
  DateTime? now,
  String? mode,
  String? source,
  double? correctionHours,
  String? catchupId,
}) {
  if (!stop.isAfter(start)) {
    throw ArgumentError.value(stop, 'stop', 'Programme stop must be after its start');
  }
  final uri = Uri.parse(originalUrl.trim());
  if (uri.toString().isEmpty || !uri.hasScheme) {
    throw ArgumentError.value(originalUrl, 'originalUrl', 'Playback URL must include a scheme');
  }
  final startText = _compactDateTime(start);
  final stopText = _compactDateTime(stop);

  final normalizedMode = mode?.trim().toLowerCase();
  final normalizedSource = source?.trim();
  if ((normalizedMode != null && normalizedMode.isNotEmpty) || (normalizedSource?.isNotEmpty ?? false)) {
    if (const {'0', 'false', 'off', 'none', 'disabled'}.contains(normalizedMode)) {
      throw UnsupportedError('Catch-up is disabled for this channel');
    }
    final sourceTemplate = normalizedSource?.isNotEmpty == true ? normalizedSource! : null;
    final correctedStart = _corrected(start, correctionHours);
    final correctedStop = _corrected(stop, correctionHours);
    final clock = now ?? DateTime.now();
    if (normalizedMode == 'playseek' && sourceTemplate == null) {
      return _replaceQueryValue(
        uri,
        'playseek',
        '${_compactDateTime(correctedStart)}-${_compactDateTime(correctedStop)}',
      );
    }
    if (normalizedMode == 'offset' && sourceTemplate == null) {
      return _replaceQueryValues(uri, <String, String>{
        'catchup': 'default',
        'offset': _nonNegativeOffset(clock, correctedStart).toString(),
      });
    }
    if (normalizedMode == 'shift' || normalizedMode == 'timeshift') {
      const template = '?utc={utc}&lutc={lutc}';
      return _appendCatchupQuery(
        uri,
        _expandCatchupTemplate(template, start: correctedStart, stop: correctedStop, now: clock, catchupId: catchupId),
      );
    }
    if (normalizedMode == 'append') {
      if (sourceTemplate == null) {
        return _replaceQueryValue(
          uri,
          'playseek',
          '${_compactDateTime(correctedStart)}-${_compactDateTime(correctedStop)}',
        );
      }
      return _appendCatchupQuery(
        uri,
        _expandCatchupTemplate(
          sourceTemplate,
          start: correctedStart,
          stop: correctedStop,
          now: clock,
          catchupId: catchupId,
        ),
      );
    }
    if (const {'flussonic', 'flussonic-hls', 'flussonic-ts', 'fs'}.contains(normalizedMode)) {
      return _expandCatchupTemplate(
        _buildFlussonicCatchupTemplate(uri, normalizedMode!),
        start: correctedStart,
        stop: correctedStop,
        now: clock,
        catchupId: catchupId,
      );
    }
    if (normalizedMode == 'xc') {
      return _expandCatchupTemplate(
        _buildXtreamCodesCatchupTemplate(uri),
        start: correctedStart,
        stop: correctedStop,
        now: clock,
        catchupId: catchupId,
      );
    }
    if (normalizedMode == 'vod' && sourceTemplate == null) {
      final id = catchupId?.trim();
      if (id == null || id.isEmpty) throw const FormatException('Catch-up ID is missing');
      return _requireAbsoluteCatchupUrl(id);
    }
    if (sourceTemplate != null) {
      final expanded = _expandCatchupTemplate(
        sourceTemplate,
        start: correctedStart,
        stop: correctedStop,
        now: clock,
        catchupId: catchupId,
      );
      return _requireAbsoluteCatchupUrl(expanded);
    }
    if (normalizedMode == 'default') {
      return _replaceQueryValue(
        uri,
        'playseek',
        '${_compactDateTime(correctedStart)}-${_compactDateTime(correctedStop)}',
      );
    }
    throw UnsupportedError('Unsupported catch-up mode: $normalizedMode');
  }

  return switch (type) {
    CatchupUrlType.playseek => _replaceQueryValue(uri, 'playseek', '$startText-$stopText'),
    CatchupUrlType.offset => _replaceQueryValues(uri, <String, String>{
      'catchup': 'default',
      'offset': _nonNegativeOffset(now ?? DateTime.now(), start).toString(),
    }),
    CatchupUrlType.default_ => _replaceQueryValue(uri, 'timeshift', startText),
  };
}

DateTime _corrected(DateTime value, double? correctionHours) {
  if (correctionHours == null || !correctionHours.isFinite || correctionHours == 0) return value;
  return value.add(Duration(microseconds: (correctionHours * Duration.microsecondsPerHour).round()));
}

String _expandCatchupTemplate(
  String template, {
  required DateTime start,
  required DateTime stop,
  required DateTime now,
  String? catchupId,
}) {
  final startUtc = start.toUtc();
  final stopUtc = stop.toUtc();
  final nowUtc = now.toUtc();
  final startEpoch = startUtc.millisecondsSinceEpoch ~/ 1000;
  final stopEpoch = stopUtc.millisecondsSinceEpoch ~/ 1000;
  final nowEpoch = nowUtc.millisecondsSinceEpoch ~/ 1000;
  final duration = stopUtc.difference(startUtc).inSeconds;
  final offset = _nonNegativeOffset(nowUtc, startUtc);
  var result = template;

  result = _replaceFormattedTimestamp(result, 'utc', startUtc);
  result = _replaceFormattedTimestamp(result, 'start', startUtc, dollar: true);
  result = _replaceFormattedTimestamp(result, 'utcend', stopUtc);
  result = _replaceFormattedTimestamp(result, 'end', stopUtc, dollar: true);
  result = _replaceFormattedTimestamp(result, 'lutc', nowUtc);
  result = _replaceFormattedTimestamp(result, 'now', nowUtc, dollar: true);
  result = _replaceFormattedTimestamp(result, 'timestamp', nowUtc, dollar: true);

  for (final entry in <String, String>{
    '{utc}': '$startEpoch',
    r'${start}': '$startEpoch',
    '{utcend}': '$stopEpoch',
    r'${end}': '$stopEpoch',
    '{lutc}': '$nowEpoch',
    r'${now}': '$nowEpoch',
    r'${timestamp}': '$nowEpoch',
    '{duration}': '$duration',
    r'${duration}': '$duration',
    '{offset}': '$offset',
    r'${offset}': '$offset',
  }.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  result = _replaceDividedValue(result, 'duration', duration);
  result = _replaceDividedValue(result, 'offset', offset);
  if (catchupId != null && catchupId.trim().isNotEmpty) {
    result = result.replaceAll('{catchup-id}', catchupId.trim());
  }
  for (final entry in <String, String>{
    'Y': startUtc.year.toString().padLeft(4, '0'),
    'm': startUtc.month.toString().padLeft(2, '0'),
    'd': startUtc.day.toString().padLeft(2, '0'),
    'H': startUtc.hour.toString().padLeft(2, '0'),
    'M': startUtc.minute.toString().padLeft(2, '0'),
    'S': startUtc.second.toString().padLeft(2, '0'),
  }.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  if (RegExp(r'\$\{[^}]+\}|\{[^}]+\}').hasMatch(result)) {
    throw FormatException('Unsupported catch-up template field');
  }
  return result;
}

String _buildFlussonicCatchupTemplate(Uri uri, String mode) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.authority.isEmpty) {
    throw const FormatException('Flussonic catch-up requires an HTTP stream URL');
  }
  final path = uri.path;
  final slash = path.lastIndexOf('/');
  if (slash <= 0 || slash == path.length - 1) {
    throw const FormatException('Flussonic stream path is incomplete');
  }
  final directory = path.substring(0, slash);
  final file = path.substring(slash + 1);
  late final String catchupPath;
  if (file == 'mpegts') {
    catchupPath = '$directory/timeshift_abs-\${start}.ts';
  } else if (file.endsWith('.m3u8')) {
    final stem = file.substring(0, file.length - '.m3u8'.length);
    catchupPath = stem == 'index'
        ? '$directory/timeshift_rel-{offset:1}.m3u8'
        : '$directory/$stem-timeshift_rel-{offset:1}.m3u8';
  } else if (mode == 'fs' || mode == 'flussonic-ts') {
    catchupPath = '$directory/timeshift_abs-\${start}.ts';
  } else {
    catchupPath = '$directory/timeshift_rel-{offset:1}.m3u8';
  }
  return _replaceUriPath(uri, catchupPath);
}

String _buildXtreamCodesCatchupTemplate(Uri uri) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.authority.isEmpty || uri.query.isNotEmpty) {
    throw const FormatException('Xtream Codes catch-up URL is invalid');
  }
  final parts = uri.path.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.firstOrNull == 'live') parts.removeAt(0);
  if (parts.length != 3) throw const FormatException('Xtream Codes stream path is invalid');
  final username = parts[0];
  final password = parts[1];
  final channelFile = parts[2];
  final lowerChannelFile = channelFile.toLowerCase();
  final extension = lowerChannelFile.endsWith('.m3u8')
      ? channelFile.substring(channelFile.length - '.m3u8'.length)
      : lowerChannelFile.endsWith('.m3u')
      ? channelFile.substring(channelFile.length - '.m3u'.length)
      : '';
  final channelId = channelFile.substring(0, channelFile.length - extension.length);
  if (channelId.isEmpty || (extension.isEmpty && channelId.contains('.'))) {
    throw const FormatException('Xtream Codes channel ID is invalid');
  }
  final outputExtension = extension.isEmpty ? '.ts' : extension;
  final catchupPath = '/timeshift/$username/$password/{duration:60}/{Y}-{m}-{d}:{H}-{M}/$channelId$outputExtension';
  return _replaceUriPath(uri, catchupPath);
}

String _replaceUriPath(Uri uri, String path) {
  final query = uri.query.isEmpty ? '' : '?${uri.query}';
  final fragment = uri.fragment.isEmpty ? '' : '#${uri.fragment}';
  return '${uri.scheme}://${uri.authority}$path$query$fragment';
}

String _requireAbsoluteCatchupUrl(String value) {
  final uri = Uri.parse(value.trim());
  if (!uri.hasScheme) throw const FormatException('Catch-up source must include a scheme');
  return uri.toString();
}

String _replaceFormattedTimestamp(String input, String token, DateTime value, {bool dollar = false}) {
  final prefix = dollar ? r'\$\{' : r'\{';
  final pattern = RegExp('$prefix${RegExp.escape(token)}:([^}]+)\\}');
  return input.replaceAllMapped(pattern, (match) => _formatCatchupTimestamp(value, match.group(1)!));
}

String _formatCatchupTimestamp(DateTime value, String format) {
  final values = <String, String>{
    'Y': value.year.toString().padLeft(4, '0'),
    'm': value.month.toString().padLeft(2, '0'),
    'd': value.day.toString().padLeft(2, '0'),
    'H': value.hour.toString().padLeft(2, '0'),
    'M': value.minute.toString().padLeft(2, '0'),
    'S': value.second.toString().padLeft(2, '0'),
  };
  return format.split('').map((part) => values[part] ?? part).join();
}

String _replaceDividedValue(String input, String token, int value) {
  final escaped = RegExp.escape(token);
  final pattern = RegExp(r'(?:\$\{' + escaped + r':(\d+)\}|\{' + escaped + r':(\d+)\})');
  return input.replaceAllMapped(pattern, (match) {
    final divisor = int.parse(match.group(1) ?? match.group(2)!);
    if (divisor <= 0) throw FormatException('Catch-up template divisor must be positive');
    return '${value ~/ divisor}';
  });
}

String _appendCatchupQuery(Uri original, String suffix) {
  var query = suffix.trim();
  while (query.startsWith('?') || query.startsWith('&')) {
    query = query.substring(1);
  }
  if (query.isEmpty) throw FormatException('Catch-up append source is empty');
  final originalText = original.toString();
  final base = original.hasFragment ? originalText.substring(0, originalText.lastIndexOf('#')) : originalText;
  final separator = original.hasQuery && original.query.isNotEmpty ? '&' : '?';
  final fragment = original.hasFragment ? '#${original.fragment}' : '';
  return '$base$separator$query$fragment';
}

int _nonNegativeOffset(DateTime now, DateTime start) {
  final seconds = now.difference(start).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

String _compactDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}'
      '${two(value.month)}${two(value.day)}'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}';
}

String _replaceQueryValue(Uri uri, String key, String value) {
  return _replaceQueryValues(uri, <String, String>{key: value});
}

String _replaceQueryValues(Uri uri, Map<String, String> replacements) {
  final values = <String, dynamic>{
    for (final entry in uri.queryParametersAll.entries) entry.key: List<String>.from(entry.value),
  };
  for (final entry in replacements.entries) {
    values[entry.key] = entry.value;
  }
  return uri.replace(queryParameters: values).toString();
}
