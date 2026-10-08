import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/qr_login_controller.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/web_login_controller.dart';

class BilibiliWebLoginBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => BiliBiliWebLoginController())];
  }
}

class BilibiliQrLoginBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => BiliBiliQRLoginController())];
  }
}
