import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/douyin/douyin_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/account_cookie_editor.dart';

class DouyinCookiePage extends GetView<DouyinCookieController> {
  const DouyinCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('douyin_cookie_hint'),
      tipText: i18n('douyin_cookie_tip'),
      onSave: controller.setCookie,
    );
  }
}
