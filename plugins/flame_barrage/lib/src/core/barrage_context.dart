import '../model/barrage/barrage_item.dart';

class BarrageContext {
  final List<BarrageItem> barrages = [];

  int messageId = 0;

  int nextId() {
    return ++messageId;
  }
}
