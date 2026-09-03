import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/twitch/twitch_cookie_controller.dart';

class TwitchCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(TwitchCookieBindingCookieController.new)];
  }
}
