import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';

class FavoriteController extends GetxController with GetTickerProviderStateMixin {
  final SettingsService settings = Get.find<SettingsService>();

  late TabController tabController;

  final tabBottomIndex = 0.obs;
  final tabSiteIndex = 0.obs;
  final tabOnlineIndex = 0.obs;
  bool isFirstLoad = true;
  StreamSubscription<dynamic>? subscription;
  Timer? _autoRefreshTimer;

  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);
  final onlineRooms = [].obs;
  final offlineRooms = [].obs;

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 2, vsync: this);

    syncRooms();

    debounce(settings.favoriteRooms, (rooms) => syncRooms(), time: const Duration(milliseconds: 1000));

    onRefresh();

    tabController.addListener(() {
      tabOnlineIndex.value = tabController.index;
    });

    if (settings.autoRefreshTime.value != 0) {
      _autoRefreshTimer = Timer.periodic(Duration(minutes: settings.autoRefreshTime.value), (timer) => onRefresh());
    }
    listenFavorite();
  }

  @override
  void onClose() {
    tabController.dispose();
    subscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.onClose();
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('refresh_favorite_rooms', (data) {
      onRefresh();
    });
  }

  void reloadPage() async {
    refreshController.callRefresh();
    await onRefresh();
    refreshController.finishRefresh(IndicatorResult.success);
  }

  void syncRooms() {
    onlineRooms.clear();
    offlineRooms.clear();
    onlineRooms.addAll(settings.favoriteRooms.where((room) => room.liveStatus == LiveStatus.live));
    offlineRooms.addAll(settings.favoriteRooms.where((room) => room.liveStatus != LiveStatus.live));
    for (var room in onlineRooms) {
      if (int.tryParse(room.watching!) == null) {
        room.watching = "0";
      }
    }
    onlineRooms.sort((a, b) => int.parse(b.watching!).compareTo(int.parse(a.watching!)));
  }

  Future<bool> onRefresh() async {
    if (isFirstLoad) await Future.delayed(const Duration(seconds: 1));

    if (settings.favoriteRooms.value.isEmpty) return false;

    var futures = settings.favoriteRooms.value
        .where((room) => room.platform!.isNotEmpty)
        .map((room) => Sites.of(room.platform!).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!))
        .toList();
    try {
      for (int i = 0; i < futures.length; i += 5) {
        try {
          List<LiveRoom> rooms = await Future.wait(futures.sublist(i, i + 5 > futures.length ? futures.length : i + 5));
          for (var room in rooms) {
            try {
              settings.updateRoom(room);
            } catch (e) {
              debugPrint('Error during refresh for a single request: $e');
            }
          }
        } catch (e) {
          debugPrint('Error during refresh for a batch of requests: $e');
        }
      }
      syncRooms();
    } catch (e) {
      debugPrint('Error during refresh: $e');
    }
    isFirstLoad = false;
    EventBus.instance.emit('refresh_favorite_finish', true);
    return false;
  }
}
