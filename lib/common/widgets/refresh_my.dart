import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:pure_live/modules/util/listen_list_util.dart';

import '../../modules/live_play/widgets/slide_animation.dart';
import '../base/base_controller.dart';
import '../l10n/generated/l10n.dart';
import 'empty_view.dart';
import 'grid_util.dart';
import 'refresh_grid_util.dart';
import 'room_card.dart';
import 'status/app_loadding_widget.dart';

class RefreshMy extends StatefulWidget {
  final BasePageController pageController;
  final IndexedWidgetBuilder? itemBuilder;

  const RefreshMy({super.key, required this.pageController, this.itemBuilder});

  @override
  State<RefreshMy> createState() => _RefreshMyState();
}

class _RefreshMyState extends State<RefreshMy> with AutomaticKeepAliveClientMixin {
  late ScrollController scrollController;

  @override
  bool get wantKeepAlive => true;

  void onListenerPosition() {
    // CoreLog.d("onListenerPosition: ${scrollController.position}");
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
      if (widget.pageController.canLoadMore.isTrue) {
        EasyThrottle.throttle('scroll-refresh-throttler', const Duration(milliseconds: 200), () {
          widget.pageController.loadData();
        });
      }
    }
    final ScrollDirection direction = scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.forward) {
    } else if (direction == ScrollDirection.reverse) {}
  }

  var streamSubscriptionListenList = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    scrollController = widget.pageController.scrollController;

    scrollController.addListener(onListenerPosition);
    initScrollController();
  }

  void initScrollController() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        onListenerPosition();
        return;
      }
      initScrollController();
    });
  }

  @override
  void dispose() {
    scrollController.removeListener(onListenerPosition);
    ListenListUtil.clearStreamSubscriptionList(streamSubscriptionListenList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var itemBuilder = widget.itemBuilder ??
        (context, index) => FrameSeparateWidget(index: index, placeHolder: const SizedBox(width: 220.0, height: 200), child: SlideTansWidget(child: RoomCard(room: widget.pageController.list[index], dense: true)));

    return LayoutBuilder(builder: (context, constraint) {
      final crossAxisCount = RefreshGridUtil.getCrossAxisCount(constraint);
      return RefreshIndicator(
          displacement: 10.0,
          edgeOffset: 10.0,
          onRefresh: () async {
            await widget.pageController.refreshData();
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: Stack(children: [
            StreamBuilder(
                initialData: [],
                stream: widget.pageController.list.stream,
                builder: (s, d) {
                  if (widget.pageController.list.isEmpty) {
                    return EmptyView(
                      icon: Icons.live_tv_rounded,
                      title: S.current.empty_live_title,
                      subtitle: S.current.empty_live_subtitle,
                      boxConstraints: constraint,
                    );
                  }
                  return CustomScrollView(
                    cacheExtent: 30,
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                          sliver: GradUtil.contentGrid(
                            /// 缓存数目， 减少卡顿
                            cacheExtent: 30,

                            padding: const EdgeInsets.all(5),
                            controller: widget.pageController.scrollController,
                            crossAxisCount: crossAxisCount,
                            itemCount: widget.pageController.list.length,
                            itemBuilder: itemBuilder,
                          )),
                    ],
                  );
                }),
            StreamBuilder(
                initialData: false,
                stream: widget.pageController.loadding.stream,
                builder: (s, d) {
                  return Visibility(
                    visible: (widget.pageController.loadding.value),
                    child: const AppLoaddingWidget(),
                  );
                }),
          ]));
    });
  }
}
