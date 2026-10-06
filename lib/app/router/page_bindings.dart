library;

import 'package:pure_live/core/index.dart' hide SearchController;

import 'package:pure_live/domains/live/presentation/pagination/live_directory_controller.dart';
import 'package:pure_live/shared/platforms/live_directory.dart';
import 'package:pure_live/domains/account/presentation/account/account_controller.dart';
import 'package:pure_live/domains/account/presentation/account/douyin/douyin_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/douyu/douyu_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/huya/huya_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/kuaishou/kuaishou_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/soop/soop_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/twitch/twitch_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/yy/yy_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/bigo/bigo_cookie_controller.dart';
import 'package:pure_live/domains/live/presentation/area_rooms/area_rooms_controller.dart';
import 'package:pure_live/domains/live/presentation/areas/favorite_areas_controller.dart';
import 'package:pure_live/domains/live/presentation/hot_areas/hot_areas_controller.dart';
import 'package:pure_live/domains/live/presentation/multiview/multiview_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';
import 'package:pure_live/domains/live/presentation/search/search_controller.dart';
import 'package:pure_live/domains/live/presentation/search/web_search_controller.dart';
import 'package:pure_live/domains/live/presentation/shield/danmu_shield_controller.dart';
import 'package:pure_live/domains/live/presentation/tags/tag_management_controller.dart';
import 'package:pure_live/domains/recorder/data/record_settings_controller.dart';
import 'package:pure_live/domains/recorder/presentation/pages/recorder/recorder_controller.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/features/toolbox/toolbox_controller.dart';
import 'package:pure_live/features/version/version_controller.dart';
import 'package:pure_live/features/web_dav/web_dav_controller.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

class AccountBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => AccountController())];
  }
}

class DouyinCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => DouyinCookieController())];
  }
}

class DouyuCookieBinding extends Binding {
  @override
  List<Bind> dependencies() => [Bind.lazyPut(() => DouyuCookieController())];
}

class HuyaCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => HuyaCookieController())];
  }
}

class KuaishouCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => KuaishouCookieController())];
  }
}

class SoopCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => SoopCookieBindingCookieController())];
  }
}

class TwitchCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => TwitchCookieBindingCookieController())];
  }
}

class YyCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => YyCookieBindingCookieController())];
  }
}

class BigoCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => BigoCookieBindingCookieController())];
  }
}

class AreaRoomsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    final Site site = Get.arguments[0];
    final LiveArea subCategory = Get.arguments[1];
    final String tag = areaRoomsControllerTag(site, subCategory);

    return [Bind.lazyPut<BasePageScrollAndStateBone<LiveRoom>>(() => createController(site, subCategory), tag: tag)];
  }

  static BasePageScrollAndStateBone<LiveRoom> createController(Site site, LiveArea subCategory) {
    final directory = site.liveSite;
    if (directory is LiveSiteDirectoryPager) {
      return LiveDirectoryController(directory: directory as LiveSiteDirectoryPager, category: subCategory);
    }
    if (directory is LiveSiteCategoryDirectoryProvider) {
      return LiveDirectoryController(
        directory: (directory as LiveSiteCategoryDirectoryProvider).categoryDirectory,
        category: subCategory,
      );
    }
    if (site.id == Sites.kuaishouSite) {
      return AreaServerAllController(site, subCategory);
    }
    if (site.id == Sites.douyuSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 40);
    }
    if (site.id == Sites.huyaSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 120);
    }
    if (site.id == Sites.soopSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 60);
    }
    if (site.id == Sites.twitcastingSite) {
      return AreaServerFixedController(site, subCategory, fixedSize: 60);
    }
    return AreaServerRemoteController(site, subCategory);
  }
}

class FavoriteAreasBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => FavoriteAreasController())];
  }
}

class HotAreasBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => HotAreasController())];
  }
}

class MultiviewBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => MultiviewController())];
  }
}

class LivePlayBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => LivePlayController(room: Get.arguments, site: Get.parameters["site"] ?? ""))];
  }
}

class SearchBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => SearchController())];
  }
}

class WebSearchBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => WebSearchController())];
  }
}

class DanmuShieldBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => DanmuShieldController())];
  }
}

class TagManagementBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => TagManagementController())];
  }
}

class RecordSettingsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => RecordSettingsController())];
  }
}

class RecorderBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => RecorderController())];
  }
}

class LocalVideoPlayerBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut(() {
        final args = Get.arguments as Map<String, dynamic>? ?? const {};
        return LocalVideoPlayerController(
          directory: args['dir'] as String? ?? '',
          roomTitle: args['title'] as String?,
          roomNick: args['nick'] as String?,
        );
      }),
    ];
  }
}

class RemoteSyncBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(RemoteSyncService.new)];
  }
}

class SettingsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => SettingsService())];
  }
}

class ToolBoxBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => ToolBoxController())];
  }
}

class VersionBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => VersionController())];
  }
}

class WebDavBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => WebDavPageController())];
  }
}
