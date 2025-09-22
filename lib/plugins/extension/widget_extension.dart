import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';

extension WidgetExtension on Widget {
  /// 监控状态
  Widget get obx {
    return Obx(() => this);
  }

  /// 监控状态
  Widget obxValue<T extends RxInterface>(T data) {
    return ObxValue((T ii) => this, data);
  }

  /// 保活
  Widget get keepAlive {
    return KeepAliveWrapper(
      child: this,
    );
  }

  /// 扩展
  Widget get expanded {
    return Expanded(
      child: this,
    );
  }

  /// 监听数据
  Widget  listenValue<T extends Rx>(T data) {
    return StreamBuilder(
        initialData: data.value,
        stream: data.stream,
        builder: (s, d) {
          return this;
        });
  }
}
