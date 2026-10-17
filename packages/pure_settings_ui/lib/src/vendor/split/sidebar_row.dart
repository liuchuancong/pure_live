import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_data.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';

/// A row of a desktop sidebar: a tile in the list pane of a macOS, Windows
/// or GNOME style split view. Each style draws its own. Internal.
abstract class SidebarRow extends StatefulWidget {
  const SidebarRow(
    this.tile, {
    super.key,
    required this.selected,
    this.semanticsSelected,
  });

  /// The tile the row draws. Its descriptions, value and paddings are not
  /// shown.
  final SettingsTileData tile;
  final bool selected;

  /// Whether assistive technologies hear the row as selected: null for rows
  /// that don't open a page, and in GNOME's one-pane sidebar.
  final bool? semanticsSelected;
}

/// What the States of the sidebar rows share: the keyboard focus, the
/// activation and the row's line. Internal.
///
/// A click gives the row the focus, as `NSTableView`, `NavigationView` and
/// `GtkListBox` do, so the arrow keys and Tab go on from the clicked row.
/// Its focus ring stays hidden until a key is pressed (the rings are for
/// keyboard users), also when the focus comes back to the row, for
/// example after going back from the page it opened in one pane.
mixin SidebarRowState<T extends SidebarRow> on State<T> {
  SettingsTileData get tile => widget.tile;

  /// For the row's `FocusableActionDetector`.
  late final FocusNode focusNode = FocusNode(debugLabel: debugLabel);

  bool _focusHighlight = false;

  /// A click gave the row the focus, and no key was pressed since.
  bool _focusedByPointer = false;

  /// Enter and Space activate the row. For the row's
  /// `FocusableActionDetector`, with [focusNode].
  late final Map<Type, Action<Intent>> actions = tileActivateActions(
    activateRow,
  );

  /// Names the row's focus node.
  String get debugLabel;

  /// Does what a click on the row does, if it does anything now.
  void activateRow();

  /// Whether the row shows its focus ring.
  bool get showsFocusRing => _focusHighlight && !_focusedByPointer;

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// A click or a tap: the row takes the focus and activates.
  void handleTap() {
    _focusFromPointer();
    activateRow();
  }

  void _focusFromPointer() {
    if (!focusNode.canRequestFocus) return;
    if (!focusNode.hasPrimaryFocus) focusNode.requestFocus();
    if (_focusedByPointer) return;
    _focusedByPointer = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _rebuild();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _stopWaitingForKey();
    _rebuild();
    return false;
  }

  void _stopWaitingForKey() {
    if (!_focusedByPointer) return;
    _focusedByPointer = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  /// For the `onShowFocusHighlight` of the row's `FocusableActionDetector`.
  void handleFocusHighlight(bool value) {
    if (value != _focusHighlight) setState(() => _focusHighlight = value);
  }

  /// The row's line: [leading] (the icon, where the style puts it), the
  /// title on one line, then the trailing widget and [toggle] (the switch
  /// of a switch row), each in [endPadding].
  Row buildLine({
    required Widget? leading,
    required TextStyle titleStyle,
    EdgeInsetsGeometry? titlePadding,
    required TextStyle trailingStyle,
    required Color? trailingIconColor,
    required EdgeInsetsGeometry endPadding,
    required Widget? toggle,
  }) {
    final trailing = tile.trailing;
    final title = DefaultTextStyle(
      style: titleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: tile.title,
    );
    return Row(
      children: [
        ?leading,
        Expanded(
          child: titlePadding == null
              ? title
              : Padding(padding: titlePadding, child: title),
        ),
        if (trailing != null)
          Padding(
            padding: endPadding,
            child: IconTheme.merge(
              data: IconThemeData(color: trailingIconColor, size: 16),
              child: DefaultTextStyle(style: trailingStyle, child: trailing),
            ),
          ),
        if (toggle != null) Padding(padding: endPadding, child: toggle),
      ],
    );
  }

  @override
  void dispose() {
    _stopWaitingForKey();
    focusNode.dispose();
    super.dispose();
  }
}
