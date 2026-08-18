import 'package:better_player_plus/better_player_plus.dart';

///Controller of Better Player List Video Player.
class BetterPlayerListVideoPlayerController {
  BetterPlayerController? _betterPlayerController;

  void setVolume(double volume) {
    _betterPlayerController?.setVolume(volume);
  }

  void pause() {
    _betterPlayerController?.pause();
  }

  void play() {
    _betterPlayerController?.play();
  }

  void seekTo(Duration duration) {
    _betterPlayerController?.seekTo(duration);
  }

  // Kept as a method (not a setter) to maintain a consistent API with the rest of the controller
  // ignore: use_setters_to_change_properties
  void setBetterPlayerController(BetterPlayerController? betterPlayerController) {
    _betterPlayerController = betterPlayerController;
  }

  void setMixWithOthers(bool mixWithOthers) {
    _betterPlayerController?.setMixWithOthers(mixWithOthers);
  }
}
