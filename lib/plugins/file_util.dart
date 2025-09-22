import 'dart:io';

import 'package:pure_live/core/common/core_log.dart';

/// 文件处理
final class FileUtil {
  /// 获取目录大小
  static Future<double> getTotalSizeOfFilesInDir(final FileSystemEntity file) async {
    try {
      if (file is File) {
        int length = await file.length();
        return double.parse(length.toString());
      }
      if (file is Directory) {
        List<Future<double>> futures = [];
        final List<FileSystemEntity> children = file.listSync();
        double total = 0;
        for (final FileSystemEntity child in children) {
          futures.add(getTotalSizeOfFilesInDir(child));
        }
        final totalList = await Future.wait(futures);
        for (var i in totalList) {
          total += i;
        }
        return total;
      }
      return 0;
    } catch (e) {
      CoreLog.error(e);
      return 0;
    }
  }

  /// 格式化文件大小
  static String formatSize(double value) {
    if (value <= 0) {
      return '0 B';
    }
    List<String> unitArr = ["B", "KB", "MB", "GB", "TB"];
    int index = 0;
    var radix = 1024;
    while (value >= radix && index < unitArr.length - 1) {
      index++;
      value = value / radix;
    }
    String size = value.toStringAsFixed(2);
    return "$size ${unitArr[index]}";
  }

  /// 删除文件夹下所有文件、或者单一文件
  static Future<Null> deleteDirectory(FileSystemEntity file) async {
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      for (final FileSystemEntity child in children) {
        deleteDirectory(child);
        child.delete().catchError((err) {
          CoreLog.error(err);
        }, test: (error) {
          return error is int && error >= 400;
        });
        // try {
        //   child.delete().catchError((e){CoreLog.error(e);});
        // } catch (e) {
        //   CoreLog.error(e);
        // }
      }
    }
  }

  /// 删除文件夹下的文件，不包括文件夹
  static Future<Null> deleteFile(FileSystemEntity file, int deleteMillisecond) async {
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      for (final FileSystemEntity child in children) {
        deleteFile(child, deleteMillisecond);
      }
    } else if (file is File) {
      var lastAccessedTime = file.lastAccessedSync();
      var millisecond = lastAccessedTime.millisecondsSinceEpoch;
      if (deleteMillisecond >= millisecond) {
        file.delete();
      }
    }
  }
}
