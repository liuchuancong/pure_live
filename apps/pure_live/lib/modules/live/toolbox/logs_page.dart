import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/modules/live/toolbox/toolbox_page.dart' show LogsPane;
import 'package:pure_live/shared/shared.dart' show LiveWindow;

/// The log console as the rail's own page: the records the running app wrote,
/// the level, the filter, the file path and the export — filling the window
/// under the shell's chrome. The console itself is [LogsPane]; this page only
/// gives it the shell's insets.
final class LogsPage extends StatelessWidget {
  /// The log console page.
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s24, inset, DsSpace.s24),
      child: const LogsPane(),
    );
  }
}
