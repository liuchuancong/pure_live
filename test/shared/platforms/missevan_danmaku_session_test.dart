import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/missevan/missevan_danmaku.dart';

void main() {
  group('猫耳游客会话 cookie', () {
    test('两个 Set-Cookie 里取 FM_SESS，忽略 FM_SESS.sig', () {
      // 线上就是这组头。dio 的 Headers.value() 在多于一个同名值时抛异常，
      // 三次重试会把异常全吃掉，界面表现成"拿不到游客会话"。
      expect(
        MissevanDanmaku.sessionCookie(const [
          'FM_SESS.sig=abc123; Path=/; HttpOnly',
          'FM_SESS=def456; Path=/; HttpOnly',
        ]),
        'def456',
      );
    });

    test('带属性的值只取到分号为止', () {
      expect(MissevanDanmaku.sessionCookie(const ['FM_SESS=def456; Path=/; Max-Age=600']), 'def456');
    });

    test('只有签名 cookie 或整组为空时是 null', () {
      expect(MissevanDanmaku.sessionCookie(const ['FM_SESS.sig=abc123; Path=/']), isNull);
      expect(MissevanDanmaku.sessionCookie(const <String>[]), isNull);
    });
  });
}
