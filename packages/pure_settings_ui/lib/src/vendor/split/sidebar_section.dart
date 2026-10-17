import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_semantics.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// A group of a desktop sidebar (macOS, Windows or GNOME style): its rows,
/// under a header when it has a title. Each style draws its own header
/// ([buildHeader]). Internal.
abstract class SidebarSection extends StatelessWidget {
  const SidebarSection({
    super.key,
    required this.title,
    required this.tiles,
    this.titlePadding,
  });

  final Widget? title;
  final List<Widget> tiles;
  final EdgeInsetsGeometry? titlePadding;

  /// The header of [title] in the style, or null when it shows none.
  @protected
  Widget? buildHeader(
    BuildContext context,
    SettingsThemeData theme,
    Widget title,
  );

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final title = this.title;
    final header = title == null ? null : buildHeader(context, theme, title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Semantics(container: true, header: true, child: header),
        for (final tile in tiles) tileSemanticsNode(tile),
      ],
    );
  }
}
