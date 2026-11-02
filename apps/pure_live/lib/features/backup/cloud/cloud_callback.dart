import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform, Process;

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/features/backup/cloud/cloud_controller.dart';
import 'package:pure_live/features/backup/cloud/cloud_service.dart';

/// The GitHub token out of what the middle page handed back: the full
/// `purelive://auth?credential=<url-encoded JSON>` link, the bare encoded
/// JSON, or the JSON itself. Null when none of those.
///
/// The link is what a browser redirect delivers and what a user pastes
/// from the page when the redirect never reached the app; accepting the
/// looser forms costs nothing and saves a retry.
String? gitHubTokenFromCallback(String text) {
  var raw = text.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.scheme == CloudService.callbackScheme) {
    if (uri.host != 'auth') return null;
    raw = uri.queryParameters['credential'] ?? '';
  } else if (!raw.startsWith('{')) {
    raw = Uri.decodeComponent(raw);
  }
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final token = decoded['accessToken'];
    return token is String && token.isNotEmpty ? token : null;
  } on Object {
    return null;
  }
}

/// Registers `purelive://` for this executable in the user's registry so a
/// browser redirect reaches the app (HKCU only: no elevation). Idempotent;
/// a failure is logged and the paste fallback still works.
Future<void> registerWindowsCallbackScheme() async {
  if (!Platform.isWindows) return;
  final log = appLog.forCategory('backup.cloud');
  final exe = Platform.resolvedExecutable;
  const base = r'HKCU\Software\Classes\purelive';
  try {
    await Process.run('reg', ['add', base, '/ve', '/d', 'PureLive Authentication Callback', '/f']);
    await Process.run('reg', ['add', base, '/v', 'URL Protocol', '/d', '', '/f']);
    await Process.run('reg', ['add', '$base\\shell\\open\\command', '/ve', '/d', '"$exe" "%1"', '/f']);
  } on Object catch (error) {
    log.warning('the purelive:// scheme could not be registered', fields: {'error': '$error'});
  }
}

/// Listens for the `purelive://auth` link a GitHub sign-in redirects to and
/// hands its token to the cloud controller. Started once per primary
/// window, beside the music deep-link binding.
final class CloudCallbackBinding {
  /// The binding.
  CloudCallbackBinding(this._ref);

  final Ref _ref;
  StreamSubscription<Uri>? _links;

  /// Starts listening; a second call is a no-op.
  void start() {
    _links ??= AppLinks().uriLinkStream.listen(
      _handle,
      onError: (Object error) {
        appLog.forCategory('backup.cloud').warning('the link stream failed', fields: {'error': '$error'});
      },
    );
  }

  Future<void> _handle(Uri link) async {
    if (link.scheme != CloudService.callbackScheme) return;
    final token = gitHubTokenFromCallback(link.toString());
    if (token == null) {
      appLog.forCategory('backup.cloud').warning('the callback link carried no token');
      return;
    }
    await _ref.read(cloudControllerProvider.notifier).signInWithGitHubToken(token);
  }

  /// Stops listening.
  void dispose() {
    unawaited(_links?.cancel());
    _links = null;
  }
}

/// The callback binding.
final cloudCallbackBindingProvider = Provider<CloudCallbackBinding>((ref) {
  final binding = CloudCallbackBinding(ref);
  ref.onDispose(binding.dispose);
  return binding;
});
