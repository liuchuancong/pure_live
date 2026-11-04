import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_vod/live_vod.dart' show BilibiliAppClient, TvLoginResult;

/// The app interface's sign-in: the access token the gRPC channel speaks and
/// the device id it was issued to. Null until the viewer scans the TV QR.
typedef VodAppSession = ({String accessKey, String deviceId, int mid});

const String _accessKeyPref = 'vod.app.accessKey';
const String _deviceIdPref = 'vod.app.deviceId';
const String _midPref = 'vod.app.mid';

/// Owns the app sign-in.
final class VodAppLoginController extends Notifier<VodAppSession?> {
  @override
  VodAppSession? build() {
    try {
      final accessKey = (StoragePrefs.getString(_accessKeyPref) ?? '').trim();
      final deviceId = (StoragePrefs.getString(_deviceIdPref) ?? '').trim();
      final mid = StoragePrefs.getInt(_midPref) ?? 0;
      if (accessKey.isEmpty || deviceId.isEmpty) return null;
      return (accessKey: accessKey, deviceId: deviceId, mid: mid);
    } on Object {
      return null;
    }
  }

  /// Keeps a confirmed sign-in.
  Future<void> save(TvLoginResult result, {required String deviceId}) async {
    state = (accessKey: result.accessToken, deviceId: deviceId, mid: result.mid);
    try {
      await StoragePrefs.setString(_accessKeyPref, result.accessToken);
      await StoragePrefs.setString(_deviceIdPref, deviceId);
      await StoragePrefs.setInt(_midPref, result.mid);
    } on Object {
      // A closed store loses the sign-in; the session still works.
    }
  }

  /// Forgets the sign-in.
  Future<void> clear() async {
    state = null;
    try {
      await StoragePrefs.remove(_accessKeyPref);
      await StoragePrefs.remove(_deviceIdPref);
      await StoragePrefs.remove(_midPref);
    } on Object {
      // A closed store keeps the rows; the session is gone anyway.
    }
  }
}

/// The app sign-in, when one exists.
final vodAppSessionProvider = NotifierProvider<VodAppLoginController, VodAppSession?>(VodAppLoginController.new);

/// The app playback client, alive while a sign-in exists.
final vodAppClientProvider = Provider<BilibiliAppClient?>((ref) {
  final session = ref.watch(vodAppSessionProvider);
  if (session == null) return null;
  final client = BilibiliAppClient(accessKey: session.accessKey, buvid: session.deviceId);
  ref.onDispose(() => unawaited(client.close()));
  return client;
});
