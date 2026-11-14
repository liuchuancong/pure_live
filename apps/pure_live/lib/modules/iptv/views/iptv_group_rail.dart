import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_iptv/live_iptv.dart' show iptvUngroupedKey;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/views/iptv_panels.dart' show iptvNumber;
import 'package:pure_live/shared/widgets/app_panel.dart';

/// What one of the module's channel surfaces holds open: the library's
/// visible groups in the library's own display order, how many channels each
/// of them holds, how many the whole walk holds, and which group is open
/// (null for every group at once).
///
/// A record of its own because the module has two surfaces that browse by
/// group — the channel page (whose state the channels controller mirrors) and
/// the guide page (which holds the choice itself) — and the group rows have to
/// name, count and mark the same groups wherever they stand. The wider state
/// record the channels page keeps satisfies this one as it is.
typedef IptvGroupFilter = ({List<String> groups, Map<String, int> groupCounts, int totalCount, String? selectedGroup});

/// The width of the module's group column. On the channel page the table beside
/// it keeps its own minimums (200 + 200 flexed over the fixed 120/72/64), and
/// 960 is where that page is allowed to pay for both panes; the guide page,
/// which also carries a picker pane of its own, waits for a wider window.
const double kIptvGroupRailWidth = 200;

/// The height of a group row — the module's list measure, the one its zapping
/// panel already rows to.
const double kIptvGroupRowExtent = 48;

/// The group's own name, or the interface's name for the channels no playlist
/// grouped — the key for those is the empty string the package leaves to the
/// interface to word.
String iptvGroupLabel(Translations t, String group) => group.isEmpty ? t.iptv.ungrouped : group;

/// The groups a screen lists: the order it was given, with the catch-all bucket
/// moved to the end.
///
/// Channels that name no group are not a group the playlist's author arranged —
/// the package gives them the empty key and leaves the position to whoever
/// draws the list, and the rank they get by default is wherever the first such
/// line happens to sit in the file. An item with no rank belongs at the bottom,
/// not between 央视 and 卫视: Fire TV's own rule for a channel with no `SortRank`
/// is that it lands last, and alist-tvbox puts a site with no `order` at 9000,
/// 排在最后. Every surface that offers the group dimension walks this one list,
/// so the bucket is in one place no matter which pane the viewer is in.
List<String> iptvGroupsListed(Iterable<String> names) => [
  for (final name in names)
    if (name.isNotEmpty) name,
  if (names.any((name) => name.isEmpty)) iptvUngroupedKey,
];

/// The library's groups down a first column: every channel first, then one row
/// per visible group, each with how many channels it holds. A vertical column
/// is what a real playlist needs — 100 groups is a list to scroll, not a strip
/// to hunt along — and it is the reference's first pane, on the guide surface
/// as much as on the channel one.
final class IptvGroupsColumn extends StatelessWidget {
  const IptvGroupsColumn({required this.filter, required this.onSelect, super.key});

  /// The groups the surface holds, with the open one.
  final IptvGroupFilter filter;

  /// Opens a group; null takes every channel at once.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      width: kIptvGroupRailWidth,
      child: DsCard(
        style: const DsCardStyle(
          padding: EdgeInsets.only(top: DsSpace.s8, bottom: DsSpace.s6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s4,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12),
              child: Text(
                t.iptv.groupsLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.overline.copyWith(color: colors.textSubtle),
              ),
            ),
            Expanded(
              child: IptvGroupList(filter: filter, onSelect: onSelect),
            ),
          ],
        ),
      ),
    );
  }
}

/// The same groups for a window that has no room for the column: one line
/// naming the open group, which opens the list in a panel. Where a scrolling
/// tab strip would take a row per group, this takes a row per page — however
/// many groups the playlist carries.
final class IptvGroupEntry extends StatelessWidget {
  const IptvGroupEntry({required this.filter, required this.onSelect, super.key});

  /// The groups the surface holds, with the open one.
  final IptvGroupFilter filter;

  /// Opens a group; null takes every channel at once.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final group = filter.selectedGroup;
    // widthFactor 1 keeps the line the button's own width: as a stretch
    // column's line it still sits at the start of the full row, but it can
    // also stand in a head's action row without claiming the whole window.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: const DsIcon(DsIcons.folder, size: 14),
          semanticLabel: t.iptv.groupsLabel,
          onPressed: () => unawaited(
            showAppPanel<void>(
              context: context,
              builder: (context) => IptvGroupPickerPanel(
                filter: filter,
                onSelect: (group) {
                  onSelect(group);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          // The open group is the news this line carries; the category's own
          // name only shows while the whole library is open.
          child: Text(
            group == null ? t.iptv.zapperGroups : iptvGroupLabel(t, group),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// The panel the compact and medium windows open over their channel list.
final class IptvGroupPickerPanel extends StatelessWidget {
  const IptvGroupPickerPanel({required this.filter, required this.onSelect, super.key});

  /// The groups the surface holds, with the open one.
  final IptvGroupFilter filter;

  /// Opens a group; null takes every channel at once.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AppPanel(
      title: Text(t.iptv.groupsLabel),
      // The list scrolls itself; the panel should not wrap it in a second
      // scroll that never gets a bounded height to measure against.
      scrollable: false,
      child: IptvGroupList(filter: filter, onSelect: onSelect),
    );
  }
}

/// The group rows, shared by the column and the panel so the two forms name,
/// count and choose the same groups: every channel first, then the visible
/// groups in the library's own display order.
final class IptvGroupList extends StatelessWidget {
  const IptvGroupList({required this.filter, required this.onSelect, super.key});

  /// The groups the surface holds, with the open one.
  final IptvGroupFilter filter;

  /// Opens a group; null takes every channel at once.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    // Listed through one rule wherever the rows stand: the column, the panel
    // and the picker all order the same groups the same way, so the catch-all
    // bucket is in one place across the module's three group surfaces.
    final groups = iptvGroupsListed(filter.groups);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      itemExtent: kIptvGroupRowExtent,
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        final group = index == 0 ? null : groups[index - 1];
        final selected = filter.selectedGroup == group;
        return DsListRow(
          semanticLabel: group == null ? t.iptv.tabAll : iptvGroupLabel(t, group),
          title: Text(
            group == null ? t.iptv.tabAll : iptvGroupLabel(t, group),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          detail: Text(
            iptvNumber(group == null ? filter.totalCount : (filter.groupCounts[group] ?? 0)),
            style: theme.typography.numeric(theme.typography.small),
          ),
          selected: selected,
          style: const DsListRowStyle(height: kIptvGroupRowExtent),
          onPressed: () => onSelect(group),
        );
      },
    );
  }
}
