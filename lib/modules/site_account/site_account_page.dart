import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/site_account/site_account_controller.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';

import '../util/site_logo_widget.dart';

class SiteAccountPage extends GetView<SiteAccountController> {
  const SiteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.three_party_authentication),
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              S.current.bilibili_need_login_info,
              textAlign: TextAlign.center,
            ),
          ),
          ...Sites.supportSites.where((site) => !([Sites.iptvSite, Sites.allSite].contains(site.id))).map((site) => site.liveSite.isSupportLogin()
              ? Obx(
                  () => ListTile(
                    leading: SiteWidget.getSiteLogo(site),
                    title: Text("${Sites.getSiteName(site.id)} ${S.current.live}"),
                    subtitle: Text(site.liveSite.userName.value.getNotNullOrEmptyByDefault(S.current.login_not)),
                    trailing: site.liveSite.isLogin.value ? const Icon(Icons.logout) : const Icon(Icons.chevron_right),
                    onTap: () {
                      controller.onTap(site);
                    },
                  ),
                )
              : ListTile(
                  leading: SiteWidget.getSiteLogo(site),
                  title: Text("${Sites.getSiteName(site.id)} ${S.current.live}"),
                  subtitle: Text(S.current.not_supported),
                  enabled: false,
                  trailing: const Icon(Icons.chevron_right),
                )),
        ],
      ),
    );
  }
}
