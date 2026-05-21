import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/common/global/app_path_manager.dart';

class PlaylistStorage {
  static const _uuid = Uuid();

  static Future<Directory> _playlistDir() async {
    final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
    final playlistDir = Directory(p.join(dir.path, AppPathManager.iptvTable, 'playlists'));
    if (!await playlistDir.exists()) {
      await playlistDir.create(recursive: true);
    }

    return playlistDir;
  }

  /// 保存用户导入文件
  static Future<File> saveImportedFile(File sourceFile) async {
    final dir = await _playlistDir();
    final ext = p.extension(sourceFile.path);
    final filename = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$ext';
    final target = File(p.join(dir.path, filename));
    return sourceFile.copy(target.path);
  }

  /// 保存网络 playlist
  static Future<File> saveRemoteContent({required String content, required String extension}) async {
    final dir = await _playlistDir();
    final filename = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$extension';
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(content);
    return file;
  }

  /// 删除 playlist
  static Future<void> deletePlaylist(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
