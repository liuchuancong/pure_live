import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/account/account_controller.dart';

import '../util/site_logo_widget.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({super.key});

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
          Obx(
            () => ListTile(
              leading: SiteWidget.getSiteLogeImage(Sites.bilibiliSite),
              title: Text(S.current.bilibili),
              subtitle: Text(BiliBiliAccountService.instance.name.value),
              trailing: BiliBiliAccountService.instance.logined.value ? const Icon(Icons.logout) : const Icon(Icons.chevron_right),
              onTap: controller.bilibiliTap,
            ),
          ),
          ...Sites.supportSites.where((site) => !([Sites.bilibiliSite, Sites.allSite].contains(site.id))).map((site) => ListTile(
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
