import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/shared/enums/app_module.dart' show AppModule;

/// Owns which module (live, IPTV, video on demand, music) the shell shows.
///
/// The window, its chrome and the router stay; the sidebar's destinations
/// and the mobile bottom bar follow the module. Persistence rides with the
/// settings store once the app wires it; the in-memory default is live.
final class SelectedModuleController extends Notifier<AppModule> {
  @override
  AppModule build() => AppModule.live;

  /// The module the shell is showing.
  AppModule get selected => state;

  /// Moves the shell to [module].
  set selected(AppModule module) => state = module;
}

/// The module the shell is showing.
final selectedModuleProvider = NotifierProvider<SelectedModuleController, AppModule>(SelectedModuleController.new);
