import 'package:get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/site_account/login/qr_login_controller.dart';
import 'package:pure_live/modules/site_account/login/web_login_controller.dart';

class SiteWebLoginBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut(() => SiteWebLoginController(
            site: Sites.of(Get.parameters["site"] ?? ""),
          )),
    ];
  }
}

class SiteQrLoginBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut(() => SiteQRLoginController(
            site: Sites.of(Get.parameters["site"] ?? ""),
          )),
    ];
  }
}
