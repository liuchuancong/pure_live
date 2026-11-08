import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/webview_guest.dart' show WebViewXiaohongshuGuest;

import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/network/network_providers.dart'
    show networkFactoryProvider, proxySettingsProvider;
import 'package:pure_live/app/providers/network/winhttp_live_http.dart' show WinHttpLiveHttp;
import 'package:pure_live/features/account/account.dart' show douyuLoginStoreProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/live/shield/shield.dart';

/// The registry of every built-in site, built once per process.
///
/// The sites own no credentials or settings yet; the composition root of
/// `live_sites` (its `createBuiltInLiveSites`) wires what it can by itself
/// and its seams (douyu login renewal, the twitch language filter, huya's
/// H.264 preference) are handed in when the settings store learns to keep
/// them.
final sitesProvider = Provider<LiveSiteRegistry>((ref) {
  // One transport for every site: the proxy and the network log configured
  // once, rather than each adapter opening its own silent client.
  final http = ref.watch(networkFactoryProvider).create();
  // Kick's host refuses Flutter's TLS handshake; Windows' WinHTTP answers.
  // The transport is only handed to Kick, and only where it exists.
  final kickHttp = Platform.isWindows
      ? WinHttpLiveHttp(route: () => ref.read(proxySettingsProvider.notifier).route)
      : null;
  ref.onDispose(() => kickHttp?.close());
  // The xiaohongshu visitor bootstrap: where an offscreen browser can run,
  // short-lived pages read the site's public directory anonymously; without
  // one the site keeps its sign-in-only scope.
  final xiaohongshuGuest = WebViewXiaohongshuGuest.isAvailable
      ? WebViewXiaohongshuGuest(route: () => ref.read(proxySettingsProvider.notifier).route)
      : null;
  return LiveSiteRegistry(
    createBuiltInLiveSites(
      log: appLog.forCategory('sites'),
      http: http,
      kickHttp: kickHttp,
      xiaohongshuGuest: xiaohongshuGuest,
      // The douyu protocol reads this for every suspected chat, so the
      // shield page's switch bites the next line without a re-open.
      douyuFilterSuspectedAutomated: () => ref.read(danmakuFilterProvider).douyuSuspectedAutomated,
      douyuLogin: ref.read(douyuLoginStoreProvider),
      douyuForceRenew: () => ref.read(douyuForceRenewProvider),
      twitchLanguages: () => ref.read(twitchLanguagesProvider),
      youtubeAllChat: () => ref.read(youtubeAllChatProvider),
      huyaPreferH264: () => ref.read(preferH264Provider),
    ),
  );
});
