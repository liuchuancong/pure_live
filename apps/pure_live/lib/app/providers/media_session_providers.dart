import 'package:media_core_mediasession/media_core_mediasession.dart';

/// Arms the OS playback surfaces (Windows SMTC, Android's notification,
/// macOS/Linux controls) over the app's kernel. Idempotent; the boot path
/// calls it after the engine prime and before any room exists — a failure
/// here only costs the surfaces, never the app.
Future<void> enableMediaSession() async {
  await MediaSessionBootstrap.enable();
}
