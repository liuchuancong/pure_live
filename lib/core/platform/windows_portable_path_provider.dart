import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

/// Keeps package/plugin state beside the Windows executable instead of
/// scattering cache databases and temporary files through the system drive.
///
/// Downloads remain the user's normal Downloads directory because they are
/// exported documents rather than private application state.
class WindowsPortablePathProvider extends PathProviderPlatform {
  WindowsPortablePathProvider({required this.delegate, required this.dataRoot});

  final PathProviderPlatform delegate;
  final String dataRoot;

  Future<String> _localDirectory(String name) async {
    final directory = Directory(p.join(dataRoot, name));
    await directory.create(recursive: true);
    return directory.path;
  }

  @override
  Future<String?> getTemporaryPath() => _localDirectory('TEMP');

  @override
  Future<String?> getApplicationSupportPath() => _localDirectory('PLUGIN_SUPPORT');

  @override
  Future<String?> getLibraryPath() => _localDirectory('LIBRARY');

  @override
  Future<String?> getApplicationDocumentsPath() => _localDirectory('DOCUMENTS');

  @override
  Future<String?> getApplicationCachePath() => _localDirectory('CACHE');

  @override
  Future<String?> getExternalStoragePath() => delegate.getExternalStoragePath();

  @override
  Future<List<String>?> getExternalCachePaths() => delegate.getExternalCachePaths();

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      delegate.getExternalStoragePaths(type: type);

  @override
  Future<String?> getDownloadsPath() => delegate.getDownloadsPath();
}

/// The Windows shared_preferences plugin constructs PathProviderWindows
/// directly instead of using PathProviderPlatform.instance. Register fresh
/// stores with a local support-path provider before EasyLocalization reads its
/// saved locale.
void configureWindowsPortableSharedPreferences(String dataRoot) {
  final pathProvider = _PortablePathProviderWindows(dataRoot);
  final legacyStore = SharedPreferencesWindows();
  // ignore: invalid_use_of_visible_for_testing_member
  legacyStore.pathProvider = pathProvider;
  SharedPreferencesStorePlatform.instance = legacyStore;

  final asyncStore = SharedPreferencesAsyncWindows();
  // ignore: invalid_use_of_visible_for_testing_member
  asyncStore.pathProvider = pathProvider;
  SharedPreferencesAsyncPlatform.instance = asyncStore;
}

class _PortablePathProviderWindows extends PathProviderWindows {
  _PortablePathProviderWindows(this.dataRoot);

  final String dataRoot;

  @override
  Future<String?> getApplicationSupportPath() async {
    final directory = Directory(p.join(dataRoot, 'PLUGIN_SUPPORT'));
    await directory.create(recursive: true);
    return directory.path;
  }
}
