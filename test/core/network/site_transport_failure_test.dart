import 'dart:io' show Directory, File, HandshakeException, SocketException;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/site_transport_failure.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';

class _Declared implements SiteTransportFailure {
  const _Declared(this.isSiteUnreachable);

  @override
  final bool isSiteUnreachable;
}

DioException _dio(DioExceptionType type, {Object? error}) => DioException(
  requestOptions: RequestOptions(path: 'https://live.nicovideo.jp/watch/lv123'),
  type: type,
  error: error,
);

/// 扫源码而不是逐个构造：新增一个适配器忘了实现接口，构造式测试永远是绿的，
/// 只有这条规则会红。
List<String> _adaptersMissingTheDeclaration() {
  final offenders = <String>[];
  for (final entity in Directory('lib/shared/platforms').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in RegExp(r'class (\w+Exception) implements Exception(\w|,|\s|\{)*?\{').allMatches(source)) {
      final body = source.substring(match.start, source.indexOf('\n}', match.end));
      final kind = RegExp(r'final (\w+Failure\w*) kind;').firstMatch(body);
      if (kind == null) continue;
      // 传输档在站点自己的枚举里；同目录扫一次就够了。
      final enums = Directory(entity.parent.path)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .map((text) => RegExp('enum ${kind.group(1)} \\{(.*?)\\}', dotAll: true).firstMatch(text)?.group(1))
          .whereType<String>()
          .join();
      if (!RegExp(r'(^|[{\s,])transport([,\s}]|\s*$)', multiLine: true).hasMatch(enums)) continue;
      if (!match.group(0)!.contains('SiteTransportFailure')) offenders.add('${entity.path} ${match.group(1)}');
    }
  }
  return offenders;
}

void main() {
  group('站点异常的"没答话"信号', () {
    test('声明 transport 就是没拿到可读响应', () {
      expect(isUnreachableSiteFailure(const NiconicoException(NiconicoFailure.transport)), isTrue);
      expect(isUnreachableSiteFailure(const BigoException(BigoFailure.transport)), isTrue);
      expect(isUnreachableSiteFailure(const _Declared(true)), isTrue);
    });

    test('站点答了话就不算连不上', () {
      // 403、找不到房间、被限流都是**关于这个房间**的答复，走原来的提示；
      // 把它们一起说成"连不上站点"会把人支到代理设置上去。
      expect(isUnreachableSiteFailure(const NiconicoException(NiconicoFailure.access)), isFalse);
      expect(isUnreachableSiteFailure(const NiconicoException(NiconicoFailure.missing)), isFalse);
      expect(isUnreachableSiteFailure(const NiconicoException(NiconicoFailure.cancelled)), isFalse);
      expect(isUnreachableSiteFailure(const _Declared(false)), isFalse);
    });

    test('dio 认得出的连接失败算连不上', () {
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.connectionError)), isTrue);
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.connectionTimeout)), isTrue);
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.receiveTimeout)), isTrue);
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.sendTimeout)), isTrue);
    });

    test('TLS 被掐断在 dio 里是 unknown，只有内层错误认得出来', () {
      // 这就是被墙/被地域封锁时日志里的形状：`Underlying Type: HandshakeException`
      // 而 `Response Code: none`。dio 只把 SocketException 映射成连接类错误，
      // 握手失败原样塞进 error，整个异常的类型是 unknown。
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.unknown, error: HandshakeException('reset'))), isTrue);
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.unknown, error: const SocketException('refused'))), isTrue);
      // 而 unknown 也可能是解析炸了——那不是网络。
      expect(
        isUnreachableSiteFailure(_dio(DioExceptionType.unknown, error: const FormatException('bad json'))),
        isFalse,
      );
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.badResponse)), isFalse);
      expect(isUnreachableSiteFailure(_dio(DioExceptionType.cancel)), isFalse);
    });

    test('没包成 DioException 的原始错误也算连不上', () {
      expect(isUnreachableSiteFailure(const SocketException('connection refused')), isTrue);
      expect(isUnreachableSiteFailure(HandshakeException('closed during handshake')), isTrue);
    });

    test('每个有 transport 档的站点异常类都声明了它', () {
      expect(
        _adaptersMissingTheDeclaration(),
        isEmpty,
        reason:
            '站点适配器的 failure enum 里有 transport，异常类却没声明 SiteTransportFailure：'
            '这个站点连不上时会重新回报成「读取视频信息失败」，观众找不到该动哪个设置。',
      );
    });
  });
}
