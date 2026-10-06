import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/player_controller.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';

/// 失败提示选哪个键。
///
/// 两个代理开关长得太像：「播放器代理」管引擎去拉流，「应用层代理」管产生那个
/// 地址的页面与 API 请求。日志里 `mpv` 走了 127.0.0.1:7897 而站点请求直连被掐断，
/// 观众看到的却只有一句"读取视频信息失败"——它会把人支去找坏掉的适配器。
void main() {
  group('取流信息失败的提示选择', () {
    test('站点没答话时点名管这条路的开关', () {
      expect(
        streamMetadataFailureKey(error: const NiconicoException(NiconicoFailure.transport), appProxyEnabled: false),
        'site_unreachable',
      );
      // 代理已经开着就不能再劝人开代理，要说的是这条节点到不到得了。
      expect(
        streamMetadataFailureKey(error: const NiconicoException(NiconicoFailure.transport), appProxyEnabled: true),
        'site_unreachable_via_proxy',
      );
    });

    test('站点答了话就还是原来那句', () {
      expect(
        streamMetadataFailureKey(error: const NiconicoException(NiconicoFailure.access), appProxyEnabled: false),
        'read_video_failed',
      );
      expect(
        streamMetadataFailureKey(error: const NiconicoException(NiconicoFailure.notLive), appProxyEnabled: true),
        'read_video_failed',
      );
    });
  });
}
