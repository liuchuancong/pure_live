import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_device/live_device.dart'
    show PlatformStartupService, StartupCapabilities, StartupException, StartupService;

/// The login-entry state the General pane shows.
final class StartupState {
  /// Creates a state.
  const StartupState({this.supported = false, this.enabled = false, this.loading = true, this.error = ''});

  /// Whether this platform has an auto-start entry to read or change.
  final bool supported;

  /// Whether this build is currently registered to start at login.
  final bool enabled;

  /// A read/write is in flight.
  final bool loading;

  /// The last failure, for the row; empty when none.
  final String error;

  /// A copy with selected fields replaced.
  StartupState copyWith({bool? supported, bool? enabled, bool? loading, String? error}) => StartupState(
    supported: supported ?? this.supported,
    enabled: enabled ?? this.enabled,
    loading: loading ?? this.loading,
    error: error ?? this.error,
  );
}

/// Owns the Windows login-entry setting.
///
/// The operating system's registration is the source of truth, not a stored
/// boolean: the row reads the Run key, so an entry removed outside the app
/// shows as off and an entry from an earlier install is compared by target.
/// Other platforms report [StartupCapabilities.supported] false and the pane
/// hides the row.
final class StartupController extends Notifier<StartupState> {
  static const StartupService _service = PlatformStartupService();

  @override
  StartupState build() {
    final capabilities = _service.capabilities;
    if (!capabilities.supported) {
      return const StartupState(loading: false);
    }
    unawaited(_read());
    return const StartupState(supported: true);
  }

  Future<void> _read() async {
    try {
      final enabled = await _service.isEnabled().timeout(const Duration(seconds: 6));
      if (!ref.mounted) return;
      state = state.copyWith(supported: true, enabled: enabled, loading: false, error: '');
    } on StartupException catch (error) {
      debugPrint('startup read failed: ${error.message} cause=${error.cause}');
      if (!ref.mounted) return;
      state = state.copyWith(supported: true, loading: false, error: error.message);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(supported: true, loading: false, error: '$error');
    }
  }

  /// Registers or removes the login entry, then reads the result back so the
  /// switch reflects the OS rather than the request.
  Future<void> setEnabled({required bool value}) async {
    if (!state.supported || state.loading) return;
    state = state.copyWith(loading: true, error: '');
    try {
      await _service.setEnabled(enabled: value).timeout(const Duration(seconds: 8));
      await _read();
    } on StartupException catch (error) {
      debugPrint('startup write failed: ${error.message} cause=${error.cause}');
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.message);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: '$error');
    }
  }
}

/// The login-entry setting.
final startupProvider = NotifierProvider<StartupController, StartupState>(StartupController.new);
