import 'dart:developer';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/modules/search/search_list_controller.dart';

class SearchListView extends StatelessWidget {
  final String tag;

  const SearchListView(this.tag, {super.key});

  SearchListController get controller => Get.find<SearchListController>(tag: tag);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
        return Obx(
          () => EasyRefresh(
            controller: controller.easyRefreshController,
            onRefresh: controller.refreshData,
            onLoad: controller.loadData,
            child: controller.list.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.all(0),
                    physics: const BouncingScrollPhysics(),
                    controller: controller.scrollController,
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: controller.list.length,
                    itemBuilder: (context, index) {
                      final room = controller.list[index];
                      return OwnerCard(room: room);
                    },
                  )
                : EmptyView(
                    icon: Icons.live_tv_rounded,
                    title: S.of(context).empty_search_title,
                    subtitle: S.of(context).empty_search_subtitle,
                  ),
          ),
        );
      },
    );
  }
}

class OwnerCard extends StatefulWidget {
  const OwnerCard({super.key, required this.room});

  final LiveRoom room;

  @override
  State<OwnerCard> createState() => _OwnerCardState();
}

class _OwnerCardState extends State<OwnerCard> {
  SettingsService settings = Get.find<SettingsService>();

  Future<String?> getFinalUrl(String requestUrl) async {
    try {
      final url = Uri.parse(requestUrl);
      final client = http.Client();
      log("requestUrl: $requestUrl");
      // 1. 发送请求
      final request = http.Request('GET', url)..followRedirects = false;
      final response = await client.send(request);
      log("Status Code: ${response.statusCode}");
      // 2. 获取重定向地址
      final redirectUrl = response.headers['location'];
      log("roomId is 0, skip $redirectUrl");
      if (redirectUrl == null || redirectUrl.isEmpty) {
        return null;
      }
      final segments = Uri.parse(redirectUrl).pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }

      return null;
    } catch (e) {
      log("Error occurred: $e");
      return null;
    }
  }

  void _onTap(BuildContext context) async {
    String roomId = widget.room.roomId!;
    if (widget.room.platform == Sites.huyaSite) {
      if (widget.room.roomId == '0') {
        var roomIdInfo = await getFinalUrl('https://www.huya.com/yy/${widget.room.userId!}');
        if (roomIdInfo != null) {
          roomId = roomIdInfo;
        }
      }
    }
    AppNavigator.toLiveRoomDetail(liveRoom: widget.room.copyWith(roomId: roomId));
  }

  late bool isFavorite = settings.isFavorite(widget.room);

  ImageProvider? getRoomAvatar(String avatar) {
    try {
      return CachedNetworkImageProvider(
        avatar,
        errorListener: (err) {
          log("CachedNetworkImageProvider: Image failed to load!");
        },
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => _onTap(context),
        leading: CircleAvatar(
          foregroundImage: widget.room.avatar!.isNotEmpty ? getRoomAvatar(widget.room.avatar!) : null,
          radius: 20,
          backgroundColor: Theme.of(context).disabledColor,
        ),
        title: Text(
          widget.room.title != null ? '${widget.room.title}' : '',
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.nick!, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              widget.room.area!.isEmpty
                  ? "${widget.room.platform?.toUpperCase()}"
                  : "${widget.room.platform?.toUpperCase()} - ${widget.room.area}",
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: FilledButton.tonal(
          onPressed: () {
            setState(() => isFavorite = !isFavorite);
            if (isFavorite) {
              settings.addRoom(widget.room);
            } else {
              settings.removeRoom(widget.room);
            }
          },
          style: isFavorite ? null : FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface),
          child: Text(isFavorite ? S.of(context).unfollow : S.of(context).follow),
        ),
      ),
    );
  }
}
