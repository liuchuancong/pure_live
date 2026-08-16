import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  var index = 0.obs;
  final results = <LiveRoom>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = false.obs;
  final searched = false.obs;
  final errorMessage = ''.obs;
  final ScrollController scrollController = ScrollController();
  bool _isWebView2Available = true;
  int _searchGeneration = 0;
  int _settledTabIndex = 0;
  int _currentPage = 0;
  String _activeKeyword = '';
  SearchController() {
    tabController = TabController(length: Sites().availableSites().length + 1, vsync: this);
    tabController.addListener(() {
      index.value = tabController.index;
      if (!tabController.indexIsChanging && _settledTabIndex != tabController.index) {
        _settledTabIndex = tabController.index;
        if (searched.v) doSearch();
      }
    });
    scrollController.addListener(_handleSearchScroll);
  }

  void _handleSearchScroll() {
    if (!scrollController.hasClients || scrollController.position.extentAfter > 480) return;
    loadMore();
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

  Future<void> doSearch() async {
    final keyword = searchController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n("please_input_keyword"));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (scrollController.hasClients) scrollController.jumpTo(0);
    final generation = ++_searchGeneration;
    _activeKeyword = keyword;
    _currentPage = 0;
    loading.v = true;
    loadingMore.v = false;
    hasMore.v = false;
    searched.v = true;
    errorMessage.v = '';
    results.clear();

    await _searchPage(keyword: keyword, page: 1, generation: generation, append: false);
  }

  Future<void> loadMore() async {
    if (loading.v || loadingMore.v || !hasMore.v || _activeKeyword.isEmpty) return;
    final generation = _searchGeneration;
    loadingMore.v = true;
    await _searchPage(keyword: _activeKeyword, page: _currentPage + 1, generation: generation, append: true);
  }

  Future<void> _searchPage({
    required String keyword,
    required int page,
    required int generation,
    required bool append,
  }) async {
    final sites = Sites().availableSites();
    final selectedSites = index.v == 0 ? sites : [sites[index.v - 1]];
    final failures = <String>[];
    final batches = await Future.wait(
      selectedSites.map((site) async {
        try {
          return await site.liveSite.searchRooms(keyword, page: page, pageSize: 20);
        } catch (error) {
          failures.add(site.name);
          debugPrint('Native search failed for ${site.id}: $error');
          return <LiveRoom>[];
        }
      }),
    );
    if (generation != _searchGeneration) return;

    final unique = <String, LiveRoom>{
      if (append)
        for (final room in results) '${room.platform}:${room.roomId}': room,
    };
    final previousCount = unique.length;
    for (final room in batches.expand((items) => items)) {
      unique['${room.platform}:${room.roomId}'] = room;
    }
    final rooms = unique.values.toList()
      ..sort((a, b) {
        final liveOrder = (b.liveStatus == LiveStatus.live ? 1 : 0) - (a.liveStatus == LiveStatus.live ? 1 : 0);
        if (liveOrder != 0) return liveOrder;
        if (SettingsService.to.app.preferRealOnlineCounts.v) {
          final supportedOrder = (b.supportsRealOnlineCount ? 1 : 0) - (a.supportsRealOnlineCount ? 1 : 0);
          if (supportedOrder != 0) return supportedOrder;
          if (!a.supportsRealOnlineCount) return a.platform.toString().compareTo(b.platform.toString());
        }
        return _numericHeat(b.watching).compareTo(_numericHeat(a.watching));
      });
    results.assignAll(rooms);
    _currentPage = page;
    final receivedResults = batches.any((items) => items.isNotEmpty);
    hasMore.v = receivedResults && unique.length > previousCount;
    if (failures.isNotEmpty) {
      errorMessage.v = i18n('search_partial_failure', args: {'sites': failures.join('、')});
    }
    loading.v = false;
    loadingMore.v = false;
  }

  int _numericHeat(String? value) {
    final text = value?.trim() ?? '';
    final number = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return (text.contains('万') ? number * 10000 : number).round();
  }

  void openWebSearch() {
    if (index.v == 0) {
      ToastUtil.show(i18n('select_platform_for_web_search'));
      return;
    }
    if (Platform.isWindows && !_isWebView2Available) {
      showWebView2MissingDialog();
      return;
    }
    final site = Sites().availableSites()[index.v - 1];
    final url = buildSearchUrl(site.id, searchController.text.trim());
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

  @override
  void onClose() {
    _searchGeneration++;
    tabController.dispose();
    scrollController
      ..removeListener(_handleSearchScroll)
      ..dispose();
    searchController.dispose();
    super.onClose();
  }
}
