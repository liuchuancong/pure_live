import 'package:flame/components.dart';
import '../model/barrage/barrage_type.dart';
import '../components/barrage_component.dart';

class BarrageLayer extends Component {
  BarrageLayer({required this.type});

  final BarrageType type;

  void addBarrage(BarrageComponent component) {
    add(component);
  }

  void clear() {
    final components = children.whereType<BarrageComponent>().toList();
    removeAll(components);
  }

  List<BarrageComponent> get activeComponents {
    return children.whereType<BarrageComponent>().toList();
  }
}
