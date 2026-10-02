import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/recorder/pages/record_settings/record_settings_controller.dart';

class RecordSettingsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => RecordSettingsController())];
  }
}
