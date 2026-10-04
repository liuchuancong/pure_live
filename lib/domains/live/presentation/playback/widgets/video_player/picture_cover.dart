import 'package:flutter/widgets.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/audio_only_presentation.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/dummy_video_cover.dart';

/// 该拿哪一层盖子遮住画面，不需要时返回 null。
///
/// 纯音频的卡片优先：它本来就把画面盖住了，占位视频轨有没有真画面已经无关。
///
/// 房间视图与 PiP 紧凑视图**共用这一处判定**——PiP 不是独立原生窗口（Windows 上
/// `Win32PipWindow` 改的就是主窗口的样式与尺寸），但它是另一棵 Flutter 子树
/// （`buildPiPOverlay`），不会自动继承房间视图的盖子，所以两边都得问一次。
/// [room] 为 null 时不给盖子：没有房间就没有封面可显示，露出底下那路画面也比
/// 盖一层空壳诚实。
Widget? pictureCoverFor({required bool audioOnly, required bool dummyVideo, required LiveRoom? room}) {
  if (room == null) return null;
  if (audioOnly) return AudioOnlyPresentation(room: room);
  if (dummyVideo) return DummyVideoCover(room: room);
  return null;
}
