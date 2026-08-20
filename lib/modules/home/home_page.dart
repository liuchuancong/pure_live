import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:move_to_desktop/move_to_desktop.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/modules/areas/areas_page.dart';
import 'package:pure_live/modules/home/mobile_view.dart';
import 'package:pure_live/modules/home/tablet_view.dart';
import 'package:pure_live/modules/popular/popular_page.dart';
import 'package:pure_live/modules/favorite/favorite_page.dart';
import 'package:pure_live/modules/about/widgets/version_dialog.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';
import 'package:pure_live/common/global/initialized.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/player/models/player_engine.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  Timer? _debounceTimer;
  final FavoriteController favoriteController = Get.find<FavoriteController>();
  late final VoidCallback _favoriteTabListener;
  Worker? _savedMenuWorker;
  DateTime? _backgroundedAt;

  int _selectedIndex = 0;

  final Map<HomeMenu, Widget> _pageMap = const {
    HomeMenu.favorites: FavoritePage(),
    HomeMenu.popular: PopularPage(),
    HomeMenu.areas: AreasPage(),
    HomeMenu.record: RecorderPage(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncInitialIndex();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (Platform.isAndroid) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Theme.of(context).navigationBarTheme.backgroundColor,
          ),
        );
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }

      final initialRoom = AppInitializer().takeInitialRoom();
      if (initialRoom != null && mounted) {
        // MyApp prewarms the global player asynchronously. Reusing that same
        // initialization Future prevents a command-line room from racing a
        // second PlayerManager into existence on fast desktop startup.
        await GlobalPlayerService.instance.initialize(defaultEngine: PlayerEngine.mediaKit);
        if (!mounted) return;
        await AppNavigator.toLiveRoomDetail(liveRoom: initialRoom);
      }
    });

    addToOverlay();

    _favoriteTabListener = () {
      if (mounted) {
        setState(() => _selectedIndex = favoriteController.tabBottomIndex.value);
      }
    };
    favoriteController.tabBottomIndex.addListener(_favoriteTabListener);

    _savedMenuWorker = ever(SettingsService.to.app.savedMenuIds, (v) {
      if (mounted) {
        final List<String> value = List<String>.from(v as List);
        if (value.isNotEmpty) {
          final currentMenuId = HomeMenu.values[_selectedIndex].id;
          if (!value.contains(currentMenuId)) {
            final firstMenu = HomeMenu.fromId(value.first);
            if (firstMenu != null) {
              onDestinationSelected(firstMenu.index);
            }
          }
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null || DateTime.now().difference(backgroundedAt) < const Duration(seconds: 15)) return;

    final menu = HomeMenu.values[_selectedIndex];
    if (menu == HomeMenu.popular) {
      unawaited(Get.find<PopularController>().refreshCurrentData());
    } else if (menu == HomeMenu.areas) {
      unawaited(Get.find<AreasController>().refreshCurrentData());
    }
  }

  void _syncInitialIndex() {
    final activeIds = SettingsService.to.app.savedMenuIds.v;
    if (activeIds.isNotEmpty) {
      final firstMenu = HomeMenu.fromId(activeIds.first);
      if (firstMenu != null) {
        _selectedIndex = firstMenu.index;
        favoriteController.tabBottomIndex.value = firstMenu.index;
      }
    }
  }

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
    favoriteController.refreshData();
  }

  void onDestinationSelected(int index) {
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
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
    await VersionUtil.initPackageInfo();
    await VersionUtil().checkUpdate();
    bool isHasNerVersion = SettingsService.to.app.enableAutoCheckUpdate.v && VersionUtil.hasNewVersion();
    if (mounted) {
      if (overlay != null && isHasNerVersion) {
        WidgetsBinding.instance.addPostFrameCallback((_) => overlay.insert(entry));
      } else {
        if (overlay != null && isHasNerVersion) {
          overlay.insert(entry);
        }
      }
    }
  }

  void onBackButtonPressed(bool didPop, _) async {
    if (!didPop) {
      MoveToDesktop().moveToDesktop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: onBackButtonPressed,
      child: LayoutBuilder(
        builder: (context, constraint) {
          final bool isTablet = constraint.maxWidth > 680;

          return Obx(() {
            final activeMenuIds = List<String>.from(SettingsService.to.app.savedMenuIds.v);
            if (isTablet) {
              activeMenuIds.remove(HomeMenu.record.id);
            }
            if (activeMenuIds.isEmpty) return const Scaffold();

            int adjustedIndex = _selectedIndex;
            if (adjustedIndex >= HomeMenu.values.length ||
                (isTablet && HomeMenu.values[adjustedIndex] == HomeMenu.record)) {
              final fallbackMenu = HomeMenu.fromId(activeMenuIds.first);
              if (fallbackMenu != null) {
                adjustedIndex = fallbackMenu.index;
              }
            }

            final currentMenu = HomeMenu.values[adjustedIndex];
            final currentWidget = _pageMap[currentMenu] ?? const SizedBox.shrink();

            return !isTablet
                ? HomeMobileView(
                    body: currentWidget,
                    index: adjustedIndex,
                    onDestinationSelected: onDestinationSelected,
                    onFavoriteDoubleTap: handMoveRefresh,
                  )
                : HomeTabletView(
                    body: currentWidget,
                    index: adjustedIndex,
                    activeMenuIds: activeMenuIds,
                    onDestinationSelected: onDestinationSelected,
                  );
          });
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    favoriteController.tabBottomIndex.removeListener(_favoriteTabListener);
    _savedMenuWorker?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
