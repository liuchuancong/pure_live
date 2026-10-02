import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/account/twitch/twitch_cookie_controller.dart';

class TwitchCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => TwitchCookieBindingCookieController())];
  }
}
