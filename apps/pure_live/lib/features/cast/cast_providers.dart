import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/cast/cast_service.dart';

/// The app-wide casting service; one DLNA discovery for the whole run, so
/// opening the picker twice does not start two SSDP sockets.
final castServiceProvider = Provider<CastService>((ref) {
  final service = CastService();
  ref.onDispose(service.dispose);
  return service;
});
