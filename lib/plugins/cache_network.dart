import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:pure_live/core/common/core_log.dart';

class CacheNetWorkUtils {
  // static Widget getCacheImage(String imageUrl,
  //     {double radius = 0.0, required Widget errorWidget, bool full = false}) {
  //   return imageUrl.isNotEmpty
  //       ? CachedNetworkImage(
  //           imageUrl: imageUrl,
  //           cacheManager: CustomCacheManager.instance,
  //           placeholder: (context, url) => const CircularProgressIndicator(
  //                 color: Colors.white,
  //               ),
  //           errorWidget: (context, error, stackTrace) => errorWidget,
  //           imageBuilder: (context, image) => full == false
  //               ? CircleAvatar(
  //                   foregroundImage: image,
  //                   radius: radius,
  //                   backgroundColor: Theme.of(context).disabledColor,
  //                 )
  //               : Image(image: image))
  //       : errorWidget;
  // }

  /// 图片缓存
  static ImageProvider? getNetworkImageProvider(String? avatar) {
    try {
      if (avatar == null || avatar == "") {
        return null;
      }
      return ExtendedNetworkImageProvider(
        proxyImageUrl(avatar),
        cache: true,
        retries: 3,
        timeLimit: const Duration(milliseconds: 5000),
        timeRetry: const Duration(milliseconds: 100),
        cacheMaxAge: const Duration(days: 3),
        // cacheManager: CustomCacheManager.instance, errorListener: (err) {
        // log(err.toString());
        // CoreLog.e("", (err as Error).stackTrace!);
        // log("CachedNetworkImageProvider: Image failed to load!");
        // CoreLog.error(err);
      );
    } catch (e) {
      CoreLog.error(e);
      return null;
    }
  }

  /// 圆形头像
  static CircleAvatar getCircleAvatar2(
    String? avatar, {
    double radius = 17,
  }) {
    return CircleAvatar(
      foregroundImage: avatar != null && avatar.isNotEmpty ? CacheNetWorkUtils.getNetworkImageProvider(avatar) : null,
      radius: radius,
      backgroundColor: Theme.of(Get.context!).disabledColor,
    );
  }

  /// 圆形头像
  static Widget getCircleAvatar(
    String? avatar, {
    double radius = 17,
  }) {
    if (avatar == null) {
      return Container();
    }
    return CircleAvatar(radius: radius, child: getCacheImageV2(avatar, radius: radius, fit: BoxFit.fitWidth, shape: BoxShape.circle, cacheWidth: 60, cacheHeight: 60));
  }

  static Widget getCacheImageV2(
    String? imageUrl, {
    double radius = 0.0,
    bool full = false,
    BoxFit fit = BoxFit.fitWidth,
    BoxShape? shape,
    int? cacheWidth = 300, // 16 : 9
    int? cacheHeight = 169,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox(
        // key: ValueKey("getCacheImageV2_outlined"),
        child: Icon(
          Icons.image_not_supported_outlined,
        ),
      );
    }
    return ExtendedImage.network(
      // key: ValueKey(imageUrl),
      proxyImageUrl(imageUrl, width: cacheWidth, height: cacheHeight),
      cache: true,
      fit: fit,
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      shape: shape,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      width: cacheWidth?.toDouble(),
      height: cacheWidth?.toDouble(),
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            // return ExtendedImage.asset(
            //   clearMemoryCacheWhenDispose: true,
            //   "assets/images/loading.gif",
            //   fit: BoxFit.fitWidth,
            // );
            return Container(color: Colors.grey,);
            return LoadingIndicator(
              indicatorType: Indicator.ballPulse,

              /// 必须, loading的类型
              // colors: const [Colors.white],       /// 可选, 颜色集合
              // strokeWidth: 2,                     /// 可选, 线条宽度，只对含有线条的组件有效
              // backgroundColor: Colors.black,      /// 可选, 组件背景色
              // pathBackgroundColor: Colors.black   /// 可选, 线条背景色
            );

          ///if you don't want override completed widget
          ///please return null or state.completedWidget
          //return null;
          //return state.completedWidget;
          case LoadState.completed:
            return state.completedWidget;
          case LoadState.failed:
            return const Icon(
              Icons.image_not_supported_outlined,
            );
          /*GestureDetector(
              child: const Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Icon(
                    Icons.error,
                    color: Colors.red,
                  ),
                ],
              ),
              onTap: () {
                state.reLoadImage();
              },
            );*/
        }
      },
    );
  }

  static String proxyImageUrl(String imageUrl,{int? width, int? height}) {
    var encodeUrl = Uri.encodeComponent(imageUrl);
    var sizeText = "";
    if(width != null && height != null) {
      // sizeText="&size=f$width,$height";
      sizeText="&size=w$width";
    }
    var proxyUrl = "https://gimg0.baidu.com/gimg/src=$encodeUrl&app=2001&n=0&g=0n&q=80&fmt=webp$sizeText";
    return proxyUrl;
  }
}
