import 'package:remixicon/remixicon.dart';

import 'package:pure_live/core/index.dart';

/// 直播源只给了一路占位视频（例如猫耳 FM 的 16×16 h264）时，盖在画面上的房间封面。
///
/// 和纯音频模式那层一样是**盖住**而不是替换：视频组件留在树上继续解码，帧心跳不
/// 断，看门狗不会把好好在播的房间判成卡死。区别是这里没有"切回视频"可言——源里
/// 就没有真画面，所以说明条常驻，免得用户以为卡住了。
///
/// 背景必须不透明：底下那路占位视频还在被拉伸着画，半透明就是一层纯色糊在上面。
/// 整层 [IgnorePointer]：控制层叠在它上面，手势要能落下去。
class DummyVideoCover extends StatelessWidget {
  const DummyVideoCover({super.key, required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    // 封面优先，没有就用头像：两者都没有时留纯黑，也比一片拉伸的纯色强。
    final candidates = [room.cover, room.avatar];
    var image = '';
    for (final candidate in candidates) {
      final normalized = normalizeNetworkImageUrl(candidate);
      if (normalized.isNotEmpty) {
        image = normalized;
        break;
      }
    }

    return IgnorePointer(
      child: ColoredBox(
        key: const ValueKey('dummy-video-cover'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              Image.network(
                image,
                fit: BoxFit.cover,
                headers: networkImageHeaders(image),
                errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.headphone_line, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          i18n('dummy_video_cover_notice'),
                          key: const ValueKey('dummy-video-notice'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t12.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
