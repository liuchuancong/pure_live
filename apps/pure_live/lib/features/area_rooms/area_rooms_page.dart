import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart' show LiveAreaProvider, LivePageRequest, LiveRoom;
import 'package:live_uikit/styling.dart' show LiveButton, LiveEmpty;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The rooms of one area: the same infinite grid the popular feed uses,
/// loaded through the site's area capability.
final class AreaRoomsPage extends ConsumerStatefulWidget {
  /// Shows [areaId] of [siteId]; [areaName] titles the page.
  const AreaRoomsPage({required this.siteId, required this.areaId, required this.areaName, super.key});

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
  late final InfiniteController<LiveRoom> _controller = InfiniteController(loader: _load);
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onState);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onState)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onState(InfiniteState<LiveRoom> state) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) {
      unawaited(_controller.loadNext());
    }
  }

  Future<PageResult<LiveRoom>> _load(PageRequest request) {
    final capability = ref.read(areaProvider(widget.siteId));
    if (capability == null) {
      throw StateError('${widget.siteId} lost its area capability');
    }
    // The loader contract: errors throw, the controller keeps the shown
    // data and exposes the failure on its state.
    return capability
        .getAreaRooms(
          areaId: widget.areaId,
          request: LivePageRequest(page: request.page, pageSize: request.pageSize),
        )
        .then(
          (result) => result.fold(
            (error) => throw _FeedException(error),
            (page) => PageResult(items: page.items, totalCount: page.totalCount, hasMore: page.hasMore),
          ),
        );
  }

  static int _columns(BuildContext context) => switch (BreakpointsQualifier().qualify(context)) {
    ScreenSize.small => 2,
    ScreenSize.medium => 3,
    ScreenSize.large => 4,
  };

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    return Scaffold(
      appBar: AppBar(title: Text(widget.areaName.isEmpty ? widget.areaId : widget.areaName)),
      body: state.items.isEmpty ? _placeholder(context, state) : _grid(context, state),
    );
  }

  Widget _grid(BuildContext context, InfiniteState<LiveRoom> state) => CustomRefreshIndicator(
    onRefresh: _controller.refresh,
    builder: (context, child, indicator) => Stack(
      alignment: Alignment.topCenter,
      children: [
        child,
        Positioned(
          top: 12,
          child: Opacity(
            opacity: indicator.value.clamp(0, 1),
            child: IgnorePointer(child: CircularProgressIndicator(value: indicator.isLoading ? null : indicator.value)),
          ),
        ),
      ],
    ),
    child: GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns(context),
        childAspectRatio: 0.82,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) {
        if (index < state.items.length) {
          return RoomCard(
            room: state.items[index],
            onOpen: () => RoomRoute(
              siteId: state.items[index].ref.platform,
              roomId: state.items[index].ref.roomId,
              roomName: state.items[index].content.title,
            ).push<void>(context),
          );
        }
        return state.isLoadingMore ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
      },
    ),
  );

  Widget _placeholder(BuildContext context, InfiniteState<LiveRoom> state) {
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t.errors.network, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _controller.retry),
          ],
        ),
      );
    }
    if (state.isRefreshing || state.isUnloaded) {
      return Skeletonizer(
        child: GridView.count(
          crossAxisCount: _columns(context),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [
            for (var i = 0; i < _columns(context) * 3; i++)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(color: Colors.white24),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('XXXXXXXXXXXXXXXX'), SizedBox(height: 4), Text('XXXX')],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return LiveEmpty(title: context.t.common.empty);
  }
}

/// Wraps a site error for the loader contract; the controller stores it on
/// its state and the view renders the generic network copy over it.
final class _FeedException implements Exception {
  const _FeedException(this.cause);

  /// The site error behind the failure.
  final Object cause;

  @override
  String toString() => 'feed failed: $cause';
}
