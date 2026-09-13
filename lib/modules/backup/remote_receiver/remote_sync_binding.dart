import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/backup/remote_receiver/remote_sync_service.dart';

class RemoteSyncBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(RemoteSyncService.new)];
  }
}
