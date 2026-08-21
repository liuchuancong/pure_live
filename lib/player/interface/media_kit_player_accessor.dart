import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

abstract interface class MediaKitPlayerAccessor {
  Player get mediaKitPlayer;

  VideoController get mediaKitVideoController;
}
