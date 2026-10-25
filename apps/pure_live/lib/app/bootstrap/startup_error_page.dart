import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The screen a failed boot shows instead of the app.
///
/// The widget tree is not up — no theme, no router, no translations — so
/// this renders a bare `DsScope` carrying the failing task's name, which
/// is what a bug report needs first.
final class StartupErrorPage extends StatelessWidget {
  /// An error screen for the [error] the bootstrap raised.
  const StartupErrorPage({required this.error, super.key});

  /// The start-up failure to show.
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // The app's own Directionality lives under the router, which never
      // mounted; the error page must still be able to draw text.
      textDirection: TextDirection.ltr,
      child: DsScope(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('启动失败:$error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
