import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/account/twitch/twitch_cookie_controller.dart';
import 'package:pure_live/modules/account/widgets/account_cookie_editor.dart';

class TwitchCookiePage extends GetView<TwitchCookieBindingCookieController> {
  const TwitchCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('twitch_cookie_hint'),
      tipText: i18n('twitch_cookie_tip'),
      onSave: controller.setCookie,
    );
  }
}
