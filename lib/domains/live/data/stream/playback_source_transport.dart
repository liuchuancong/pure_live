import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:media_core_ingest/media_core_ingest.dart';
import 'package:pure_live/core/player/core/ingest_ffmpeg_registry.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/player/core/playback_proxy_policy.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

import 'flv_legacy_hevc_relay.dart';
import 'live_stream_ingest.dart';
import 'playback_ingest_needs.dart';
import 'playback_manifest_probe.dart';

class _PlaybackInputCreation {
  _PlaybackInputCreation(this.joinOnCancel) {
    // open always observes the factory; teardown may also join it. Installing
    // an observer now avoids unhandled errors when no cancellation is pending.
    unawaited(settled.future.catchError((Object _) {}));
  }
  final bool joinOnCancel;
  final cancel = CancelToken();
  final settled = Completer<void>();
}

/// Owned by one UnifiedPlayer, not by the route or by a quality label.
/// Native completion can arrive after a manager deadline; its input must not
/// become active again after cancellation, replacement or disposal.
class PlaybackSourceTransport {
  PlaybackSourceTransport({this._createInput});
  final PlaybackInputFactory? _createInput;
  final Set<_PlaybackInputCreation> _creating = {};
  final Set<PlaybackInputLease> _pending = {};
  final Set<PlaybackInputLease> _retiring = {};

  /// Inputs already superseded but kept open one round: the engine may still be
  /// reading the loopback URI while the caller assembles its replacement source
  /// list, so they are retired by the *next* transaction instead of immediately.
  final Set<PlaybackInputLease> _stale = {};
  PlaybackInputLease? _active;

  /// Remote session closure can invalidate a committed input before a user
  /// resumes. Consumers reacquire their recipe instead of replaying its URI.
  bool get activeInputIsUsable => !_closed && (_active?.isUsable ?? false);
  int _generation = 0;
  bool _closed = false;
  Future<void>? _closing;

  static String _perHostProxy(Uri uri) =>
      playsDirectBehindProxy(uri) ? 'DIRECT' : PlaybackProxyPolicy.currentDirective();

  static Future<PlaybackInputLease> _createRelay(
    String url,
    Map<String, String> headers,
    HlsSourceQueryPolicy policy,
  ) async {
    // This string is an argument value, never a shell command. Validate before
    // encoding it as CRLF-delimited HTTP fields to preserve the header boundary.
    final name = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
    for (final entry in headers.entries) {
      if (!name.hasMatch(entry.key) || RegExp(r'[\r\n\x00]').hasMatch(entry.value)) {
        throw const FormatException('Invalid playback input header');
      }
    }
    final relay = await FFmpegHlsInputRelay.startForArguments(
      [
        if (headers.isNotEmpty) ...['-headers', headers.entries.map((e) => '${e.key}: ${e.value}\r\n').join()],
        '-i',
        url,
      ],
      sourceQueryPolicy: policy,
      findProxy: _perHostProxy,
    );
    if (relay == null) throw const FormatException('Expected a policy-bound HLS input');
    return PlaybackInputLease(relay.inputUri, relay.close);
  }

  static Future<PlaybackInputLease> _createLegacyHevcRelay(String url, Map<String, String> headers) async {
    final relay = await FlvLegacyHevcRelay.start(url, headers, findProxy: _perHostProxy);
    return PlaybackInputLease(relay.inputUri, relay.close, isUsable: () => !relay.isClosed);
  }

  /// Serves a rewritten manifest tree from loopback: every child the player sees
  /// is already an absolute loopback URL, so neither a bare `media.95.mp4` nor an
  /// absolute path `/tc.livehls/...` can become a Windows path on the way to the
  /// demuxer.
  ///
  /// The provider's session cookie travels with the tree. TwitCasting hands one
  /// out *with the manifest* (`lvhls_ssid_<movie>`, scoped to the stream path,
  /// ten minutes) and answers a segment request that lacks it with 401 — so a
  /// relay that drops it reads the playlist fine and then starves on the first
  /// segment. Every other relay here already fetched upstream through the
  /// player's proxy; this one is the last that did not.
  static Future<PlaybackInputLease> _createIngestRelay(
    String url,
    Map<String, String> headers, {
    String? rootManifest,
    Uri Function(Uri)? childUriPolicy,
    HlsSourceQueryPolicy? matchesPolicy,
  }) async {
    final Uri source = Uri.parse(url);
    if (matchesPolicy != null && !matchesPolicy.matchesSource(source)) {
      throw const FormatException('Playback query policy does not match selected input');
    }
    final relay = await LoopbackIngestRelay.start(
      source: source,
      headers: headers,
      rootManifest: rootManifest,
      childUriPolicy: childUriPolicy,
      sessionCookies: true,
      findProxy: _perHostProxy,
    );
    return PlaybackInputLease(relay.inputUri, relay.close, isUsable: () => !relay.isClosed);
  }

  /// Remuxes an upstream the player cannot parse: FFmpeg reads it once and the
  /// player reads a plain local playlist instead.
  static Future<PlaybackInputLease> _createFfmpegRelay(String url, Map<String, String> headers) async {
    final relay = await FfmpegIngestRelay.start(
      source: Uri.parse(url),
      startFfmpeg: startIngestFfmpeg,
      headers: headers,
    );
    return PlaybackInputLease(relay.inputUri, relay.close);
  }

  /// Prepares one remote line as a local input the player can read, or returns
  /// null when the line is best handed over untouched.
  ///
  /// The caller swaps the returned loopback URI into its own source list; the
  /// lease stays owned here and is released by the next transaction, by
  /// [release] or by [close]. Relaying costs a process, a port and one to three
  /// seconds of start-up, so only a declared need - or, on an undeclared line, a
  /// manifest whose children really cannot be resolved natively - moves it off
  /// the direct path.
  ///
  /// A relay that cannot start returns null instead of throwing: the caller then
  /// plays the upstream URL directly, which is what happens with no transport.
  Future<PlaybackInputLease?> prepare({
    required String url,
    required Map<String, String> headers,
    LiveStreamFacts? facts,
    HlsSourceQueryPolicy? policy,
  }) async {
    if (_closed) return null;
    final int generation = ++_generation;
    bool current() => !_closed && generation == _generation;
    PlaybackInputLease? input;
    try {
      if (_creating.isNotEmpty || _pending.isNotEmpty || _stale.isNotEmpty) await _cancelPendingResources();
      if (!current()) return null;
      final PlaybackOwnedInputFactory? createInput = await _chooseInput(
        url: url,
        headers: headers,
        facts: facts,
        policy: policy,
      );
      // The superseded input stays open one more round: the engine may still be
      // reading it while the caller assembles the replacement source list.
      final PlaybackInputLease? previous = _active;
      _active = null;
      if (previous != null) _stale.add(previous);
      if (createInput == null || !current()) return null;
      input = await _acquire(createInput, current, joinOnCancel: true);
      if (!current() || !input.isUsable) throw StateError('Playback input transaction was retired');
      _active = input;
      _pending.remove(input);
      return _active;
    } catch (error) {
      if (input != null) {
        _pending.remove(input);
        await _retire(input);
      }
      developer.log('playback input relay unavailable: $error', name: 'PlaybackIngest');
      return null;
    }
  }

  /// Releases the input handed to the player without closing the owner: playback
  /// stopped (room left, floating window closed) but a later line still gets one.
  Future<void> release() async {
    if (_closed) return;
    _generation++;
    final PlaybackInputLease? active = _active;
    _active = null;
    if (active != null) _stale.add(active);
    await _cancelPendingResources();
  }

  /// The delivery decision for one line, as a factory [prepare] can acquire - or
  /// null when the line goes to the player untouched.
  Future<PlaybackOwnedInputFactory?> _chooseInput({
    required String url,
    required Map<String, String> headers,
    required LiveStreamFacts? facts,
    required HlsSourceQueryPolicy? policy,
  }) async {
    final Uri? source = Uri.tryParse(url);
    if (source == null) return null;
    final Map<String, String> frozen = Map<String, String>.unmodifiable(headers);
    final bool manifest = isDeclaredManifest(facts, source);

    if (policy != null) {
      // An HLS source with a query-token policy goes through the same ingest
      // relay as a rewritten manifest: the policy is applied to the *upstream*
      // child requests, so the player only ever sees absolute loopback URLs.
      final PlaybackInputFactory? legacyFactory = _createInput;
      if (legacyFactory == null && manifest) {
        return (_) => _createIngestRelay(url, frozen, childUriPolicy: policy.apply, matchesPolicy: policy);
      }
      return (_) {
        if (!policy.matchesSource(source)) {
          throw const FormatException('Playback query policy does not match selected input');
        }
        return (legacyFactory ?? _createRelay)(url, frozen, policy);
      };
    }

    final ({Set<IngestNeed> needs, String? rootManifest}) decision = await _ingestNeeds(
      url: url,
      source: source,
      headers: frozen,
      facts: facts,
      manifest: manifest,
    );
    final IngestPlan plan = resolveIngestPlan(needs: decision.needs, sourceIsManifest: manifest);
    if (plan.isDirect) return null;
    // Host only: a signed live URL carries its token in the query.
    developer.log('${source.host} -> $plan', name: 'PlaybackIngest');
    if (plan.strategy == IngestStrategy.manifestRelay) {
      final String? rootManifest = decision.rootManifest;
      return (_) => _createIngestRelay(url, frozen, rootManifest: rootManifest);
    }
    if (ingestFfmpegAvailable) {
      // The player's own FFmpeg cannot parse this container (codec-id-12 HEVC
      // inside FLV), so a local FFmpeg remuxes it into a loopback HLS tree.
      return (_) => _createFfmpegRelay(url, frozen);
    }
    // Without an FFmpeg runtime the Dart tag rewriter still covers known CDNs.
    if (FlvLegacyHevcRelay.appliesTo(url)) return (_) => _createLegacyHevcRelay(url, frozen);
    return null;
  }

  /// Why this line cannot be handed to the player as it is, plus the manifest
  /// body already read for that answer so the relay does not read it twice.
  Future<({Set<IngestNeed> needs, String? rootManifest})> _ingestNeeds({
    required String url,
    required Uri source,
    required Map<String, String> headers,
    required LiveStreamFacts? facts,
    required bool manifest,
  }) async {
    // A platform that declares its line is believed: that is the point of the
    // declaration, and it saves a probe read on every HLS start.
    if (facts != null) return (needs: ingestNeedsFor(facts), rootManifest: null);
    if (manifest) {
      // Decide from the manifest itself rather than from a per-platform list: a
      // manifest whose children are bare names (`media.95.mp4`) or absolute paths
      // cannot be handed to the native resolver, because a reader that loses the
      // manifest URL looks for them next to itself and turns them into local
      // paths (`No protocol handler found ... \tc.livehls\...\media.95.mp4`).
      final PlaybackManifestProbe? probe = await probePlaybackManifest(url, headers: headers);
      if (probe != null) {
        final Set<IngestNeed> needs = probe.kind.requiresRewrite
            ? const <IngestNeed>{IngestNeed.relativeChildren}
            : const <IngestNeed>{};
        developer.log(
          'manifest ${source.host}: ${probe.kind.describe()} -> '
          '${needs.isEmpty ? 'direct' : 'loopback rewrite'}',
          name: 'PlaybackIngest',
        );
        return (needs: needs, rootManifest: probe.body);
      }
    }
    // Nothing declared and nothing readable: fall back to the host table and to
    // the CDNs known to serve HEVC inside FLV.
    final Set<IngestNeed> needs = <IngestNeed>{...playbackIngestNeeds(source)};
    if (FlvLegacyHevcRelay.appliesTo(url)) needs.add(IngestNeed.legacyContainer);
    return (needs: Set<IngestNeed>.unmodifiable(needs), rootManifest: null);
  }

  /// No placeholder URL, raw cookies or signed websocket are sent to native.
  /// Metadata/seat acquisition happens inside this same source transaction.
  Future<void> openOwned({required PlaybackOwnedInputFactory createInput, required PlaybackNativeOpen nativeOpen}) =>
      _open(createInput: createInput, joinCreationOnCancel: true, nativeOpen: nativeOpen);

  Future<void> _open({
    String? url,
    List<String> urls = const [],
    Map<String, String> headers = const {},
    required PlaybackOwnedInputFactory? createInput,
    required bool joinCreationOnCancel,
    required PlaybackNativeOpen nativeOpen,
  }) async {
    if (_closed) throw StateError('Playback input owner is closed');
    final generation = ++_generation;
    PlaybackInputLease? input;
    bool current() => !_closed && generation == _generation;
    try {
      if (_creating.isNotEmpty || _pending.isNotEmpty || _stale.isNotEmpty || _retiring.isNotEmpty) {
        await _cancelPendingResources();
      }
      if (!current()) throw StateError('Playback input transaction was retired');
      if (createInput != null) {
        input = await _acquire(createInput, current, joinOnCancel: joinCreationOnCancel);
      }
      if (!current() || input?.isUsable == false) throw StateError('Playback input transaction was retired');
      final local = input?.uri.toString();
      await nativeOpen(
        local ?? url!,
        local == null ? urls : [local],
        local == null ? headers : const {},
        input != null,
      );
      if (!current() || input?.isUsable == false) throw StateError('Playback input transaction was retired');
      final previous = _active;
      _active = input;
      _pending.remove(input);
      input = null;
      if (previous != null) await _retire(previous);
    } catch (_) {
      _pending.remove(input);
      if (input != null) await _retire(input);
      rethrow;
    }
  }

  Future<PlaybackInputLease> _acquire(
    PlaybackOwnedInputFactory factory,
    bool Function() current, {
    required bool joinOnCancel,
  }) async {
    final creation = _PlaybackInputCreation(joinOnCancel);
    _creating.add(creation);
    try {
      final input = await factory(creation.cancel);
      _pending.add(input);
      if (!current() || creation.cancel.isCancelled) {
        _pending.remove(input);
        await _retire(input);
        creation.settled.complete();
        throw StateError('Playback input transaction was retired');
      }
      creation.settled.complete();
      return input;
    } catch (error, stack) {
      if (!creation.settled.isCompleted) {
        if (creation.cancel.isCancelled && identical(error, creation.cancel.cancelError)) {
          creation.settled.complete();
        } else {
          creation.settled.completeError(error, stack);
        }
      }
      rethrow;
    } finally {
      _creating.remove(creation);
    }
  }

  /// Cancel only the pending replacement, retaining the previous input until
  /// its native owner is replaced or disposed. A late factory result is closed
  /// by open() without invoking nativeOpen; never await an unbounded native open.
  Future<void> cancelPending() async {
    _generation++;
    await _cancelPendingResources();
  }

  Future<void> _cancelPendingResources() async {
    final creating = _creating.toList();
    for (final creation in creating) {
      creation.cancel.cancel();
    }
    final pending = _pending.toList();
    _pending.clear();
    final stale = _stale.toList();
    _stale.clear();
    await Future.wait([
      ...pending.map(_retire),
      ...stale.map(_retire),
      ..._retiring.map((input) => input.close()),
      for (final creation in creating)
        if (creation.joinOnCancel) creation.settled.future,
    ]);
  }

  Future<void> _retire(PlaybackInputLease input) async {
    _retiring.add(input);
    try {
      await input.close();
    } finally {
      _retiring.remove(input);
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    final active = _active;
    _active = null;
    final pending = cancelPending();
    final activeClose = active == null ? Future<void>.value() : _retire(active);
    // A dispatch-time cancellation may already be retiring a native input.
    // Teardown still joins that cleanup instead of merely observing an empty
    // pending set and declaring the owner closed early.
    await Future.wait([pending, activeClose, ..._retiring.map((input) => input.close())]);
  }
}
