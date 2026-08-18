import 'package:better_player_plus/src/core/better_player_controller.dart';
import 'package:flutter/material.dart';

///Widget which is used to inherit BetterPlayerController through widget tree.
class BetterPlayerControllerProvider extends InheritedWidget {
  const BetterPlayerControllerProvider({super.key, required this.controller, required super.child});

  final BetterPlayerController controller;

  @override
  bool updateShouldNotify(BetterPlayerControllerProvider old) => controller != old.controller;
}
