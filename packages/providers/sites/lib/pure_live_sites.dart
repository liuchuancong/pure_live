// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_sites.dart
// Purpose: Public barrel of pure_live_sites; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-11
///
/// Layer: providers. Allowed dependencies: L0 foundation plus the L1 contract packages; providers never depend
/// on each other and never touch PlayerAdapter (invariants I1 and I5).
/// See docs/architecture/dependency-rules.md and the package README.
///
/// **Every live site is a directory here, not a package** (docs/architecture/package-architecture.md §2), and a
/// site is two files: `lib/src/<site>/<site>_api.dart` (what is asked, how it is signed, what comes back) and
/// `<site>_site.dart` (the class that answers the capability interfaces). The shapes a caller receives are the
/// shared ones in `pure_live_platform` - [ContentSummary], [ContentDetail], [MediaTicket], [StreamOption],
/// [LiveRoomStatus] - because 30+ 站点 each with their own model set would be 30 copies of the same room, line
/// and ticket. Adding a site is a new directory plus a test directory and one `registerBuiltInSources` call; the
/// reading rules they share are in `src/common/`.
///
/// Sites are plain Dart, registered at the composition root: there is no plugin, script or manifest mechanism on
/// this path (docs/architecture/package-architecture.md §2). Vod adapters live in `pure_live_vod` instead - a
/// video is re-openable while a live room is now-or-not, and resolve means different things to the two.
library;

export 'src/acfun/acfun_api.dart';
export 'src/acfun/acfun_site.dart';
export 'src/baidulive/baidulive_api.dart';
export 'src/baidulive/baidulive_site.dart';
export 'src/bigo/bigo_api.dart';
export 'src/bigo/bigo_site.dart';
export 'src/cc/cc_api.dart';
export 'src/cc/cc_site.dart';
export 'src/chzzk/chzzk_api.dart';
export 'src/chzzk/chzzk_site.dart';
export 'src/common/site_json.dart';
export 'src/douyu/douyu_api.dart';
export 'src/douyu/douyu_site.dart';
export 'src/huya/huya_api.dart';
export 'src/huya/huya_site.dart';
export 'src/inke/inke_api.dart';
export 'src/inke/inke_site.dart';
export 'src/jdlive/jdlive_api.dart';
export 'src/jdlive/jdlive_site.dart';
export 'src/kuaishou/kuaishou_api.dart';
export 'src/kuaishou/kuaishou_site.dart';
export 'src/kugou/kugou_api.dart';
export 'src/kugou/kugou_site.dart';
export 'src/missevan/missevan_api.dart';
export 'src/missevan/missevan_site.dart';
export 'src/picarto/picarto_api.dart';
export 'src/picarto/picarto_site.dart';
export 'src/showroom/showroom_api.dart';
export 'src/showroom/showroom_site.dart';
export 'src/soop/soop_api.dart';
export 'src/soop/soop_site.dart';
export 'src/weibo/weibo_api.dart';
export 'src/weibo/weibo_site.dart';
