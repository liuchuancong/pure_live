import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

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

  static Uri? parseHttpUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || RegExp(r'\s').hasMatch(trimmed)) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) return null;

    try {
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return null;
    } on FormatException {
      return null;
    }
    return uri.scheme == scheme ? uri : uri.replace(scheme: scheme);
  }

  /// Only complete HTTP(S) URLs are accepted. Substrings and schemeless host
  /// names must stay on the local-path branch instead of reaching a launcher.
  static bool isValidUrl(String value) => parseHttpUrl(value) != null;

  static bool isHostUrl(String value) => parseHttpUrl(value) != null;

  /// 验证字符串是否为纯数字（端口号校验）
  static bool isNumericPort(String value) {
    return RegExp(r"^\d+$").hasMatch(value);
  }

  /// 请求写入应用沙箱之外目录所需的存储权限。
  ///
  /// Android 11+ 使用「所有文件访问权限」这一特殊权限；Android 10 及以下使用
  /// 传统的运行时存储权限。应用专属外部目录（`getDownloadsDirectory()`）不需要
  /// 任何权限，因此只有用户主动选择了公共目录时才会走到这里。
  ///
  /// 返回值表示调用结束时的授权状态；「所有文件访问权限」需要用户跳转系统设置
  /// 页面手动开启，返回 false 时调用方应再校验目标目录是否真的可写。
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        if (await Permission.manageExternalStorage.isGranted) return true;
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }
      if (await Permission.storage.isGranted) return true;
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (_) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
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

  static Future<bool> cleanupOwnedSharedMediaFile(File file, {Directory? temporaryDirectory}) async {
    final resolvedTemporaryDirectory = temporaryDirectory ?? await getTemporaryDirectory();
    final root = p.normalize(resolvedTemporaryDirectory.absolute.path);
    final filePath = p.normalize(file.absolute.path);
    if (!p.isWithin(root, filePath)) return false;

    final relativeParts = p.split(p.relative(filePath, from: root));
    if (relativeParts.length != 3 || relativeParts.first != 'share_handler') return false;

    final attachmentDirectory = file.parent;
    final stagingRoot = attachmentDirectory.parent;
    try {
      if (await file.exists()) await file.delete();
      if (await attachmentDirectory.exists() && (await attachmentDirectory.list().isEmpty)) {
        await attachmentDirectory.delete();
      }
      if (await stagingRoot.exists() && (await stagingRoot.list().isEmpty)) await stagingRoot.delete();
      return true;
    } catch (error) {
      debugPrint('Shared media temporary cleanup failed: $error');
      return false;
    }
  }

  static Future<bool> openFileOrUrl(String pathOrUrl) async {
    final trimmedPath = pathOrUrl.trim();
    if (trimmedPath.isEmpty) return false;

    final remoteUri = parseHttpUrl(trimmedPath);
    if (remoteUri != null) {
      try {
        if (await canLaunchUrl(remoteUri)) {
          return await launchUrl(remoteUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        return false;
      }
      return false;
    }

    final file = File(trimmedPath);
    final directory = Directory(trimmedPath);
    final isDir = await directory.exists();
    final isFile = await file.exists();

    if (!isDir && !isFile) return false;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        if (Platform.isWindows) {
          await Process.start('explorer.exe', [p.context.canonicalize(trimmedPath)], mode: ProcessStartMode.detached);
        } else if (Platform.isMacOS) {
          final result = await Process.run('open', [trimmedPath]);
          if (result.exitCode != 0) return false;
        } else if (Platform.isLinux) {
          final result = await Process.run('xdg-open', [trimmedPath]);
          if (result.exitCode != 0) return false;
        }
        return true;
      } catch (_) {}
    }

    if (Platform.isAndroid && isDir) {
      try {
        const externalStorage = '/storage/emulated/0/';

        if (!trimmedPath.startsWith(externalStorage)) {
          return false;
        }

        final relativePath = trimmedPath
            .substring(externalStorage.length)
            .replaceAll('\\', '/')
            .replaceAll(RegExp(r'^/+|/+$'), '');

        if (relativePath.isEmpty) {
          return false;
        }

        final documentId = 'primary:$relativePath';

        final contentUri = Uri.parse(
          'content://com.android.externalstorage.documents/document/'
          '${Uri.encodeComponent(documentId)}',
        );

        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: contentUri.toString(),
          type: 'vnd.android.document/directory',
        );

        // 精简模拟器镜像没有处理 vnd.android.document/directory 的文件管理器。
        // 未解析到任何界面时必须如实返回失败，否则界面会误报“已打开文件夹”。
        if (await intent.canResolveActivity() != true) {
          return false;
        }

        await intent.launch();
        return true;
      } catch (_) {}
    }

    try {
      final result = await OpenFilex.open(trimmedPath);
      return result.type == ResultType.done;
    } catch (_) {
      if (!Platform.isAndroid) {
        try {
          final String cleanPath = trimmedPath.startsWith('file://') ? trimmedPath : 'file://$trimmedPath';
          final Uri fileUri = Uri.parse(cleanPath);
          if (await canLaunchUrl(fileUri)) {
            return await launchUrl(fileUri);
          }
        } catch (_) {}
      }
    }

    return false;
  }

  /// Opens the system directory picker and lets the user choose a download directory.
  ///
  /// Returns:
  /// - A filesystem path on desktop platforms.
  /// - A platform-specific directory path or URI on Android.
  /// - `null` if the user cancels the picker or an error occurs.
  static Future<String?> pickDirectory() async {
    try {
      final result = await FilePicker.getDirectoryPath(dialogTitle: 'Select download directory');

      if (result == null || result.trim().isEmpty) {
        return null;
      }

      return result.trim();
    } catch (error) {
      debugPrint('Pick directory failed: $error');
      return null;
    }
  }
}
