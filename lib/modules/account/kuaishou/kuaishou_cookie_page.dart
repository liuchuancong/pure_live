import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_controller.dart';

class KuaishouCookiePage extends GetView<KuaishouCookieController> {
  const KuaishouCookiePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("set_cookie"))),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          Padding(padding: const EdgeInsets.all(8.0), child: Text(i18n("kuaishou_cookie_tip"))),
          buildCard(
            context: context,
            child: ExpansionTile(
              title: Text(i18n("cookie")),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              initiallyExpanded: true,
              children: [
                TextField(
                  minLines: 3,
                  maxLines: 3,
                  controller: controller.cookieController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: i18n("kuaishou_cookie_hint"),
                    contentPadding: const EdgeInsets.all(12.0),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withValues(alpha: .2))),
                  ),
                  onSubmitted: controller.setCookie,
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 4.0),
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      controller.setCookie(controller.cookieController.text);
                    },
                    icon: const Icon(Remix.settings_2_fill),
                    label: Text(i18n("set")),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard({required BuildContext context, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        boxShadow: Get.isDarkMode ? [] : [BoxShadow(blurRadius: 8, color: Colors.grey.withValues(alpha: .2))],
      ),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: child,
      ),
    );
  }
}
