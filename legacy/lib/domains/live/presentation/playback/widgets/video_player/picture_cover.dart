import 'package:flutter/widgets.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/audio_only_presentation.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/dummy_video_cover.dart';

Widget? pictureCoverFor({required bool audioOnly, required bool dummyVideo, required LiveRoom? room}) {
  if (room == null) return null;
  if (audioOnly) return AudioOnlyPresentation(room: room);
  if (dummyVideo) return DummyVideoCover(room: room);
  return null;
}
