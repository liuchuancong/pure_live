import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class DbService extends GetxService {
  late final database.AppDatabase db;

  Future<DbService> init() async {
    db = database.AppDatabase();
    return this;
  }
}
