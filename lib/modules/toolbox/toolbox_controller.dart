import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';

class ToolBoxController extends GetxController {
  final TextEditingController roomJumpToController = TextEditingController();
  final TextEditingController getUrlController = TextEditingController();

  void jumpToRoom(String e) async {
    if (e.isEmpty) {
      ToastUtil.show(i18n("toolbox_empty_link"));
      return;
    }
    var parseResult = await LiveUrlTool.parseLiveUrl(e);
    if (parseResult.isEmpty || parseResult.first == "") {
      ToastUtil.show(i18n("toolbox_parse_failed"));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    Future.delayed(const Duration(milliseconds: 200), () {
      String platform = parseResult[1];
      AppNavigator.toLiveRoomDetail(
        liveRoom: LiveRoom(
          roomId: parseResult.first,
          platform: platform,
          title: "",
          cover: '',
          nick: "",
          watching: '',
          avatar: "",
          area: '',
          liveStatus: LiveStatus.live,
          status: true,
          data: '',
          danmakuData: '',
        ),
      );
    });
  }

  void getPlayUrl(String e) async {
    await LiveUrlTool.getLivePlayUrl(e);
  }

  void autoCheckClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    String? text = data?.text;
    if (text == null || text.isEmpty) return;

    final bool isLiveUrl = RegExp(r"bilibili|huya|douyu|douyin|kuaishou|163").hasMatch(text);
    if (isLiveUrl) {
      roomJumpToController.text = text;
      getUrlController.text = text;
      Get.snackbar(
        i18n("toolbox_detect_link"),
        i18n("toolbox_auto_fill"),
        snackPosition: SnackPosition.bottom,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(15),
      );
    }
  }

  @override
  void onClose() {
    roomJumpToController.dispose();
    getUrlController.dispose();
    super.onClose();
  }
}
