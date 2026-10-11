/// Catch-up (time-shift) playback: which past programmes a channel can
/// replay, and the URL that plays them.
///
/// The playlist decides this: a channel's `catchup`, `catchup-source` and
/// `catchup-days` attributes say whether the provider offers catch-up, with
/// which mode and template, and for how long. Building the URL is therefore
/// data-driven — a template with `{utc}`/`{start}`/`{duration}` fields, or
/// one of the handful of modes the ecosystem agreed on (`playseek`,
/// `timeshift`, Xtream Codes, Flussonic) — and never a guess.
library;

/// Where a programme stands at a wall-clock time. Intervals are half-open:
/// the start instant is already [live], the stop instant is already
/// [catchup].
enum IptvProgrammePhase {
  /// Not started yet.
  scheduled,

  /// On air right now.
  live,

  /// Finished; replayable if the channel has catch-up.
  catchup,
}

/// The catch-up URL shape used when the channel carries no catch-up mode or
/// template of its own.
enum CatchupUrlType {
  /// `timeshift=<start>` in local time.
  default_,

  /// `playseek=<start>-<stop>` in local time.
  playseek,

  /// `catchup=default&offset=<seconds since start>`.
  offset,
}

/// Whether a programme can be replayed at all.
enum IptvCatchupAvailability {
  /// It can.
  available,

  /// The channel turned catch-up off.
  disabled,

  /// It ended before the provider's archive window.
  outsideWindow,

  /// The provider's mode or template cannot build a URL for this programme.
  unsupported,
}

/// The modes that mean "catch-up is off", as providers write them in the
/// playlist attribute: a channel whose mode is one of these never offers a
/// replay, whatever its archive window says.
const Set<String> disabledCatchupModes = {'0', 'false', 'off', 'none', 'disabled'};

/// The modes this builder knows without a template.
const Set<String> _builtInModes = {
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

/// The phase of the programme `start`..`stop` at `now`.
IptvProgrammePhase classifyIptvProgramme({required DateTime start, required DateTime stop, required DateTime now}) {
  if (now.isBefore(start)) {
    return IptvProgrammePhase.scheduled;
  }
  if (now.isBefore(stop)) {
    return IptvProgrammePhase.live;
  }
  return IptvProgrammePhase.catchup;
}

/// Whether the programme ending at [programmeStop] can be replayed with the
/// channel's catch-up [mode], [source] template and [days] window.
///
/// The conditions are the provider's, in the order that matters: a mode that
/// means "off" or a zero window ends the question, a template needing a
/// catch-up id that the channel does not carry cannot be filled, an unknown
/// mode without a template cannot be built, and a programme older than the
/// window is simply gone. A caller that gets anything other than `available`
/// shows the programme as history and offers no replay.
IptvCatchupAvailability evaluateIptvCatchupAvailability({
  required DateTime programmeStop,
  required DateTime now,
  String? mode,
  String? source,
  double? days,
  String? catchupId,
}) {
  final normalizedMode = mode?.trim().toLowerCase();
  if (disabledCatchupModes.contains(normalizedMode) || days == 0) {
    return IptvCatchupAvailability.disabled;
  }
  final hasSource = source?.trim().isNotEmpty ?? false;
  final id = catchupId?.trim() ?? '';
  if ((source?.contains('{catchup-id}') ?? false) && id.isEmpty) {
    return IptvCatchupAvailability.unsupported;
  }
  if (normalizedMode == 'vod' && !hasSource && id.isEmpty) {
    return IptvCatchupAvailability.unsupported;
  }
  if (normalizedMode != null && normalizedMode.isNotEmpty && !_builtInModes.contains(normalizedMode) && !hasSource) {
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

/// The catch-up URL of the programme `start`..`stop` on the live stream
/// [originalUrl].
///
/// Existing fragments and repeated query values are kept: providers sign or
/// tokenise their URLs, and rebuilding the query from a map drops the second
/// value of a repeated parameter — which is exactly what makes a signed URL
/// stop working.
///
/// With a [mode] or [source] template the provider's own rules apply (after
/// shifting the times by [correctionHours], for providers whose playlist
/// times run on another clock): `playseek`, and `default`/`append` without a
/// template, set `playseek=<start>-<stop>` in local time; `offset` without a
/// template sets `catchup=default&offset=<seconds since start>`; `shift` and
/// `timeshift` append `utc=&lutc=`; `append` appends its expanded template;
/// the Flussonic modes and `xc` rewrite the path; `vod` without a template
/// plays the programme's [catchupId]; any other template must expand to an
/// absolute URL.
///
/// [now] fixes the clock used by `{lutc}`, `{offset}` and their relatives,
/// which makes the builder testable; a programme that has not started gives
/// an offset of zero rather than a negative one.
///
/// Throws an [ArgumentError] for a bad URL or interval, a [FormatException]
/// for a template it cannot fill, and an [UnsupportedError] when catch-up is
/// disabled or the mode is unknown.
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
  final clock = now ?? DateTime.now();
  final normalizedMode = mode?.trim().toLowerCase();
  final trimmedSource = source?.trim() ?? '';
  final template = trimmedSource.isNotEmpty ? trimmedSource : null;
  if ((normalizedMode != null && normalizedMode.isNotEmpty) || template != null) {
    if (disabledCatchupModes.contains(normalizedMode)) {
      throw UnsupportedError('Catch-up is disabled for this channel');
    }
    final from = _corrected(start, correctionHours);
    final to = _corrected(stop, correctionHours);
    String expand(String text) => _expandTemplate(text, start: from, stop: to, now: clock, catchupId: catchupId);
    String playseek() => _replaceQueryValues(uri, {'playseek': '${_compact(from)}-${_compact(to)}'});
    switch (normalizedMode) {
      case 'playseek' when template == null:
        return playseek();
      case 'offset' when template == null:
        return _replaceQueryValues(uri, {'catchup': 'default', 'offset': '${_nonNegativeOffset(clock, from)}'});
      case 'shift' || 'timeshift':
        return _appendQuery(uri, expand('?utc={utc}&lutc={lutc}'));
      case 'append':
        return template == null ? playseek() : _appendQuery(uri, expand(template));
      case 'flussonic' || 'flussonic-hls' || 'flussonic-ts' || 'fs':
        return expand(_flussonicTemplate(uri, normalizedMode!));
      case 'xc':
        return expand(_xtreamCodesTemplate(uri));
      case 'vod' when template == null:
        final id = catchupId?.trim();
        if (id == null || id.isEmpty) {
          throw const FormatException('Catch-up ID is missing');
        }
        return _requireAbsolute(id);
      case _:
        break;
    }
    if (template != null) {
      return _requireAbsolute(expand(template));
    }
    if (normalizedMode == 'default') {
      return playseek();
    }
    throw UnsupportedError('Unsupported catch-up mode: $normalizedMode');
  }
  return switch (type) {
    CatchupUrlType.playseek => _replaceQueryValues(uri, {'playseek': '${_compact(start)}-${_compact(stop)}'}),
    CatchupUrlType.offset => _replaceQueryValues(uri, {
      'catchup': 'default',
      'offset': '${_nonNegativeOffset(clock, start)}',
    }),
    CatchupUrlType.default_ => _replaceQueryValues(uri, {'timeshift': _compact(start)}),
  };
}

DateTime _corrected(DateTime value, double? hours) {
  if (hours == null || !hours.isFinite || hours == 0) {
    return value;
  }
  return value.add(Duration(microseconds: (hours * Duration.microsecondsPerHour).round()));
}

/// Expands a provider's template.
///
/// The field set is the one the ecosystem actually uses, in both spellings
/// (`{utc}` and `${start}`): epoch seconds, formatted date parts, the
/// programme's duration, the seconds since its start, and the catch-up id
/// for providers that replay by programme identity. Anything left
/// unexpanded afterwards is a field this builder does not know, and saying
/// so beats sending a URL with a literal `{utc}` in it.
String _expandTemplate(
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
  result = _replaceFormatted(result, 'utc', startUtc);
  result = _replaceFormatted(result, 'start', startUtc, dollar: true);
  result = _replaceFormatted(result, 'utcend', stopUtc);
  result = _replaceFormatted(result, 'end', stopUtc, dollar: true);
  result = _replaceFormatted(result, 'lutc', nowUtc);
  result = _replaceFormatted(result, 'now', nowUtc, dollar: true);
  result = _replaceFormatted(result, 'timestamp', nowUtc, dollar: true);
  for (final MapEntry(:key, :value) in {
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
    result = result.replaceAll(key, value);
  }
  result = _replaceDivided(result, 'duration', duration);
  result = _replaceDivided(result, 'offset', offset);
  final id = catchupId?.trim() ?? '';
  if (id.isNotEmpty) {
    result = result.replaceAll('{catchup-id}', id);
  }
  for (final MapEntry(:key, :value) in _fields(startUtc).entries) {
    result = result.replaceAll('{$key}', value);
  }
  if (RegExp(r'\$\{[^}]+\}|\{[^}]+\}').hasMatch(result)) {
    throw const FormatException('Unsupported catch-up template field');
  }
  return result;
}

Map<String, String> _fields(DateTime value) => {
  'Y': value.year.toString().padLeft(4, '0'),
  'm': value.month.toString().padLeft(2, '0'),
  'd': value.day.toString().padLeft(2, '0'),
  'H': value.hour.toString().padLeft(2, '0'),
  'M': value.minute.toString().padLeft(2, '0'),
  'S': value.second.toString().padLeft(2, '0'),
};

/// Flussonic's catch-up paths: the stream's own file name decides where the
/// archived segment lives (`mpegts` and `.ts` streams go absolute, `.m3u8`
/// goes relative to the programme's offset).
String _flussonicTemplate(Uri uri, String mode) {
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
  final String catchupPath;
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
  return _replacePath(uri, catchupPath);
}

/// Xtream Codes' catch-up path, which carries the account, the duration and
/// the programme's local start time.
String _xtreamCodesTemplate(Uri uri) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.authority.isEmpty || uri.query.isNotEmpty) {
    throw const FormatException('Xtream Codes catch-up URL is invalid');
  }
  final parts = uri.path.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.firstOrNull == 'live') {
    parts.removeAt(0);
  }
  if (parts.length != 3) {
    throw const FormatException('Xtream Codes stream path is invalid');
  }
  final [username, password, channelFile] = parts;
  final lower = channelFile.toLowerCase();
  final extension = lower.endsWith('.m3u8')
      ? channelFile.substring(channelFile.length - '.m3u8'.length)
      : lower.endsWith('.m3u')
      ? channelFile.substring(channelFile.length - '.m3u'.length)
      : '';
  final channelId = channelFile.substring(0, channelFile.length - extension.length);
  if (channelId.isEmpty || (extension.isEmpty && channelId.contains('.'))) {
    throw const FormatException('Xtream Codes channel ID is invalid');
  }
  final output = extension.isEmpty ? '.ts' : extension;
  return _replacePath(uri, '/timeshift/$username/$password/{duration:60}/{Y}-{m}-{d}:{H}-{M}/$channelId$output');
}

String _replacePath(Uri uri, String path) {
  final query = uri.query.isEmpty ? '' : '?${uri.query}';
  final fragment = uri.fragment.isEmpty ? '' : '#${uri.fragment}';
  return '${uri.scheme}://${uri.authority}$path$query$fragment';
}

String _requireAbsolute(String value) {
  final uri = Uri.parse(value.trim());
  if (!uri.hasScheme) {
    throw const FormatException('Catch-up source must include a scheme');
  }
  return uri.toString();
}

String _replaceFormatted(String input, String token, DateTime value, {bool dollar = false}) {
  final prefix = dollar ? r'\$\{' : r'\{';
  final pattern = RegExp('$prefix${RegExp.escape(token)}:([^}]+)\\}');
  return input.replaceAllMapped(pattern, (match) {
    final fields = _fields(value);
    return match.group(1)!.split('').map((part) => fields[part] ?? part).join();
  });
}

String _replaceDivided(String input, String token, int value) {
  final escaped = RegExp.escape(token);
  final pattern = RegExp(r'(?:\$\{' + escaped + r':(\d+)\}|\{' + escaped + r':(\d+)\})');
  return input.replaceAllMapped(pattern, (match) {
    final divisor = int.parse(match.group(1) ?? match.group(2)!);
    if (divisor <= 0) {
      throw const FormatException('Catch-up template divisor must be positive');
    }
    return '${value ~/ divisor}';
  });
}

String _appendQuery(Uri original, String suffix) {
  var query = suffix.trim();
  while (query.startsWith('?') || query.startsWith('&')) {
    query = query.substring(1);
  }
  if (query.isEmpty) {
    throw const FormatException('Catch-up append source is empty');
  }
  final text = original.toString();
  final base = original.hasFragment ? text.substring(0, text.lastIndexOf('#')) : text;
  final separator = original.hasQuery && original.query.isNotEmpty ? '&' : '?';
  final fragment = original.hasFragment ? '#${original.fragment}' : '';
  return '$base$separator$query$fragment';
}

int _nonNegativeOffset(DateTime now, DateTime start) {
  final seconds = now.difference(start).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// `yyyyMMddHHmmss` in local time: providers that take a calendar start
/// mean the viewer's clock, and a UTC programme time is converted to it
/// first so the same programme yields the same string everywhere.
String _compact(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}'
      '${two(local.month)}${two(local.day)}${two(local.hour)}${two(local.minute)}${two(local.second)}';
}

/// The URL with some query values replaced, keeping every other value —
/// including the repeats a signed URL carries.
String _replaceQueryValues(Uri uri, Map<String, String> replacements) {
  final values = <String, Object>{
    for (final MapEntry(:key, :value) in uri.queryParametersAll.entries) key: List<String>.of(value),
    ...replacements,
  };
  return uri.replace(queryParameters: values).toString();
}
