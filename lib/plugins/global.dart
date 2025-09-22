import 'dart:io';
import 'package:pure_live/common/index.dart';

Future<void> register(String scheme) async {
  String appPath = Platform.resolvedExecutable;

  String protocolRegKey = 'Software\\Classes\\$scheme';
  RegistryValue protocolRegValue = const RegistryValue(
    'URL Protocol',
    RegistryValueType.string,
    '',
  );
  String protocolCmdRegKey = 'shell\\open\\command';
  RegistryValue protocolCmdRegValue = RegistryValue(
    '',
    RegistryValueType.string,
    '"$appPath" "%1"',
  );

  final regKey = Registry.currentUser.createKey(protocolRegKey);
  regKey.createValue(protocolRegValue);
  regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
}

void initRefresh() {
  EasyRefresh.defaultHeaderBuilder = () => const ClassicHeader(
        armedText: '松开加载',
        dragText: '上拉刷新',
        readyText: '加载中...',
        processingText: '正在刷新...',
        noMoreText: '没有更多数据了',
        failedText: '加载失败',
        messageText: '上次加载时间 %T',
        processedText: '加载成功',
      );
  EasyRefresh.defaultFooterBuilder = () => const ClassicFooter(
        armedText: '松开加载',
        dragText: '下拉刷新',
        readyText: '加载中...',
        processingText: '正在刷新...',
        noMoreText: '没有更多数据了',
        failedText: '加载失败',
        messageText: '上次加载时间 %T',
        processedText: '加载成功',
      );
}
