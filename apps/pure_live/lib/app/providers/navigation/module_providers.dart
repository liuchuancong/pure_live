import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/shared.dart';

/// Owns which module (live, IPTV, video on demand, music) the shell shows.
///
/// The window, its chrome and the router stay; the sidebar's destinations
/// and the mobile bottom bar follow the module. The choice persists under
/// `browse.module` in the settings store; the default is live.
final class SelectedModuleController extends Notifier<AppModule> {
  @override
  AppModule build() {
    final stored = _readStoredModule();
    for (final module in AppModule.values) {
      if (module.name == stored) return module;
    }
    return AppModule.live;
  }

  /// The stored module's name, or null when storage never opened (its
  /// boot failure is logged); live is then the default.
  static String? _readStoredModule() {
    try {
      return StoragePrefs.getString('browse.module');
    } on Object {
      return null;
    }
  }

  /// The module the shell is showing.
  AppModule get selected => state;

  /// Moves the shell to [module], writing the choice through.
  set selected(AppModule module) {
    state = module;
    unawaited(StoragePrefs.setString('browse.module', module.name));
  }
}

/// The module the shell is showing.
final selectedModuleProvider = NotifierProvider<SelectedModuleController, AppModule>(SelectedModuleController.new);
