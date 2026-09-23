import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/douyu/douyu_cookie_controller.dart';
import 'package:pure_live/modules/account/widgets/account_cookie_editor.dart';

class DouyuCookiePage extends GetView<DouyuCookieController> {
  const DouyuCookiePage({super.key});

  @override
  Widget build(BuildContext context) => AccountCookieEditorPage(
    controller: controller.cookieController,
    hintText: i18n('cookie_hint', args: {'name': i18n('site_douyu')}),
    tipText: i18n('cookie_tip', args: {'name': i18n('site_douyu')}),
    onSave: controller.setCookie,
  );
}
