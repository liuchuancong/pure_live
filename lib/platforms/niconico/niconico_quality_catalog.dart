import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/hls_master_selection.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/recorder/services/niconico_hls_input.dart'
    show NiconicoSeatFactory, NiconicoMasterReader, readNiconicoMaster;

import 'niconico_api.dart';
import 'niconico_session.dart';
import 'niconico_stream.dart';
import 'niconico_watch.dart';

/// Public, repeatable selection identity. Never retains a media URI or cookie.
class NiconicoQuality {
  const NiconicoQuality._(this.width, this.height, this.bandwidth);
  final int width;
  final int height;
  final int bandwidth;
  String get resolution => '${width}x$height';
  String get id => '$resolution@$bandwidth';
  String get label => '$width×$height · $bandwidth bps';
  Map<String, Object> toJson() => {'resolution': resolution, 'bandwidth': bandwidth};

  static List<NiconicoQuality> parse(Uri source, String text) {
    try {
      final master = HlsMasterPlaylist.parse(source, text);
      final result = <NiconicoQuality>[];
      final identities = <String>{};
      for (final variant in master.variants) {
        final resolution = variant.attributes['RESOLUTION'];
        if (resolution == null) throw const FormatException('Missing video resolution');
        final dimensions = resolution.split('x').map(int.parse).toList();
        final quality = NiconicoQuality._(dimensions[0], dimensions[1], int.parse(variant.attributes['BANDWIDTH']!));
        // The native owner selects by exact resolution AND bitrate. Duplicate
        // pairs and ambiguous external audio must not become unusable menu rows.
        if (!identities.add(quality.id)) throw const FormatException('Ambiguous quality selector');
        master.select(video: variant.uri);
        result.add(quality);
      }
      result.sort((a, b) {
        final height = b.height.compareTo(a.height);
        if (height != 0) return height;
        final width = b.width.compareTo(a.width);
        return width != 0 ? width : b.bandwidth.compareTo(a.bandwidth);
      });
      return List.unmodifiable(result);
    } on FormatException {
      throw const NiconicoException(NiconicoFailure.schema);
    }
  }
}

/// A short-lived metadata/seat/master inspection. Each call owns and closes
/// its session before returning public choices; playback acquires a fresh seat.
class NiconicoQualityCatalog {
  NiconicoQualityCatalog({
    NiconicoApi? api,
    NiconicoSeatFactory? openSeat,
    this._readMaster = readNiconicoMaster,
    String Function(Uri)? findProxy,
    this.deadline = const Duration(seconds: 30),
  }) : _api = api ?? NiconicoApi(),
       _openSeat =
           openSeat ?? ((watch, cancel, proxy) => NiconicoSession.open(watch, cancel: cancel, findProxy: proxy)),
       _findProxy = findProxy ?? resolveWebSocketProxyDirective {
    if (deadline <= Duration.zero) throw ArgumentError('Discovery deadline must be positive');
  }
  final NiconicoApi _api;
  final NiconicoSeatFactory _openSeat;
  final NiconicoMasterReader _readMaster;
  final String Function(Uri) _findProxy;
  final Duration deadline;

  Future<List<NiconicoQuality>> load(String programId, {CancelToken? cancel}) =>
      withRequestCancellation(cancel, (token) async {
        NiconicoWatch.validateProgramId(programId);
        NiconicoSession? seat;
        StreamSubscription<NiconicoStream>? changes;
        StreamSubscription<NiconicoFailure?>? ended;
        NiconicoFailure? reason;
        void cancelFor(NiconicoFailure failure) {
          reason ??= failure;
          if (!token.isCancelled) token.cancel();
        }

        void checkCancellation() {
          if (token.isCancelled) throw NiconicoException(reason ?? NiconicoFailure.cancelled);
        }

        final timer = Timer(deadline, () => cancelFor(NiconicoFailure.transport));
        late List<NiconicoQuality> qualities;
        try {
          checkCancellation();
          final watch = await _api.room(programId, cancel: token);
          checkCancellation();
          if (watch.status != NiconicoStatus.onAir) throw const NiconicoException(NiconicoFailure.notLive);
          if (watch.access != NiconicoAccess.allowed) throw const NiconicoException(NiconicoFailure.access);
          // Own a late factory result before observing cancellation.
          seat = await _openSeat(watch, token, _findProxy);
          checkCancellation();
          final owner = seat;
          final source = owner.current.uri;
          changes = owner.changes.listen((grant) {
            if (grant.uri != source) cancelFor(NiconicoFailure.sessionClosed);
          }, onError: (Object _) => cancelFor(NiconicoFailure.transport));
          ended = owner.done.asStream().listen(
            (failure) => cancelFor(failure ?? NiconicoFailure.sessionClosed),
            onError: (Object _) => cancelFor(NiconicoFailure.transport),
          );
          String? cookies(Uri target) {
            checkCancellation();
            final grant = owner.current;
            if (grant.uri != source) throw const NiconicoException(NiconicoFailure.sessionClosed);
            return grant.cookieHeaderFor(target);
          }

          final master = await _readMaster(source, cookies, token, _findProxy);
          checkCancellation();
          if (owner.current.uri != source) throw const NiconicoException(NiconicoFailure.sessionClosed);
          qualities = NiconicoQuality.parse(source, master);
        } catch (error) {
          checkCancellation();
          if (error is NiconicoException) rethrow;
          throw const NiconicoException(NiconicoFailure.transport);
        } finally {
          timer.cancel();
          await changes?.cancel();
          await ended?.cancel();
          if (seat != null) {
            try {
              await seat.close();
              if (!seat.cleanupSucceeded) throw const NiconicoException(NiconicoFailure.cleanup);
            } catch (_) {
              throw const NiconicoException(NiconicoFailure.cleanup);
            }
          }
        }
        checkCancellation();
        return qualities;
      });
}
