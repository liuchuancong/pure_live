import 'package:get/get.dart';
import 'package:pure_live/modules/site_account/site_account_controller.dart';

class SiteAccountBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut(() => SiteAccountController())
    ];
  }
}
