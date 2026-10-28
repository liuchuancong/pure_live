import 'dart:async' show TimeoutException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';

/// The room a resolved link points at.
typedef ResolvedRoom = ({String platform, String roomId, Uri url});

/// What the link tool holds: the run in flight, the room the last resolve
/// found, and why the last resolve failed (null while none or while busy).
typedef LinkToolState = ({bool resolving, ResolvedRoom? resolved, LinkToolFailure? failure});

/// Why a resolve ended without a room.
enum LinkToolFailure {
  /// The field was empty when the action ran.
  empty,

  /// No registered platform owns the link.
  unsupported,

  /// The owning platform answered too slowly.
  timeout,

  /// The owning platform answered with a network or parse failure.
  failed,
}

/// The link tool's requests (the reference's `ToolboxController`, cut to
/// what this codebase can do): a resolve walks every registered site's
/// [LiveLinkResolver] in registration order — a link a site does not own is
/// refused without a request, so the walk costs one real request at most —
/// and the first room wins.
///
/// A newer resolve replaces an older one: answers from a superseded run are
/// dropped, not written over the newer one's state.
final class LinkToolController extends Notifier<LinkToolState> {
  /// How long one platform's resolve may take (the reference's 12 s).
  static const Duration _perSiteTimeout = Duration(seconds: 12);

  /// One more than the newest resolve this controller started; a run whose
  /// generation fell behind has been replaced and must not write state.
  int _generation = 0;

  @override
  LinkToolState build() => (resolving: false, resolved: null, failure: null);

  /// Resolves [text] into a room: the first platform whose resolver owns
  /// the link wins; when none does, the state names why.
  Future<void> resolve(String text) async {
    final generation = ++_generation;
    final link = text.trim();
    if (link.isEmpty) {
      state = (resolving: false, resolved: null, failure: LinkToolFailure.empty);
      return;
    }
    final uri = linkUriOf(link);
    if (uri == null) {
      state = (resolving: false, resolved: null, failure: LinkToolFailure.unsupported);
      return;
    }
    state = (resolving: true, resolved: null, failure: null);
    var sawTrouble = false;
    var sawTimeout = false;
    ResolvedRoom? found;
    for (final site in ref.read(sitesProvider).all) {
      if (generation != _generation) return;
      final resolver = site.capability<LiveLinkResolver>();
      if (resolver == null) continue;
      try {
        final canonical = await resolver.resolve(uri).timeout(_perSiteTimeout);
        canonical.match(
          (error) {
            // A site that does not own the link refuses it without a
            // request; any other left is real trouble worth reporting.
            if (error is! LiveSiteUnsupported) sawTrouble = true;
          },
          (url) {
            final room = _roomOf(site.manifest.id, url);
            if (room != null) found = room;
          },
        );
      } on TimeoutException {
        // Only a site that took the link can time out; the rest refuse at
        // once, so the timeout names the network, not the platform.
        sawTimeout = true;
      } on Object {
        // A resolver answers failures as lefts; anything thrown is the
        // same kind of trouble, and the run must not strand on it.
        sawTrouble = true;
      }
      if (found != null) break;
    }
    if (generation != _generation) return;
    if (found != null) {
      state = (resolving: false, resolved: found, failure: null);
      return;
    }
    state = (
      resolving: false,
      resolved: null,
      failure: sawTimeout
          ? LinkToolFailure.timeout
          : sawTrouble
          ? LinkToolFailure.failed
          : LinkToolFailure.unsupported,
    );
  }

  /// Forgets the last result, keeping the field's text the page owns.
  void reset() {
    _generation++;
    state = (resolving: false, resolved: null, failure: null);
  }

  /// The room of a canonical room URL (`https://<live host>/{roomId}`, the
  /// shape every resolver answers), or null when the path names none.
  static ResolvedRoom? _roomOf(String platform, Uri url) {
    final segments = url.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final roomId = segments.last;
    if (roomId.trim().isEmpty) return null;
    return (platform: platform, roomId: roomId, url: url);
  }

  /// The first http(s) address in [text] — share texts lead with words —
  /// or the text itself as a bare host when it names one. Public so the
  /// link pane can decide whether a clipboard's text is worth offering.
  static Uri? linkUriOf(String text) {
    final embedded = RegExp(r'https?://[^\s，。；“”‘’<>]+').firstMatch(text)?.group(0);
    for (final candidate in <String?>[embedded, text.trim()]) {
      if (candidate == null || candidate.isEmpty) continue;
      var uri = Uri.tryParse(candidate);
      if (uri == null || uri.host.isEmpty) uri = Uri.tryParse('https://$candidate');
      if (uri != null && uri.host.isNotEmpty) return uri;
    }
    return null;
  }
}

/// One network check's outcome: the endpoint answered, or how it failed.
sealed class ProbeOutcome {
  const ProbeOutcome();

  /// The endpoint answered: [rooms] came back in [elapsed].
  const factory ProbeOutcome.success({required int rooms, required Duration elapsed}) = ProbeSuccess;

  /// The endpoint failed: the site's own [error], or a synthesized network
  /// error when the answer never arrived.
  const factory ProbeOutcome.failure({required LiveSiteError error}) = ProbeFailure;
}

/// The endpoint answered.
final class ProbeSuccess extends ProbeOutcome {
  const ProbeSuccess({required this.rooms, required this.elapsed});

  /// How many rooms the probed page carried.
  final int rooms;

  /// From the request's start to the parsed page.
  final Duration elapsed;
}

/// The endpoint failed.
final class ProbeFailure extends ProbeOutcome {
  const ProbeFailure({required this.error});

  /// The site's own error, or the synthesized timeout one.
  final LiveSiteError error;
}

/// One platform's node test: whether its check is running and the last
/// answer, or null before the first run.
typedef PlatformProbeNode = ({bool probing, ProbeOutcome? outcome});

/// The node test's state: one entry per platform it has seen, and whether
/// a sweep is running.
typedef PlatformProbeState = ({bool running, Map<String, PlatformProbeNode> nodes});

/// Tests the platforms' endpoints the way the network tool does — the
/// discovery feed, else the hot list — for one platform on demand or for
/// every probe-able platform in a bounded sweep.
final class PlatformProbeController extends Notifier<PlatformProbeState> {
  /// How long one probe may take before it counts as unreachable.
  static const Duration _timeout = Duration(seconds: 15);

  /// How many platforms a sweep probes at once: enough to make a wall
  /// useful, few enough that it does not look like an attack.
  static const int _sweepConcurrency = 4;

  /// One more than the newest sweep this controller started.
  int _generation = 0;

  @override
  PlatformProbeState build() => (running: false, nodes: const {});

  /// Tests [siteId] alone; a check already running for it is left alone.
  Future<void> probe(String siteId) async {
    if (state.nodes[siteId]?.probing ?? false) return;
    _set(siteId, (probing: true, outcome: null));
    final outcome = await _measure(siteId);
    if (!ref.mounted) return;
    _set(siteId, (probing: false, outcome: outcome));
  }

  /// Tests every probe-able platform, at most [_sweepConcurrency] at a
  /// time; results land on the wall as each one answers.
  Future<void> probeAll() async {
    if (state.running) return;
    final sites = probeSites(ref.read(sitesProvider).all);
    if (sites.isEmpty) return;
    final generation = ++_generation;
    state = (running: true, nodes: {for (final site in sites) site.manifest.id: (probing: false, outcome: null)});
    var next = 0;
    Future<void> worker() async {
      while (next < sites.length) {
        final site = sites[next++];
        if (generation != _generation) return;
        _set(site.manifest.id, (probing: true, outcome: null));
        final outcome = await _measure(site.manifest.id);
        if (!ref.mounted || generation != _generation) return;
        _set(site.manifest.id, (probing: false, outcome: outcome));
      }
    }

    await Future.wait([for (var index = 0; index < _sweepConcurrency && index < sites.length; index++) worker()]);
    if (!ref.mounted || generation != _generation) return;
    state = (running: false, nodes: state.nodes);
  }

  /// Forgets every result (a new wall starts from nothing).
  void clear() {
    _generation++;
    state = (running: false, nodes: const {});
  }

  /// Times one platform's cheap call; failures carry the site's own words.
  Future<ProbeOutcome> _measure(String siteId) async {
    final site = ref.read(sitesProvider).getById(siteId);
    final discovery = site?.capability<LiveDiscoveryProvider>();
    final hot = site?.capability<LiveHotProvider>();
    if (site == null || (discovery == null && hot == null)) {
      return ProbeOutcome.failure(
        error: LiveSiteError.unsupported(siteId: siteId, message: 'no probe target'),
      );
    }
    final watch = Stopwatch()..start();
    try {
      final answer = discovery != null
          ? await discovery.getRecommendedRooms().timeout(_timeout)
          : await hot!.getHotRooms().timeout(_timeout);
      watch.stop();
      final outcome = answer.match(
        (error) => ProbeOutcome.failure(error: error),
        (page) => ProbeOutcome.success(rooms: page.items.length, elapsed: watch.elapsed),
      );
      return outcome;
    } on TimeoutException {
      watch.stop();
      return ProbeOutcome.failure(
        error: LiveSiteError.network(siteId: siteId, message: 'probe timed out'),
      );
    } on Object catch (error) {
      watch.stop();
      return ProbeOutcome.failure(
        error: LiveSiteError.network(siteId: siteId, message: '$error', cause: error),
      );
    }
  }

  void _set(String siteId, PlatformProbeNode node) {
    state = (running: state.running, nodes: {...state.nodes, siteId: node});
  }
}

/// The platforms a node test can probe: every site that answers one of the
/// two cheap page calls, in registration order.
List<LiveSite> probeSites(Iterable<LiveSite> sites) => [
  for (final site in sites)
    if (site.capability<LiveDiscoveryProvider>() != null || site.capability<LiveHotProvider>() != null) site,
];

/// The link tool's state.
final linkToolProvider = NotifierProvider<LinkToolController, LinkToolState>(LinkToolController.new);

/// The node test's state.
final platformProbeProvider = NotifierProvider<PlatformProbeController, PlatformProbeState>(
  PlatformProbeController.new,
);
