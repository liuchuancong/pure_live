import 'package:get/get.dart';

class GlobalPlayerState extends GetxController {
  static GlobalPlayerState get to => Get.find<GlobalPlayerState>();
  // 全屏
  var isFullscreen = false.obs;
  // window 半屏
  var isWindowFullscreen = false.obs;

  // 是否画中画
  var isPipMode = false.obs;
  bool get fullscreenUI => isFullscreen.value || isWindowFullscreen.value;
  void reset() {
    isFullscreen.value = false;
    isWindowFullscreen.value = false;
    isPipMode.value = false;
  }

  String? _currentRoomId;

  void setCurrentRoom(String roomId) {
    if (_currentRoomId != roomId) {
      _currentRoomId = roomId;
    }
  }
}
