/// A capability smoke probe over every built-in live site.
///
/// Each site is asked for the things its capabilities promise, over the real
/// network, and every answer is judged: a `left` is a failure, an answer with
/// no content is a warning (a capability may legitimately be empty), and a
/// capability the site does not implement is skipped.
///
/// ```sh
/// dart run tool/capability_probe.dart                        # every site, every capability
/// dart run tool/capability_probe.dart --site=douyu,bilibili  # a subset of sites
/// dart run tool/capability_probe.dart --only=hot,room,lines  # a subset of capabilities
/// dart run tool/capability_probe.dart --room=douyu:12821     # pin the room under test
/// dart run tool/capability_probe.dart --deep                 # also read the first stream bytes
/// dart run tool/capability_probe.dart --inventory            # which site has which capability
/// dart run tool/capability_probe.dart --json=report.json     # machine-readable report
/// ```
///
/// Exit code: `0` when nothing failed, `1` when at least one check failed,
/// `2` for a bad invocation.
library;

// The unnamed constructor spells its class name; the `new` shorthand is not
// what a reader of this tool expects.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, exit, exitCode, stderr, stdout;

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';

/// Every check the probe knows, in the order a site runs them.
const List<String> _kChecks = <String>[
  'hot',
  'discovery',
  'areas',
  'areaRooms',
  'search',
  'suggest',
  'webSearch',
  'room',
  'roomList',
  'refresh',
  'recordRefresh',
  'status',
  'qualities',
  'lines',
  'plan',
  'superChat',
  'danmaku',
  'links',
  'anchor',
];

/// How many rooms the danmaku check may listen in before calling a chat
/// quiet: a big room's heat says nothing about how much people talk, so a
/// silent first room is retried in another one.
const int _kDanmakuRooms = 3;

/// How a check ended.
enum _Status { ok, warn, fail, skip }

/// One judged check.
final class _Check {
  _Check(this.site, this.capability, this.status, this.elapsed, this.detail);

  final String site;
  final String capability;
  final _Status status;
  final Duration elapsed;
  final String detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'site': site,
    'capability': capability,
    'status': status.name,
    'ms': elapsed.inMilliseconds,
    'detail': detail,
  };
}

typedef _Outcome = ({_Status status, String detail});

const _Outcome _skip = (status: _Status.skip, detail: 'not supported');

_Outcome _ok(String detail) => (status: _Status.ok, detail: detail);

_Outcome _warn(String detail) => (status: _Status.warn, detail: detail);

_Outcome _fail(String detail) => (status: _Status.fail, detail: detail);

/// [Either.fold] behind a plain call: returning it straight out of an async
/// function trips the analyzer's `async_return_with_no_await` heuristic.
_Outcome _judge<T>(
  Either<LiveSiteError, T> answer,
  _Outcome Function(LiveSiteError error) onLeft,
  _Outcome Function(T value) onRight,
) => answer.fold(onLeft, onRight);

/// What the probe was asked to do.
final class _Options {
  /// Defaults; the command line overwrites what it names.
  bool help = false;

  /// Print the site × capability matrix and exit without any request.
  bool inventory = false;

  /// Read the first bytes of the first play line (an actual stream check).
  bool deep = false;

  /// Print the capabilities a site does not implement as well.
  bool showSkips = false;

  final Set<String> sites = <String>{};
  final Set<String> checks = <String>{};
  final Set<String> skips = <String>{};
  final Map<String, String> rooms = <String, String>{};
  String query = 'lol';
  Duration timeout = const Duration(seconds: 20);
  Duration danmakuWait = const Duration(seconds: 10);
  int workers = 3;
  String? jsonPath;
  ProxyRoute? proxy;

  /// Whether [capability] is part of this run.
  bool wants(String capability) => !skips.contains(capability) && (checks.isEmpty || checks.contains(capability));
}

Future<void> main(List<String> argv) async {
  stdout.encoding = utf8;
  final options = _parseOptions(argv);
  if (options.help) {
    _printUsage();
    return;
  }
  final unknown = <String>{...options.checks, ...options.skips}.difference(_kChecks.toSet());
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown check(s): ${unknown.join(', ')}\nKnown: ${_kChecks.join(', ')}');
    exitCode = 2;
    return;
  }

  final transport = DioFactory(proxyPolicy: options.proxy == null ? null : FixedProxyPolicy(global: options.proxy))
      .create();
  final all = createBuiltInLiveSites(http: transport);
  final selected = <LiveSite>[
    for (final site in all)
      if (options.sites.isEmpty || options.sites.contains(site.manifest.id)) site,
  ];
  if (selected.isEmpty) {
    stderr.writeln('No site matches --site=${options.sites.join(',')}');
    exitCode = 2;
    return;
  }
  if (options.inventory) {
    _printInventory(selected);
    return;
  }

  final checksLabel = options.checks.isEmpty ? 'all' : options.checks.join(',');
  final skipLabel = options.skips.isEmpty ? '' : ', skipping ${options.skips.join(',')}';
  stdout.writeln('Probing ${selected.length} site(s), checks: $checksLabel$skipLabel | query "${options.query}"');
  final results = <_Check>[];
  var cursor = 0;
  Future<void> worker() async {
    while (cursor < selected.length) {
      final site = selected[cursor++];
      final own = await _probeSite(site, options, transport);
      results.addAll(own);
      _printBlock(site, own, options);
    }
  }

  final workerCount = options.workers.clamp(1, 8);
  await Future.wait(<Future<void>>[for (var index = 0; index < workerCount; index++) worker()]);

  final ordered = <_Check>[
    for (final site in selected)
      for (final check in results)
        if (check.site == site.manifest.id) check,
  ];
  _printSummary(ordered);
  final failed = ordered.where((check) => check.status == _Status.fail).length;
  final reportPath = options.jsonPath;
  if (reportPath != null) {
    final report = <String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'query': options.query,
      'sites': <String>[for (final site in selected) site.manifest.id],
      'summary': _countByStatus(ordered),
      'checks': <Map<String, Object?>>[for (final check in ordered) check.toJson()],
    };
    File(reportPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln('Report written to $reportPath');
  }
  // Sessions a timed-out check left behind keep sockets open; the probe
  // is done, so the process ends with its verdict rather than waiting
  // for every abandoned connection to wither.
  exit(failed == 0 ? 0 : 1);
}

/// Runs every enabled check against [site], in dependency order: a listing
/// gives a sample room, the room check pins the detail, and the playback,
/// chat and link checks read the best room this run has.
Future<List<_Check>> _probeSite(LiveSite site, _Options options, LiveHttp transport) async {
  final id = site.manifest.id;
  final checks = <_Check>[];
  LiveArea? area;
  LivePlayQuality? quality;
  Future<LiveRoom?>? sampleLookup;
  Future<LiveRoom?>? roomLookup;
  final sampledRooms = <String, LiveRoom>{};

  void remember(Iterable<LiveRoom> rooms) {
    for (final room in rooms) {
      final roomId = room.ref.roomId.trim();
      if (roomId.isNotEmpty) sampledRooms[roomId] = room;
    }
  }

  Future<void> run(String capability, Future<_Outcome> Function() body) async {
    if (!options.wants(capability)) return;
    final stopwatch = Stopwatch()..start();
    _Outcome outcome;
    try {
      final budget = capability == 'danmaku' ? options.timeout + options.danmakuWait * _kDanmakuRooms : options.timeout;
      outcome = await body().timeout(budget);
    } on TimeoutException {
      outcome = _fail('timed out');
    } on Object catch (error) {
      outcome = _fail('threw $error');
    }
    stopwatch.stop();
    checks.add(_Check(id, capability, outcome.status, stopwatch.elapsed, outcome.detail));
  }

  Future<LiveArea?> firstArea() async {
    final provider = site.capability<LiveAreaProvider>();
    if (provider == null) return null;
    final answer = await provider.getAreas();
    final area = answer.fold((_) => null, (areas) => areas.isEmpty ? null : areas.first);
    return area;
  }

  Future<LiveRoom?> loadSample() async {
    final hot = site.capability<LiveHotProvider>();
    if (hot != null) {
      final answer = await hot.getHotRooms(request: LivePageRequest.of());
      final first = answer.fold((_) => null, (page) => _firstRoom(page.items));
      if (first != null) return first;
    }
    final discovery = site.capability<LiveDiscoveryProvider>();
    if (discovery != null) {
      final answer = await discovery.getRecommendedRooms(request: LivePageRequest.of());
      final first = answer.fold((_) => null, (page) => _firstRoom(page.items));
      if (first != null) return first;
    }
    final areas = site.capability<LiveAreaProvider>();
    if (areas != null) {
      final opened = area ?? await firstArea();
      area = opened;
      if (opened != null) {
        final answer = await areas.getAreaRooms(area: opened, request: LivePageRequest.of());
        final first = answer.fold((_) => null, (page) => _firstRoom(page.items));
        if (first != null) return first;
      }
    }
    return null;
  }

  // One listing lookup and one room lookup per site: dependent checks reuse
  // the first answer, so a platform this network cannot reach costs one
  // timeout instead of one per capability.
  Future<LiveRoom?> sampleRoom() => sampleLookup ??= loadSample();

  Future<LiveRoom?> loadRoom() async {
    final pinned = options.rooms[id];
    final provider = site.capability<LiveRoomProvider>();
    if (pinned != null && provider != null) {
      final answer = await provider.getRoom(pinned);
      final room = answer.fold((_) => null, (value) => value);
      return room;
    }
    final seed = await sampleRoom();
    if (seed == null || provider == null) return seed;
    final answer = await provider.getRoom(seed.ref.roomId);
    final room = answer.fold((_) => seed, (value) => value);
    return room;
  }

  Future<LiveRoom?> currentRoom() => roomLookup ??= loadRoom();

  await run('hot', () async {
    final provider = site.capability<LiveHotProvider>();
    if (provider == null) return _skip;
    final answer = await provider.getHotRooms(request: LivePageRequest.of());
    return _judge(answer, (error) => _fail(_errorText(error)), (page) {
      remember(page.items);
      return _roomsOutcome(id, 'hot', page.items.toList());
    });
  });

  await run('discovery', () async {
    final provider = site.capability<LiveDiscoveryProvider>();
    if (provider == null) return _skip;
    final answer = await provider.getRecommendedRooms(request: LivePageRequest.of());
    return _judge(answer, (error) => _fail(_errorText(error)), (page) {
      remember(page.items);
      return _roomsOutcome(id, 'discovery', page.items.toList());
    });
  });

  await run('areas', () async {
    final provider = site.capability<LiveAreaProvider>();
    if (provider == null) return _skip;
    final answer = await provider.getAreas();
    return _judge(answer, (error) => _fail(_errorText(error)), (areas) {
      if (areas.isEmpty) return _warn('0 areas');
      area ??= areas.first;
      final malformed = areas.where((item) => item.areaId.trim().isEmpty || item.areaName.trim().isEmpty).length;
      final detail = '${areas.length} areas';
      return malformed == 0 ? _ok(detail) : _warn('$detail, $malformed malformed');
    });
  });

  await run('areaRooms', () async {
    final provider = site.capability<LiveAreaProvider>();
    if (provider == null) return _skip;
    final opened = area ?? await firstArea();
    area = opened;
    if (opened == null) return _warn('no area to open');
    final answer = await provider.getAreaRooms(area: opened, request: LivePageRequest.of());
    return _judge(answer, (error) => _fail('${opened.areaName}: ${_errorText(error)}'), (page) {
      remember(page.items);
      return _roomsOutcome(id, opened.areaName, page.items.toList());
    });
  });

  await run('search', () async {
    final provider = site.capability<LiveSearchProvider>();
    if (provider == null) return _skip;
    final target = provider.supportedTargets.contains(LiveSearchTarget.rooms)
        ? LiveSearchTarget.rooms
        : provider.supportedTargets.first;
    final answer = await provider.search(LiveSearchRequest.of(query: options.query, target: target));
    return _judge(answer, (error) => _fail(_errorText(error)), (page) {
      final items = page.items;
      if (items.isEmpty) return _warn('0 results for "${options.query}"');
      return _ok('${items.length} ${target.name} for "${options.query}"');
    });
  });

  await run('suggest', () async {
    final provider = site.capability<LiveSuggestCapability>();
    if (provider == null) return _skip;
    final words = await provider.suggestions(options.query);
    if (words.isEmpty) return _ok('no suggestions for "${options.query}"');
    return _ok('${words.length} suggestions: ${_clip(words.take(3).join(' | '))}');
  });

  await run('webSearch', () async {
    final provider = site.capability<LiveWebSearchProvider>();
    if (provider == null) return _skip;
    final descriptor = provider.createSearch(options.query);
    final uri = descriptor.uri;
    if (!_isHttp(uri.toString())) return _warn('bad web search address $uri');
    return _ok(uri.toString());
  });

  await run('room', () async {
    final provider = site.capability<LiveRoomProvider>();
    if (provider == null) return _skip;
    final pinned = options.rooms[id];
    final roomId = pinned ?? (await sampleRoom())?.ref.roomId;
    if (roomId == null) return _warn('no room id (listings came back empty)');
    final answer = await provider.getRoom(roomId);
    return _judge(answer, (error) => _fail('getRoom($roomId): ${_errorText(error)}'), (room) {
      roomLookup ??= Future<LiveRoom?>.value(room);
      final issues = _roomIssues(id, room);
      final title = room.content.title.trim();
      final detailText =
          'room ${room.ref.roomId} "${_clip(title)}" ${room.broadcast.effectiveLiveStatus.name}'
          '${issues.isEmpty ? '' : '; ${issues.join(', ')}'}';
      return title.isEmpty || issues.isNotEmpty ? _warn(detailText) : _ok(detailText);
    });
  });

  await run('roomList', () async {
    final provider = site.capability<LiveRoomProvider>();
    if (provider == null) return _skip;
    final answer = await provider.getRooms(LivePageRequest.of());
    return _judge(answer, (error) => _fail(_errorText(error)), (page) {
      remember(page.items);
      return _roomsOutcome(id, 'room list', page.items.toList());
    });
  });

  await run('refresh', () async {
    final provider = site.capability<LiveRoomRefresh>();
    if (provider == null) return _skip;
    final roomId = (await currentRoom())?.ref.roomId;
    if (roomId == null) return _warn('no room to refresh');
    final answer = await provider.getRoomForRefresh(roomId: roomId);
    return _judge(answer, (error) => _fail('$roomId: ${_errorText(error)}'), (room) {
      final title = room.content.title.trim();
      return title.isEmpty ? _warn('$roomId: no title in the refresh') : _ok('$roomId "${_clip(title)}"');
    });
  });

  await run('recordRefresh', () async {
    final provider = site.capability<LiveRoomRefresh>();
    if (provider == null) return _skip;
    final roomId = (await currentRoom())?.ref.roomId;
    if (roomId == null) return _warn('no room for the recording read');
    final answer = await provider.getRoomForRecording(roomId: roomId);
    return _judge(answer, (error) => _fail('$roomId: ${_errorText(error)}'), (room) {
      final title = room.content.title.trim();
      return title.isEmpty ? _warn('$roomId: no title in the recording read') : _ok('$roomId "${_clip(title)}"');
    });
  });

  await run('status', () async {
    final provider = site.capability<LiveStatusCheck>();
    if (provider == null) return _skip;
    final room = await currentRoom();
    if (room == null) return _warn('no room to ask about');
    final answer = await provider.getLiveStatus(room: room);
    return _judge(
      answer,
      (error) => _fail(_errorText(error)),
      (live) => _ok('${room.ref.roomId} is ${live ? 'live' : 'offline'}'),
    );
  });

  await run('qualities', () async {
    final provider = site.capability<LivePlaybackProvider>();
    if (provider == null) return _skip;
    final room = await currentRoom();
    if (room == null) return _warn('no room to ask about');
    final answer = await provider.getQualities(room: room);
    return _judge(answer, (error) => _fail(_errorText(error)), (items) {
      if (items.isEmpty) return _warn('0 qualities');
      quality = items.first;
      return _ok('${items.length} qualities: ${items.map((item) => item.label).take(4).join(', ')}');
    });
  });

  await run('lines', () async {
    final provider = site.capability<LivePlaybackProvider>();
    if (provider == null) return _skip;
    final room = await currentRoom();
    if (room == null) return _warn('no room to ask about');
    final answer = await provider.getLines(room: room, quality: quality);
    final failure = answer.fold<LiveSiteError?>((error) => error, (_) => null);
    if (failure != null) return _fail(_errorText(failure));
    final lines = answer.fold<List<LivePlayLine>>(
      (_) => const <LivePlayLine>[],
      (value) => value.toList(growable: false),
    );
    if (lines.isEmpty) return _warn('0 lines');
    final issues = <String>{};
    for (final line in lines) {
      if (!_isHttp(line.url)) issues.add('bad url');
      if (line.format.name == 'other') issues.add('format other');
      if (issues.length >= 3) break;
    }
    final detail =
        '${lines.length} lines, first ${lines.first.format.name}'
        '${issues.isEmpty ? '' : '; ${issues.join(', ')}'}';
    if (issues.isNotEmpty) return _warn(detail);
    if (!options.deep) return _ok(detail);
    final headers = <String, String>{for (final entry in lines.first.headers.entries) entry.key: entry.value};
    final probe = await MediaProbe(
      http: transport,
      timeout: options.timeout,
    ).check(lines.first.url, headers: headers, site: id);
    if (probe.playable) {
      return _ok('$detail; stream ${probe.container.name}, ${probe.bytes} B, http ${probe.statusCode}');
    }
    if (probe.inconclusive) return _warn('$detail; stream ${probe.message}');
    return _fail('$detail; stream ${probe.message} (http ${probe.statusCode})');
  });

  await run('plan', () async {
    final provider = site.capability<LivePlaybackPlanResolver>();
    if (provider == null) return _skip;
    final room = await currentRoom();
    if (room == null) return _warn('no room to plan');
    final answer = await provider.resolvePlan(room: room);
    return _judge(answer, (error) => _fail(_errorText(error)), (plan) {
      if (plan.lines.isEmpty) return _warn('0 lines in the plan');
      return _ok(
        '${plan.lines.length} lines'
        '${plan.appliedQuality == null ? '' : ', quality ${plan.appliedQuality!.label}'}'
        '${plan.qualityUnconfirmed ? ', unconfirmed' : ''}',
      );
    });
  });

  await run('superChat', () async {
    final provider = site.capability<LiveSuperChatFeed>();
    if (provider == null) return _skip;
    final room = await currentRoom();
    if (room == null) return _warn('no room to ask about');
    final answer = await provider.getSuperChatMessages(room: room);
    return _judge(answer, (error) => _fail(_errorText(error)), (messages) => _ok('${messages.length} super chats'));
  });

  Future<List<LiveRoom>> danmakuRooms() async {
    final rooms = <LiveRoom>[];
    final room = await currentRoom();
    if (room != null) rooms.add(room);
    final listed = sampledRooms.values.toList()..sort((left, right) => _audienceOf(right).compareTo(_audienceOf(left)));
    for (final candidate in listed) {
      if (rooms.length >= _kDanmakuRooms) break;
      if (rooms.any((item) => item.ref.roomId == candidate.ref.roomId)) continue;
      rooms.add(candidate);
    }
    return rooms;
  }

  await run('danmaku', () async {
    final provider = site.capability<LiveDanmakuProvider>();
    if (provider == null) return _skip;
    final rooms = await danmakuRooms();
    if (rooms.isEmpty) return _warn('no room to open a chat for');
    final quiet = <String>[];
    for (final room in rooms) {
      LiveDanmakuSession? session;
      LiveSiteError? failure;
      final answer = await provider.createSession(room: room);
      answer.fold<void>((error) => failure = error, (value) => session = value);
      final opened = session;
      if (opened == null) {
        final reason = failure;
        return _fail(reason == null ? 'no session' : _errorText(reason));
      }
      try {
        final message = await opened.events
            .firstWhere((event) => event.text.trim().isNotEmpty)
            .timeout(options.danmakuWait);
        final name = message.sender?.userName.trim() ?? '';
        return _ok('first line ${name.isEmpty ? 'anonymous' : name}: ${_clip(message.text)}');
      } on TimeoutException {
        final state = opened is LiveDanmakuStatusEvents
            ? (opened as LiveDanmakuStatusEvents).connectionState.name
            : '?';
        final audience = room.audience.popularity ?? room.audience.onlineViewers;
        quiet.add('${room.ref.roomId} (${audience == null ? 'no figures' : 'audience $audience'}, state $state)');
      } on Object catch (error) {
        return _fail('the event stream ended without a message: $error');
      } finally {
        try {
          await opened.dispose().timeout(const Duration(seconds: 5));
        } on Object {
          // A probe is done with the session either way.
        }
      }
    }
    return _warn(
      quiet.length == 1
          ? 'no line in ${options.danmakuWait.inSeconds}s from ${quiet.single}'
          : 'no line in ${options.danmakuWait.inSeconds}s from ${quiet.join(', ')}',
    );
  });

  await run('links', () async {
    final resolver = site.capability<LiveLinkResolver>();
    if (resolver == null) return _skip;
    final room = await currentRoom();
    final url = room?.links.webUrl ?? room?.links.shareUrl;
    if (url == null || url.trim().isEmpty) return _warn('the room has no link to resolve');
    final answer = await resolver.resolve(Uri.parse(url));
    return _judge(answer, (error) => _fail(_errorText(error)), (resolved) {
      return _isHttp(resolved.toString()) ? _ok('$url -> $resolved') : _warn('$url -> $resolved (not http)');
    });
  });

  await run('anchor', () async {
    final provider = site.capability<LiveAnchorProvider>();
    if (provider == null) return _skip;
    final anchor = (await currentRoom())?.anchor;
    final anchorId = anchor?.anchorId.trim() ?? '';
    if (anchorId.isEmpty) return _warn('the room carries no anchor id');
    final answer = await provider.getAnchor(anchorId);
    return _judge(answer, (error) => _fail('$anchorId: ${_errorText(error)}'), (found) {
      final name = found.name.trim();
      return name.isEmpty ? _warn('$anchorId: no name') : _ok('$anchorId "${_clip(name)}"');
    });
  });

  return checks;
}

/// The room page judged: an empty page is a warning, and shape problems in
/// any sampled room are named instead of silently passing.
_Outcome _roomsOutcome(String siteId, String label, List<LiveRoom> rooms) {
  if (rooms.isEmpty) return _warn('$label: 0 rooms');
  final issues = <String>{};
  for (final room in rooms) {
    issues.addAll(_roomIssues(siteId, room));
    if (issues.length >= 4) break;
  }
  final detail = '$label: ${rooms.length} rooms${issues.isEmpty ? '' : '; ${issues.join(', ')}'}';
  return issues.isEmpty ? _ok(detail) : _warn(detail);
}

/// The busiest room of [rooms] by its own audience figures, so the checks
/// that need a live room land on one with a conversation; the first room
/// with an id when the source reports no figures.
LiveRoom? _firstRoom(Iterable<LiveRoom> rooms) {
  LiveRoom? best;
  var score = -1;
  for (final room in rooms) {
    if (room.ref.roomId.trim().isEmpty) continue;
    final value = _audienceOf(room);
    if (value > score) {
      score = value;
      best = room;
    }
  }
  return best;
}

/// The room's own audience figure, whichever the platform reports.
int _audienceOf(LiveRoom room) {
  final audience = room.audience;
  return audience.popularity ?? audience.onlineViewers ?? audience.totalViewers ?? 0;
}

/// What a sampled room gets wrong; an empty list is a well-formed room.
List<String> _roomIssues(String siteId, LiveRoom room) => <String>[
  if (room.ref.platform != siteId) 'platform "${room.ref.platform}"',
  if (room.content.title.trim().isEmpty) 'no title',
  if (room.content.coverUrl.trim().isNotEmpty && !_isHttp(room.content.coverUrl)) 'bad cover',
];

/// Whether [url] is an http(s) address with a host.
bool _isHttp(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}

String _errorText(LiveSiteError error) {
  final cause = error.cause;
  return '${error.runtimeType}: ${error.message}${cause == null ? '' : ' ($cause)'}';
}

String _clip(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= 60 ? flat : '${flat.substring(0, 57)}...';
}

Map<String, int> _countByStatus(Iterable<_Check> checks) {
  final counts = <String, int>{for (final status in _Status.values) status.name: 0};
  for (final check in checks) {
    counts.update(check.status.name, (value) => value + 1);
  }
  return counts;
}

void _printBlock(LiveSite site, List<_Check> checks, _Options options) {
  final name = site.manifest.name['zh-CN'] ?? site.manifest.id;
  stdout.writeln('\n-- ${site.manifest.id} ($name) --');
  for (final check in checks) {
    if (check.status == _Status.skip && !options.showSkips) continue;
    stdout.writeln(
      '  ${check.capability.padRight(13)} ${_tag(check.status)} '
      '${check.elapsed.inMilliseconds.toString().padLeft(5)}ms  ${check.detail}',
    );
  }
}

String _tag(_Status status) => switch (status) {
  _Status.ok => 'ok  ',
  _Status.warn => 'warn',
  _Status.fail => 'FAIL',
  _Status.skip => 'skip',
};

void _printSummary(List<_Check> checks) {
  final counts = _countByStatus(checks);
  stdout.writeln(
    '\n== ${checks.length} checks | ok ${counts['ok']} | warn ${counts['warn']} | '
    'fail ${counts['fail']} | skip ${counts['skip']} ==',
  );
  final failing = checks.where((check) => check.status == _Status.fail).toList(growable: false);
  if (failing.isEmpty) {
    stdout.writeln('No failures.');
    return;
  }
  stdout.writeln('\nFailures:');
  for (final check in failing) {
    stdout.writeln('  ${check.site} / ${check.capability}: ${check.detail}');
  }
}

void _printInventory(List<LiveSite> sites) {
  void section<T extends LiveSiteCapability>(String label) {
    final ids = <String>[
      for (final site in sites)
        if (site.capability<T>() != null) site.manifest.id,
    ];
    stdout.writeln('${label.padRight(24)} ${ids.length.toString().padLeft(2)}  ${ids.join(', ')}');
  }

  stdout.writeln('Sites: ${sites.length}\n');
  section<LiveHotProvider>('hot');
  section<LiveDiscoveryProvider>('discovery');
  section<LiveAreaProvider>('areas');
  section<LiveRoomProvider>('room');
  section<LiveRoomRefresh>('room refresh');
  section<LivePlaybackProvider>('playback');
  section<LivePlaybackPlanResolver>('playback plan');
  section<LiveStatusCheck>('status');
  section<LiveSuperChatFeed>('super chat');
  section<LiveDanmakuProvider>('danmaku');
  section<LiveSearchProvider>('search');
  section<LiveWebSearchProvider>('web search');
  section<LiveSuggestCapability>('suggest');
  section<LiveLinkResolver>('link resolve');
  section<LiveAnchorProvider>('anchor');
  section<LiveAuthCapability>('auth');
  section<LiveCookieRefusalFeed>('cookie refusal');
  section<LivePlayRecovery>('play recovery');
  section<LivePlayLeaseLookup>('play lease');
}

_Options _parseOptions(List<String> argv) {
  final options = _Options();
  for (final argument in argv) {
    if (argument == '--help' || argument == '-h') {
      options.help = true;
    } else if (argument == '--inventory') {
      options.inventory = true;
    } else if (argument == '--deep') {
      options.deep = true;
    } else if (argument == '--show-skips') {
      options.showSkips = true;
    } else if (_value(argument, '--site') case final value?) {
      options.sites.addAll(_list(value));
    } else if (_value(argument, '--only') case final value?) {
      options.checks.addAll(_list(value));
    } else if (_value(argument, '--skip') case final value?) {
      options.skips.addAll(_list(value));
    } else if (_value(argument, '--room') case final value?) {
      for (final entry in _list(value)) {
        final split = entry.indexOf(':');
        if (split <= 0 || split == entry.length - 1) continue;
        options.rooms[entry.substring(0, split)] = entry.substring(split + 1);
      }
    } else if (_value(argument, '--query') case final value?) {
      options.query = value;
    } else if (_value(argument, '--timeout') case final value?) {
      options.timeout = Duration(seconds: int.tryParse(value) ?? 20);
    } else if (_value(argument, '--danmaku-wait') case final value?) {
      options.danmakuWait = Duration(seconds: int.tryParse(value) ?? 10);
    } else if (_value(argument, '--workers') case final value?) {
      options.workers = int.tryParse(value) ?? 3;
    } else if (_value(argument, '--json') case final value?) {
      options.jsonPath = value;
    } else if (_value(argument, '--proxy') case final value?) {
      options.proxy = _proxyRoute(value);
    } else {
      stderr.writeln('Ignoring unrecognized argument: $argument');
    }
  }
  return options;
}

/// The routing a `--proxy` names: `system`, or `host[:port]` (an optional
/// `http://` prefix is accepted).
ProxyRoute? _proxyRoute(String value) {
  final text = value.trim();
  if (text == 'system') return const SystemProxyRoute();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'http://$text');
  if (uri == null || uri.host.isEmpty) {
    stderr.writeln('Ignoring the proxy "$value" (expected system or host[:port])');
    return null;
  }
  return HttpProxyRoute(host: uri.host, port: uri.hasPort ? uri.port : 7897);
}

String? _value(String argument, String name) {
  final prefix = '$name=';
  return argument.startsWith(prefix) ? argument.substring(prefix.length) : null;
}

List<String> _list(String value) => <String>[
  for (final part in value.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

void _printUsage() {
  stdout.writeln('''
A capability smoke probe over the built-in live sites.

Usage: dart run tool/capability_probe.dart [options]

Options:
  --site=<id,...>         Probe only these sites (default: every built-in site).
  --only=<check,...>      Run only these checks (default: all).
  --skip=<check,...>      Leave these checks out.
  --room=<site>:<id>      Pin the room a site is checked against (repeatable).
  --query=<text>          The search/suggest query (default: lol).
  --timeout=<seconds>     Budget for one check (default: 20).
  --danmaku-wait=<s>      How long to wait for a chat line (default: 10); a
                          quiet room is retried in up to $_kDanmakuRooms rooms.
  --workers=<n>           Sites probed at once (default: 3, max 8).
  --deep                  Read the first bytes of the first play line.
  --proxy=system|host:p   Route the probe through a proxy.
  --inventory             Print which site implements which capability.
  --show-skips            Print unsupported capabilities too.
  --json=<path>           Write the report as JSON.
  -h, --help              This text.

Checks:
  ${_kChecks.join(', ')}

Exit code is 0 when nothing failed, 1 when a check failed, 2 for bad usage.
''');
}
