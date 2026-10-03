import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/domain/live_input_playback_binder.dart';
import 'package:pure_live/domains/recorder/data/services/live_input_playback_binding.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_input_recipe.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_input_recipe.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_input_recipe.dart';

void main() {
  group('自有输入的播放绑定', () {
    test('三种配方各自绑出带身份的播放源，且不会去开席位', () {
      // 只绑定、不打开：createInput 是惰性的，测试里碰网络就是另一回事了。
      final niconico = bindSiteInputForPlayback(
        NiconicoInputRecipe(programId: 'lv123456789', resolution: 'high', bandwidth: 1000),
      );
      expect(niconico.identity, 'niconico:lv123456789:high:1000');
      expect(niconico.url, isNull, reason: '自有输入没有可导出的 URL');

      expect(bindSiteInputForPlayback(BigoInputRecipe('site_1')).identity, 'bigo:site_1:live');
      expect(bindSiteInputForPlayback(Fc2InputRecipe('123456789')).identity, 'fc2live:123456789:auto');
    });

    test('未装配时绑定抛异常，装配后委托给实现', () {
      // 2026-10-01 的清理删掉了 switch 的全部 case 而站点仍在返回配方，
      // 结果 niconico/bigo/fc2 进房即 UnsupportedError。这里钉住两条边：
      // 没接线要大声失败，接了线要真的委托。
      configureLiveInputPlaybackBinder(null);
      expect(() => bindLiveInputForPlayback(BigoInputRecipe('site_1')), throwsUnsupportedError);

      configureLiveInputPlaybackBinder(bindSiteInputForPlayback);
      addTearDown(() => configureLiveInputPlaybackBinder(null));
      expect(bindLiveInputForPlayback(BigoInputRecipe('site_1')).identity, 'bigo:site_1:live');
    });
  });
}
