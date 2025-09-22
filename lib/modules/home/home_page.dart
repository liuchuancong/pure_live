import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:move_to_desktop/move_to_desktop.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/about/widgets/version_dialog.dart';
import 'package:pure_live/modules/areas/areas_page.dart';
import 'package:pure_live/modules/favorite/favorite_page.dart';
import 'package:pure_live/modules/home/mobile_view_v2.dart';
import 'package:pure_live/modules/home/tablet_view_v2.dart';
import 'package:pure_live/modules/popular/popular_page.dart';
import 'package:pure_live/modules/search/search_controller.dart'
    as search_controller;
import 'package:pure_live/modules/search/search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, WindowListener {
  Timer? _debounceTimer;
  final FavoriteController favoriteController = Get.find<FavoriteController>();

  @override
  void initState() {
    super.initState();
    // check update overlay ui
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) async {
        // Android statusbar and navigationbar
        if (Platform.isAndroid || Platform.isIOS) {
          SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarColor: Colors.transparent,
          ));
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } else {
          windowManager.addListener(this);
        }
      },
    );
    addToOverlay();
    favoriteController.tabBottomIndex.addListener(() {
      setState(() => _selectedIndex = favoriteController.tabBottomIndex.value);
      setPageController(_selectedIndex);
    });
  }

  void setPageController(int selectIndex) {
    switch (selectIndex) {
      case 0:
        try {
          var findOrNull = Get.findOrNull<FavoriteController>();
          if (findOrNull == null) {
            Get.put(FavoriteController());
          }
        } catch (e) {
          CoreLog.error(e);
        }
        break;
      case 1:
        try {
          var findOrNull = Get.findOrNull<PopularController>();
          if (findOrNull == null) {
            Get.put(PopularController());
          }
        } catch (e) {
          CoreLog.error(e);
        }
        break;
      case 2:
        try {
          var findOrNull = Get.findOrNull<AreasController>();
          if (findOrNull == null) {
            Get.put(AreasController());
          }
        } catch (e) {
          CoreLog.error(e);
        }
        break;
      case 3:
        try {
          var findOrNull = Get.findOrNull<search_controller.SearchController>();
          if (findOrNull == null) {
            Get.put(search_controller.SearchController());
          }
        } catch (e) {
          CoreLog.error(e);
        }
        break;
      default:
        try {
          var findOrNull = Get.findOrNull<FavoriteController>();
          if (findOrNull == null) {
            Get.put(FavoriteController());
          }
        } catch (e) {
          CoreLog.error(e);
        }
        break;
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }

  int _selectedIndex = 0;
  final List<Widget> bodys = const [
    FavoritePage(),
    PopularPage(),
    AreasPage(),
    SearchPage(),
  ];

  void debounceListen(Function? func, [int delay = 1000]) {
    if (_debounceTimer != null) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(Duration(milliseconds: delay), () {
      func?.call();

      _debounceTimer = null;
    });
  }

  void handMoveRefresh() {
    favoriteController.onRefresh();
  }

  void onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    favoriteController.tabBottomIndex.value = index;
  }

  Future<void> addToOverlay() async {
    final overlay = Overlay.maybeOf(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Container(
        alignment: Alignment.center,
        color: Colors.black54,
        child: NewVersionDialog(entry: entry),
      ),
    );
    await VersionUtil.checkUpdate();
    bool isHasNerVersion =
        Get.find<SettingsService>().enableAutoCheckUpdate.value &&
            VersionUtil.hasNewVersion();
    if (mounted) {
      if (overlay != null && isHasNerVersion) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => overlay.insert(entry));
      } else {
        if (overlay != null && isHasNerVersion) {
          overlay.insert(entry);
        }
      }
    }
  }

  void onBackButtonPressed(bool canPop, data) async {
    if (canPop) {
      final moveToDesktopPlugin = MoveToDesktop();
      await moveToDesktopPlugin.moveToDesktop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: Get.currentRoute == RoutePath.kInitial,
      onPopInvokedWithResult: onBackButtonPressed,
      child: LayoutBuilder(
        builder: (context, constraint) => constraint.maxWidth <= 680
            ? HomeMobileViewV2()
            : HomeTabletViewV2(),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
