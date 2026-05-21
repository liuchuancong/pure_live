import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  var index = 0.obs;
  bool _isWebView2Available = true;
  SearchController() {
    tabController = TabController(length: Sites().availableSites().length, vsync: this);
    tabController.addListener(() {
      index.value = tabController.index;
    });
  }

  TextEditingController searchController = TextEditingController();
  String buildSearchUrl(String platform, String keyword) {
    final q = Uri.encodeComponent(keyword);
    switch (platform) {
      case Sites.ccSite:
        return "https://cc.163.com/search/all/?query=$q&only=all";
      case Sites.kuaishouSite:
        return "https://live.kuaishou.com/search?keyword=$q";
      case Sites.huyaSite:
        return "https://www.huya.com/search?hsk=$q";
      case Sites.bilibiliSite:
        return "https://search.bilibili.com/live?keyword=$q&from_source=webtop_search&spm_id_from=444.7&search_source=3";
      case Sites.douyuSite:
        return "https://www.douyu.com/search?kw=$q&dyshid=0-ed88b042da9bbc4cf4abc97500021601";
      case Sites.douyinSite:
        return "https://www.douyin.com/search/$q?type=live";
      default:
        return "https://www.baidu.com/s?wd=$q&rsv_spt=1&rsv_iqid=0x84b83a1e077a0c1a&issp=1&f=8&rsv_bp=1&rsv_idx=2&ie=utf-8&tn=baiduhome_pg&rsv_dl=tb_click&rsv_enter=1&rsv_sug3=3&rsv_sug1=2&rsv_sug7=100&rsv_btype=i&prefixsug=12&rsp=0&inputT=1112&rsv_sug4=1287";
    }
  }

  /// 判断是否安装了 WebView2
  Future<bool> isWebView2Installed() async {
    if (!Platform.isWindows) return true;

    try {
      var result64 = await Process.run('reg', [
        'query',
        r'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
        '/v',
        'pv',
      ]);

      var resultUser = await Process.run('reg', [
        'query',
        r'HKEY_CURRENT_USER\Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
        '/v',
        'pv',
      ]);

      if ((result64.exitCode == 0 && result64.stdout.toString().contains('REG_SZ')) ||
          (resultUser.exitCode == 0 && resultUser.stdout.toString().contains('REG_SZ'))) {
        return true;
      }
    } catch (e) {
      debugPrint("检测 WebView2 失败: $e");
    }
    return false;
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      ToastUtil.show(i18n("please_input_keyword"));
      return;
    }
    if (Platform.isWindows && !_isWebView2Available) {
      showWebView2MissingDialog();
      return;
    }
    final site = Sites().availableSites()[index.value];
    String url = buildSearchUrl(site.id, searchController.text);
    Get.toNamed(RoutePath.kWebSearch, arguments: {'url': url, 'platform': site.id});
  }

  void showWebView2MissingDialog() {
    Get.dialog(
      Builder(
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.report_problem_rounded, color: Theme.of(dialogContext).colorScheme.error),
                const SizedBox(width: 8),
                Text(i18n("webview2_missing_title")),
              ],
            ),
            content: Text(i18n("webview2_missing_content"), style: const TextStyle(height: 1.4)),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n("cancel"))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final url = Uri.parse('https://developer.microsoft.com/zh-cn/microsoft-edge/webview2/?form=MA13LH');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    ToastUtil.show(i18n("webview2_open_error"));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
                ),
                child: Text(i18n("confirm")),
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isWindows) {
        _isWebView2Available = await isWebView2Installed();
        if (!_isWebView2Available) {
          showWebView2MissingDialog();
        }
      }
    });
  }
}
