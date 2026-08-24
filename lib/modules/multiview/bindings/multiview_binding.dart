import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/multiview/multiview_controller.dart';

/// 多画面同看页绑定。
///
/// 生产依赖（每格播放器工厂、站点解析器、全局播放暂停钩子）由
/// [MultiviewController] 构造函数默认装配；测试直接构造控制器并注入假实现。
class MultiviewBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => MultiviewController())];
  }
}
