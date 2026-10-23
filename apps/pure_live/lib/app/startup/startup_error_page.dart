import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The screen a failed boot shows instead of the app.
///
/// The widget tree is not up — no theme, no router, no translations — so
/// this renders a bare `DsScope` with the failing task's name, which is
/// what a bug report needs first.
final class StartupErrorPage extends StatelessWidget {
  /// An error screen for the [error] the coordinator raised.
  const new({required this.error, super.key});

  /// The startup failure to show.
  final Object error;

  @override
  Widget build(BuildContext context) {
    return DsScope(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('启动失败:$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
