import 'package:get/get.dart';
import 'package:pure_live/recorder/pages/record_history/record_history_service.dart';

class RecordHistoryBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => RecordHistoryService())];
  }
}
