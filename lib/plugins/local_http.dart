// import 'dart:io';
// import 'dart:convert';
// import 'dart:io' as io;
// import 'package:get/get.dart';
// import 'package:dia/dia.dart';
// import 'package:path/path.dart' as p;
// import 'package:dia_cors/dia_cors.dart';
// import 'package:dia_body/dia_body.dart';
// import 'package:dia_static/dia_static.dart';
// import 'package:pure_live/common/index.dart';
// import 'package:flutter_restart/flutter_restart.dart';
// import 'package:pure_live/core/common/core_log.dart';
// import 'package:pure_live/routes/app_navigation.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:dia_router/dia_router.dart' as dia_router;
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:pure_live/plugins/file_recover_utils.dart';
// import 'package:pure_live/modules/areas/areas_list_controller.dart';
// import 'package:pure_live/modules/search/search_list_controller.dart';
// import 'package:pure_live/modules/live_play/live_play_controller.dart';
// import 'package:pure_live/modules/popular/popular_grid_controller.dart';
// import 'package:pure_live/modules/area_rooms/area_rooms_controller.dart';
// import 'package:pure_live/common/services/bilibili_account_service.dart';
// import 'package:pure_live/modules/search/search_controller.dart' as pure_live;
//
// class ContextRequest extends Context with dia_router.Routing, ParsedBody {
//   ContextRequest(super.request);
// }
//
// final app = App((req) => ContextRequest(req));
//
// class LocalHttpServer {
//   static bool webPortEnableStatus = false;
//   final SettingsService settings = Get.find<SettingsService>();
//   Future<void> readAssetsFiles() async {
//     final assets = await rootBundle.loadString('AssetManifest.json');
//     var assetList = jsonDecode(assets) as Map<String, dynamic>;
//     assetList.removeWhere((key, value) => !key.startsWith('assets/pure_live_web'));
//     final directory = await getApplicationCacheDirectory();
//     for (final assetPath in assetList.keys) {
//       final assetData = await rootBundle.load(assetPath);
//       final file = File('${directory.path}/$assetPath');
//       await file.create(recursive: true);
//       await file.writeAsBytes(assetData.buffer.asUint8List());
//     }
//   }
//
//   void startServer(String port) async {
//     try {
//       final connectivityResults = await (Connectivity().checkConnectivity());
//       for (final result in connectivityResults) {
//         if (result == ConnectivityResult.mobile) {
//           SmartDialog.showToast('请在局域网下使用', displayTime: const Duration(seconds: 2));
//           return;
//         }
//       }
//       if (webPortEnableStatus) {
//         return;
//       }
//       await readAssetsFiles();
//       final directory = await getApplicationCacheDirectory();
//
//       app.use(serve(p.join(directory.path, 'assets${Platform.pathSeparator}pure_live_web'),
//           prefix: '/pure_live', index: 'index.html'));
//       app.use(body());
//       app.use(cors());
//
//       final router = dia_router.Router('/api');
//       router.get('/path/:id', (ctx, next) async {
//         ctx.body = 'params=${ctx.params} query=${ctx.query}';
//       });
//       router.get('/getSettings', (ctx, next) async {
//         ctx.body = jsonEncode(settings.toJson());
//       });
//
//       router.get('/getFavoriteRooms', (ctx, next) async {
//         ctx.body = jsonEncode(settings.favoriteRooms.map((e) => jsonEncode(e.toJson())).toList());
//       });
//
//       router.post('/closeWebServer', (ctx, next) async {
//         var webPort = ctx.query['webPort']!;
//         settings.webPort.value = webPort;
//         settings.webPortEnable.value = false;
//         ctx.body = jsonEncode({'data': true});
//       });
//
//       router.post('/getHistoryData', (ctx, next) async {
//         ctx.body = jsonEncode(settings.historyRooms.map((e) => jsonEncode(e.toJson())).toList());
//       });
//
//       router.post('/postFavoriteRooms', (ctx, next) async {
//         final FavoriteController controller = Get.find<FavoriteController>();
//         final result = await controller.onRefresh();
//         ctx.body = jsonEncode({'data': !result});
//       });
//       router.post('/exitRoom', (ctx, next) async {
//         try {
//           ctx.body = jsonEncode({'data': true});
//           var currentRoute = Get.previousRoute;
//           if (currentRoute == '/areas') {
//             Get.offAndToNamed(RoutePath.kInitial);
//           } else if (currentRoute == RoutePath.kAreaRooms) {
//             Navigator.of(Get.context!).pop();
//           } else if (currentRoute == '/home') {
//             Navigator.of(Get.context!).pop();
//           } else if (currentRoute == RoutePath.kLivePlay) {
//             final LivePlayController livePlayController = Get.find<LivePlayController>();
//             if (livePlayController.videoController != null && livePlayController.videoController!.isFullscreen.value) {
//               if (livePlayController.videoController!.isFullscreen.value) {
//                 livePlayController.videoController!.toggleFullScreen();
//               }
//             } else {
//               Navigator.of(Get.context!).pop();
//             }
//           }
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/fullscreenRoom', (ctx, next) async {
//         try {
//           final LivePlayController livePlayController = Get.find<LivePlayController>();
//           if (livePlayController.videoController != null) {
//             livePlayController.videoController!.toggleFullScreen();
//           }
//           ctx.body = jsonEncode({'data': true});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/favoriteRoom', (ctx, next) async {
//         try {
//           final LivePlayController livePlayController = Get.find<LivePlayController>();
//           if (livePlayController.videoController != null) {
//             final liveRoom = livePlayController.detail.value;
//             if (settings.isFavorite(liveRoom!)) {
//               settings.removeRoom(liveRoom);
//               ctx.body = jsonEncode({
//                 'data': '取消关注成功',
//               });
//             } else {
//               settings.addRoom(liveRoom);
//               ctx.body = jsonEncode({
//                 'data': '关注成功',
//               });
//             }
//           } else {
//             ctx.body = jsonEncode({
//               'data': '请进入直播间重试',
//             });
//           }
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': '操作失败'});
//         }
//       });
//       router.post('/enterRoom', (ctx, next) async {
//         try {
//           final liveRoom = jsonDecode(ctx.query['liveRoom']!);
//           ctx.body = jsonEncode({
//             'data': true,
//           });
//           AppNavigator.toLiveRoomDetail(liveRoom: LiveRoom.fromJson(liveRoom));
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/enterSearch', (ctx, next) async {
//         try {
//           ctx.body = jsonEncode({'data': true});
//           Get.toNamed(RoutePath.kSearch);
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/doSearch', (ctx, next) async {
//         try {
//           ctx.body = jsonEncode({'data': true});
//           Get.toNamed(RoutePath.kSearch);
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/getLibilibiLoginStatus', (ctx, next) async {
//         final BiliBiliAccountService accountService = Get.find<BiliBiliAccountService>();
//         ctx.body = jsonEncode({'data': accountService.logined.value, 'name': accountService.name.value});
//       });
//
//       router.post('/toBiliBiliLogin', (ctx, next) async {
//         try {
//           Get.toNamed(RoutePath.kBiliBiliQRLogin);
//           ctx.body = jsonEncode({'data': true});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/exitBilibili', (ctx, next) async {
//         try {
//           BiliBiliAccountService.instance.logout();
//           ctx.body = jsonEncode({'data': true});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/uploadSettingsConfig', (ctx, next) async {
//         try {
//           settings.fromJson(json.decode(ctx.query['setting']!));
//           ctx.body = jsonEncode({'data': true});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/toggleTabevent', (ctx, next) async {
//         try {
//           int index = int.parse(ctx.query['index']!);
//           String tag = ctx.query['tag']!;
//           FavoriteController favoriteController = Get.find<FavoriteController>();
//           switch (ctx.query['type']!) {
//             case 'online':
//               favoriteController.tabController.animateTo(index);
//               break;
//             case 'bottomTab':
//               favoriteController.tabBottomIndex.value = index;
//               break;
//             case 'hotTab':
//               PopularController popularController = Get.find<PopularController>();
//               popularController.tabController.animateTo(index);
//               break;
//             case 'areaTab':
//               AreasController areasController = Get.find<AreasController>();
//               areasController.tabController.animateTo(index);
//               break;
//             case 'areaSubTab':
//               AreasListController controller = Get.find<AreasListController>(tag: tag);
//               controller.tabIndex.value = index;
//               break;
//             case 'doSearch':
//               pure_live.SearchController controller = Get.find<pure_live.SearchController>();
//               controller.tabController.animateTo(index);
//               break;
//             default:
//           }
//
//           ctx.body = jsonEncode({'data': true});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//
//       router.post('/toggleWebServer', (ctx, next) async {
//         bool webPortEnable = ctx.query['webPortEnable']!.toBoolean();
//         String webPort = ctx.query['webPort']!;
//         if (settings.webPortEnable.value != webPortEnable) {
//           settings.webPortEnable.value = webPortEnable;
//         }
//         if (settings.webPort.value != webPort) {
//           settings.webPort.value = webPort;
//         }
//         ctx.body = jsonEncode({'data': true});
//       });
//
//       router.post('/restartApp', (ctx, next) async {
//         if (Platform.isAndroid) {
//           FlutterRestart.restartApp();
//           ctx.body = jsonEncode({'data': true});
//         } else {
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/getGridData', (ctx, next) async {
//         String data = '';
//         try {
//           String tag = ctx.query['tag']!;
//           int page = int.parse(ctx.query['page']!);
//           int pageSize = int.parse(ctx.query['pageSize']!);
//           String keywords = ctx.query['keywords']!;
//           switch (ctx.query['type']!) {
//             case 'hotTab':
//               var controller = Get.find<PopularGridController>(tag: tag);
//               var sizeData = await controller.getData(page, pageSize);
//               controller.list.addAll(sizeData);
//
//               if (page == 1) {
//                 data = jsonEncode(controller.list.map((LiveRoom element) => jsonEncode(element.toJson())).toList());
//               } else {
//                 controller.scrollToBottom();
//                 data = jsonEncode(sizeData.map((LiveRoom element) => jsonEncode(element.toJson())).toList());
//               }
//
//               break;
//             case 'areaTab':
//               var controller = Get.find<AreasListController>(tag: tag);
//               data = jsonEncode(controller.list.value);
//               break;
//             case 'areaRoomsTab':
//               AreaRoomsController areaRoomController = Get.find<AreaRoomsController>();
//               var sizeData = await areaRoomController.getData(page, pageSize);
//               areaRoomController.list.addAll(sizeData);
//
//               if (page == 1) {
//                 data = jsonEncode(
//                     areaRoomController.list.map((LiveRoom element) => jsonEncode(element.toJson())).toList());
//               } else {
//                 areaRoomController.scrollToBottom();
//                 data = jsonEncode(sizeData.map((LiveRoom element) => jsonEncode(element.toJson())).toList());
//               }
//               break;
//             case 'doSearch':
//               SearchListController searchListController = Get.find<SearchListController>(tag: tag);
//               searchListController.keyword.value = keywords;
//               var sizeData = await searchListController.getData(page, pageSize);
//               searchListController.list.addAll(sizeData as List<LiveRoom>);
//
//               data = jsonEncode(sizeData.map((LiveRoom element) => jsonEncode(element.toJson())).toList());
//               if (page == 1) {
//                 data = jsonEncode((searchListController.list.value as List<LiveRoom>)
//                     .map((LiveRoom element) => jsonEncode(element.toJson()))
//                     .toList());
//               } else {
//                 searchListController.scrollToBottom();
//                 data = jsonEncode(sizeData.map((LiveRoom element) => jsonEncode(element.toJson())).toList());
//               }
//               break;
//             default:
//           }
//           ctx.body = jsonEncode({'data': data});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': data});
//         }
//       });
//       router.post('/toAreaDetail', (ctx, next) async {
//         try {
//           String tag = ctx.query['tag']!;
//           String area = ctx.query['area']!;
//           var site = Sites.of(tag);
//           ctx.body = jsonEncode({'data': true});
//           var areaRoom = LiveArea.fromJson(jsonDecode(area));
//           AppNavigator.toCategoryDetail(site: site, category: areaRoom);
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//       router.post('/uploadFile', (ctx, next) async {
//         try {
//           ctx.body = jsonEncode({'data': true});
//         } catch (e) {
//           CoreLog.error(e);
//           ctx.body = jsonEncode({'data': false});
//         }
//       });
//
//       app.use(router.middleware);
//       app.use((ctx, next) async {
//         if (ctx.query['type'] != null) {
//           String? type = ctx.query['type'];
//           if (type == 'uploadM3u8File') {
//             FileRecoverUtils().recoverM3u8BackupByWeb(ctx.parsed['file'], ctx.parsed['name']);
//           } else if (type == 'uploadRecoverFile') {
//             var dir = await getApplicationCacheDirectory();
//             final file = File('${dir.path}${Platform.pathSeparator}${ctx.parsed['name']}');
//             file.writeAsStringSync(ctx.parsed['file']);
//             if (settings.recover(file)) {
//               SnackBarUtil.success(S.current.recover_backup_success);
//             } else {
//               SnackBarUtil.error(S.current.recover_backup_failed);
//             }
//           } else {
//             next();
//           }
//         } else {
//           next();
//         }
//       });
//       webPortEnableStatus = true;
//       app.listen(io.InternetAddress.anyIPv4.address, int.parse(port));
//       webPortEnableStatus = true;
//       SnackBarUtil.success('Web服务打开成功,请用浏览器打开您的ip地址+:$port/pure_live/');
//     } catch (e) {
//       CoreLog.error(e);
//       webPortEnableStatus = true;
//       settings.webPortEnable.value = false;
//       SnackBarUtil.success('Web服务打开失败,请手动打开');
//     }
//   }
//
//   closeServer() async {
//     app.close();
//     final connectivityResults = await (Connectivity().checkConnectivity());
//     bool isMobile = false;
//     for (final result in connectivityResults) {
//       if (result == ConnectivityResult.mobile) {
//         isMobile = true;
//         break;
//       }
//     }
//     if (!isMobile) {
//       SnackBarUtil.success('Web服务关闭成功');
//       webPortEnableStatus = false;
//     }
//   }
// }
