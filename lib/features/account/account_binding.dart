import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/account/account_controller.dart';

class AccountBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => AccountController())];
  }
}
