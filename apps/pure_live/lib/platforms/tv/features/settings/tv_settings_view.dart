import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/features/settings/settings_model.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// 设置 on the ten-foot screen: every settings page as a focus tile, grouped
/// under the five areas the phone overview uses, with the same titles and
/// descriptions.
///
/// A tile either pushes another route of the app (IPTV, backup) or opens the
/// page's own body as a full-screen page above this hub — the page keeps its
/// own chrome, so a TV viewer changes one setting and comes back. The hub
/// itself is a wall, not a split: a remote reads a grid faster than a column.
final class TvSettingsView extends ConsumerWidget {
  /// The TV settings hub.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return SafeArea(
      child: FocusTraversalGroup(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1600 ? 4 : 3;
            const areas = SettingsArea.values;
            return ListView(
              padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
              children: [
                Text(t.tabs.settings, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(height: 16),
                for (final area in areas) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      area.titleOf(t),
                      style: theme.text.body.copyWith(color: theme.colors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 3.6,
                    children: [
                      for (final section in SettingsSection.values)
                        if (section.area == area)
                          _TvSectionTile(
                            key: ValueKey('tv-settings-${section.name}'),
                            section: section,
                            title: settingsSectionTitle(t, section),
                            description: settingsSectionDescription(t, section),
                            first: section == SettingsSection.values.firstWhere((candidate) => candidate.area == area),
                            onTap: () => _open(context, section),
                          ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Opens [section]: another route when it has one, else its own page above
  /// the hub.
  static void _open(BuildContext context, SettingsSection section) {
    if (section.route case final route?) {
      unawaited(context.push<void>(route));
      return;
    }
    final page = section.buildPage();
    if (page == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

/// One focusable settings tile: icon, title and description, an accent ring
/// on focus.
final class _TvSectionTile extends StatefulWidget {
  const new({
    required this.section,
    required this.title,
    required this.description,
    required this.onTap,
    this.first = false,
    super.key,
  });

  final SettingsSection section;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool first;

  @override
  State<_TvSectionTile> createState() => _TvSectionTileState();
}

final class _TvSectionTileState extends State<_TvSectionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Focus(
      autofocus: widget.first,
      onFocusChange: (value) {
        if (value != _focused) {
          setState(() => _focused = value);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colors.fillQuaternary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _focused ? theme.colors.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(widget.section.icon, color: _focused ? theme.colors.primary : theme.colors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.body.copyWith(
                        color: _focused ? theme.colors.primary : theme.colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.section.route != null)
                Icon(Icons.open_in_new, size: 16, color: theme.colors.textTertiary)
              else
                Icon(Icons.chevron_right_rounded, size: 18, color: theme.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
