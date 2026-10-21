import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:pure_live/app/app_providers.dart' show sitesProvider;
import 'package:pure_live/features/discovery/area_rooms_view.dart';
import 'package:pure_live/features/discovery/follow_area_button.dart';
import 'package:pure_live/features/settings/widgets/settings_entry_button.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The rooms of one area as a route (3.x `AreaRoomsPage`): a scaffold over
/// the shared `AreaRoomsView` — the view owns both feed models and the sort;
/// the page owns the chrome, with the sort control in its app bar.
final class AreaRoomsPage extends ConsumerStatefulWidget {
  /// Shows [areaId] of [siteId]; [areaName] titles the page.
  const new({required this.siteId, required this.areaId, required this.areaName, super.key});

  /// The platform the area belongs to.
  final String siteId;

  /// The area's id.
  final String areaId;

  /// The area's display name.
  final String areaName;

  @override
  ConsumerState<AreaRoomsPage> createState() => _AreaRoomsPageState();
}

final class _AreaRoomsPageState extends ConsumerState<AreaRoomsPage> {
  /// How the loaded rooms are ordered.
  RoomSort _sort = RoomSort.platform;

  Widget _appBar(BuildContext context) {
    final theme = PureTheme.of(context);
    final site = ref.watch(sitesProvider).registry.getById(widget.siteId);
    final platform =
        site?.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN') ?? widget.siteId;
    return PureAppBar(
      title: widget.areaName.isEmpty ? widget.areaId : widget.areaName,
      // The reference's c2: the area's name with "platform · category"
      // under it, kept inside the shortest bar.
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.areaName.isEmpty ? widget.areaId : widget.areaName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.text.body.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            platform,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
          ),
        ],
      ),
      actions: [
        FollowAreaButton(
          area: LiveArea.normalized(platform: widget.siteId, areaId: widget.areaId, areaName: widget.areaName),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: PureSegmented(
              labels: [context.t.room.sortPlatform, context.t.room.sortViewers],
              index: _sort.index,
              onChanged: (value) => setState(() => _sort = RoomSort.values[value]),
            ),
          ),
        ),
        const SettingsEntryButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PureScaffold(
      appBar: _appBar(context),
      body: AreaRoomsView(
        key: ValueKey('${widget.siteId}:${widget.areaId}'),
        siteId: widget.siteId,
        areaId: widget.areaId,
        areaName: widget.areaName,
        sort: _sort,
      ),
    );
  }
}
