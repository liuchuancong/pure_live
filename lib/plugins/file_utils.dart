import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class FileUtils {
  static const String systemHotProviderId = "88888";

  /// 获取文件路径中的纯文件名
  static String getFileName(String fullPath) {
    return fullPath.split(Platform.pathSeparator).last;
  }

  /// 获取不带后缀的文件名
  static String getBaseName(String fullPath) {
    return p.basenameWithoutExtension(fullPath);
  }

  /// 生成基于时间戳和随机数的唯一长整数 ID 字符串
  static String generateUuid() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final randomValue = Random().nextInt(4294967295);
    final result = (currentTime % 10000000000 * 1000 + randomValue) % 4294967295;
    return result.toString();
  }

  /// 验证是否为合法 URL 链接
  static bool isValidUrl(String value) {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    return urlRegExp.allMatches(value).isNotEmpty;
  }

  /// 验证是否包含 Host 域名的 URL 链接
  static bool isHostUrl(String value) {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    return urlRegExp.allMatches(value).isNotEmpty;
  }

  /// 验证字符串是否为纯数字（端口号校验）
  static bool isNumericPort(String value) {
    return RegExp(r"^\d+$").hasMatch(value);
  }

  /// 请求外部存储管理权限
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (await Permission.manageExternalStorage.isDenied) {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  static Future<File> convertPhysicalFile(String shareContent) async {
    if (shareContent.isEmpty) {
      throw const FileSystemException("Shared data string content stream is fully empty");
    }
    if (shareContent.startsWith('file://')) {
      return File(Uri.parse(shareContent).toFilePath());
    }

    final fileRef = File(shareContent);
    if (await fileRef.exists()) {
      return fileRef;
    }
    throw FileSystemException("Shared media target path cannot be verified on flash drive storage", shareContent);
  }

  static Future<bool> openFileOrUrl(String pathOrUrl) async {
    final trimmedPath = pathOrUrl.trim();
    if (trimmedPath.isEmpty) return false;

    // 1. 处理标准 Web/Network 网络链接
    if (isValidUrl(trimmedPath)) {
      try {
        final Uri uri = Uri.parse(trimmedPath);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        return false;
      }
      return false;
    }

    final file = File(trimmedPath);
    final directory = Directory(trimmedPath);
    final bool targetExists = await file.exists() || await directory.exists();
    if (!targetExists) return false;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        if (Platform.isWindows) {
          await Process.run('explorer.exe', [p.context.canonicalize(trimmedPath)]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [trimmedPath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [trimmedPath]);
        }
        return true;
      } catch (_) {}
    }

    try {
      final result = await OpenFilex.open(trimmedPath);
      return result.type == ResultType.done;
    } catch (_) {
      try {
        final String cleanPath = trimmedPath.startsWith('file://') ? trimmedPath : 'file://$trimmedPath';
        final Uri fileUri = Uri.parse(cleanPath);
        if (await canLaunchUrl(fileUri)) {
          return await launchUrl(fileUri);
        }
      } catch (_) {}
    }

    return false;
  }
}
