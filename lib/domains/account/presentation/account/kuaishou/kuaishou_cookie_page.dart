import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/kuaishou/kuaishou_cookie_controller.dart';
import 'package:pure_live/domains/account/presentation/account/account_cookie_editor.dart';

class KuaishouCookiePage extends GetView<KuaishouCookieController> {
  const KuaishouCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountCookieEditorPage(
      controller: controller.cookieController,
      hintText: i18n('kuaishou_cookie_hint'),
      tipText: i18n('kuaishou_cookie_tip'),
      onSave: controller.setCookie,
    );
  }
}
