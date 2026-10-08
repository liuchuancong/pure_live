import 'package:dio/dio.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_session.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';

/// Niconico seat and master-playlist contracts.
///
/// Both playback (the quality catalog) and recording (the HLS input) need these
/// aliases, so they live with the adapter. The recorder keeps the implementation
/// (`readNiconicoMaster`) because it is built on the record-side HLS relay.
typedef NiconicoSeatFactory = Future<NiconicoSession> Function(
  NiconicoWatch watch,
  CancelToken cancel,
  String Function(Uri) findProxy,
);
typedef NiconicoMasterReader = Future<String> Function(
  Uri source,
  String? Function(Uri) cookies,
  CancelToken cancel,
  String Function(Uri) findProxy,
);
