import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
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
  return LiveSiteRegistry(
    createBuiltInLiveSites(
      http: http,
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
