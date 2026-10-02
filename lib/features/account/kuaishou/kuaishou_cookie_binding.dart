import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/account/kuaishou/kuaishou_cookie_controller.dart';

class KuaishouCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => KuaishouCookieController())];
  }
}
