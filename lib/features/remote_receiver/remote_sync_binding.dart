import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';

class RemoteSyncBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(RemoteSyncService.new)];
  }
}
