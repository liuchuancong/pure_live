// The station's link to the official service: the client the feeds ask, the
// decrypting proxy the player drinks from, and the rendition choice between
// them. Signing, the device identity and the CDN decryption all happen
// in-process — no companion service, no external signer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;

import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/modules/hongguo/official/hongguo_device.dart' show HongguoDeviceException;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoOfficialClient, HongguoOfficialFailure, HongguoRendition;
import 'package:pure_live/modules/hongguo/official/hongguo_proxy.dart' show HongguoProxyFailure, HongguoStreamProxy;

/// The official client the station's feeds ask.
final hongguoClientProvider = Provider<HongguoOfficialClient>((ref) {
  return HongguoOfficialClient(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
});

/// The local decrypting proxy the player's episodes stream through.
final hongguoStreamProxyProvider = Provider<HongguoStreamProxy>((ref) {
  final proxy = HongguoStreamProxy(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
  ref.onDispose(proxy.close);
  return proxy;
});

/// One of the station's failures, whatever layer raised it.
String hongguoFailureText(Object error) => switch (error) {
  HongguoOfficialFailure() => error.message,
  HongguoDeviceException() => error.message,
  HongguoProxyFailure() => error.message,
  _ => '$error',
};

/// The best rendition at or below [maxHeight] — h264 preferred, the
/// reference's TV-tested rule; the closest tier below when none fits, the
/// lowest tier otherwise.
HongguoRendition hongguoPickRendition(List<HongguoRendition> ladder, int maxHeight) {
  const avc = {'h264', 'avc', 'avc1', 'avc3'};
  int score(HongguoRendition rendition) => rendition.quality * 2 + (avc.contains(rendition.codec) ? 1 : 0);
  final fitting = [for (final r in ladder) if (r.quality >= 1 && r.quality <= maxHeight) r];
  if (fitting.isNotEmpty) {
    fitting.sort((a, b) => score(b).compareTo(score(a)));
    return fitting.first;
  }
  final unbounded = [for (final r in ladder) if (r.quality <= 0) r];
  if (unbounded.isNotEmpty) {
    unbounded.sort((a, b) => score(b).compareTo(score(a)));
    return unbounded.first;
  }
  return ladder.reduce((a, b) => score(a) <= score(b) ? a : b);
}
