import 'package:pure_live/core/models/live_room.dart';

class CurrentLiveRoom {
  static LiveRoom? Function()? provider;

  static LiveRoom? get value => provider?.call();
}
