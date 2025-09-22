import 'dart:io';
import 'dart:async';
import 'package:fvp/fvp.dart' as fvp;
import 'package:fvp/mdk.dart' as mdk;
import 'package:pure_live/main.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:catcher_2/catcher_2.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/plugins/cache_to_file.dart';
import 'package:pure_live/plugins/catcher/file_handler.dart';
import 'package:pure_live/core/common/http_client.dart' as my_http_client;

///全局异常的捕捉
class FlutterCatchError {
  static Catcher2? catcher2;

  static Future<void> run(Widget app, List<String> args) async {
    ///Flutter 框架异常
    FlutterError.onError = (FlutterErrorDetails details) async {
      ///TODO 线上环境
      if (kReleaseMode) {
        Zone.current.handleUncaughtError(details.exception, details.stack!);
      } else {
        ///TODO 开发期间 print
        FlutterError.dumpErrorToConsole(details);
        CoreLog.e(details.exception.toString(), details.stack!);
      }
    };

    setCustomErrorPage();

    await appInit(app, args);

    catcher2 = Catcher2(
      runAppFunction: () {
        runApp(app);
      },
    );
    // compute(updateCatcherConf,"");
    Future.delayed(Duration(seconds: 1), () => updateCatcherConf(""));

    // runZonedGuarded(() async {
    //   appInit(app, args);
    // }, (error, stack) => catchError(error, stack));
  }

  /// 更新 Catcher 配置
  static void updateCatcherConf(String msg) async {
    while (true) {
      try {
        // 异常捕获 logo记录
        final Catcher2Options debugConfig = Catcher2Options(SilentReportMode(), [
          CustomizeFileHandler(await CoreLog.getLogsPath()),
          // ConsoleHandler(
          //   enableDeviceParameters: false,
          //   enableApplicationParameters: false,
          //   enableCustomParameters: false,
          // )
        ]);

        final Catcher2Options releaseConfig = Catcher2Options(SilentReportMode(), [
          CustomizeFileHandler(await CoreLog.getLogsPath(), enableCustomParameters: false),
        ]);
        catcher2!.updateConfig(debugConfig: debugConfig, releaseConfig: releaseConfig);
        CoreLog.i("catcher update config ok");
        return;
      } catch (e) {
        CoreLog.w("catcher update config error: $e");
        sleep(const Duration(seconds: 1));
      }
    }
  }

  static Future<void> appInit(Widget app, List<String> args) async {
    /// 初始化 http
    await my_http_client.HttpClient.initHttp();
    WidgetsFlutterBinding.ensureInitialized();
    PrefUtil.prefs = await SharedPreferences.getInstance();
    MediaKit.ensureInitialized();

    mdk.setGlobalOption("log", "warning");
    Logger.root.level = Level.WARNING;
    fvp.registerWith();
    if (Platform.isWindows) {
      register(kWindowsScheme);
      await WindowsSingleInstance.ensureSingleInstance(args, "pure_live_instance_checker");
      await windowManager.ensureInitialized();
      await WindowUtil.init(width: 1280, height: 720);
    }
    // 先初始化supdatabase
    await SupaBaseManager.getInstance().initial();
    // 初始化服务
    initService();
    initRefresh();

    // 图片缓存删除
    CustomCache.instance.deleteImageCacheFile();

    // 隐藏底部状态栏
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    //   systemNavigationBarColor: Colors.transparent,
    //   systemNavigationBarDividerColor: Colors.transparent,
    //   statusBarColor: Colors.transparent,
    // ));

    ///受保护的代码块
    // runApp(app);
  }

  ///对搜集的 异常进行处理  上报等等
  static void catchError(Object error, StackTrace stack) {
    if (kDebugMode) {
      print("AppCatchError>>>>>>>>>>: $kReleaseMode"); //是否是 Release版本
      print('APP出现异常  message:$error,stackTrace：$stack');
      CoreLog.error(stack);
    }
  }

  ///自定义异常页面
  static void setCustomErrorPage() {
    ErrorWidget.builder = (FlutterErrorDetails flutterErrorDetails) {
      // debugPrint(flutterErrorDetails.toString());
      String stError = flutterErrorDetails.exceptionAsString();
      CoreLog.error(flutterErrorDetails.toString());
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(15),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Icon(Icons.error, size: 55, color: Colors.orange)),
                  Text(
                    "Current module exception${'，System diagnosis as：${stError.split(':').isNotEmpty ? stError.split(':')[0] : ''}'}，Please contact the administrator！",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.4),
                  ),
                  Text(
                    flutterErrorDetails.exceptionAsString(),
                    style: const TextStyle(color: Colors.blue, fontSize: 14),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };
  }
}
