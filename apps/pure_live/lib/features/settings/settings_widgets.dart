import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A setting row with its control in the row on a wide pane, and under the
/// label on a narrow one — desen_ui's form rhythm without copying a
/// desktop layout onto a phone. Shared by the app-wide sections and the
/// module-specific panes (IPTV, the Bilibili station), so every settings
/// surface answers a narrow window the same way.
final class SettingsConfigRow extends StatelessWidget {
  /// A row for [title] with [control] at its end.
  const SettingsConfigRow({
    required this.title,
    required this.control,
    this.description,
    this.leading,
    this.detail,
    this.controlWidth = 200,
    super.key,
  });

  /// The row's name.
  final String title;

  /// One line under the name.
  final String? description;

  /// A leading glyph.
  final Widget? leading;

  /// A value printed before the control, e.g. "250 px".
  final Widget? detail;

  /// The control itself.
  final Widget control;

  /// The control's width in the wide layout.
  final double controlWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final row = DsListRow(
          leading: leading,
          title: Text(title),
          description: description == null ? null : Text(description!),
          detail: detail,
          trailing: wide ? SizedBox(width: controlWidth, child: control) : null,
        );
        if (wide) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            Padding(padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12), child: control),
          ],
        );
      },
    );
  }
}
