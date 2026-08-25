import 'dart:async';
import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/search_ranking.dart';
import 'package:url_launcher/url_launcher.dart';

const Duration liveSearchRequestTimeout = Duration(seconds: 12);

class SearchController extends GetxController {
  SearchController() : sites = List<Site>.unmodifiable(Sites().availableSites()) {
    scrollController.addListener(_handleSearchScroll);
  }

  /// A stable platform snapshot for the lifetime of this page.
  ///
  /// Rebuilding [Sites.availableSites] creates new adapter instances. Keeping
  /// one snapshot prevents the tab labels, selected index and paginated
  /// adapter state (notably Twitch cursors) from drifting apart mid-search.
  final List<Site> sites;
  var index = 0.obs;
  final results = <LiveRoom>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final pendingSiteCount = 0.obs;
  final hasMore = false.obs;
  final searched = false.obs;
  final errorMessage = ''.obs;
  final includeOffline = true.obs;
  final sortMode = LiveSearchSortMode.smart.obs;
  final ScrollController scrollController = createPureLiveScrollController();
  bool _isWebView2Available = true;
  int _searchGeneration = 0;
  int _currentPage = 0;
  String _activeKeyword = '';
  final Map<String, LiveRoom> _rawResults = {};
  final Map<String, bool> _hasMoreByPlatform = {};
  final List<Worker> _audienceWorkers = [];
  void selectPlatform(int requestedIndex) {
    final selectedIndex = requestedIndex.clamp(0, sites.length).toInt();
    if (selectedIndex == index.v) return;
    index.value = selectedIndex;
    if (searched.v) doSearch();
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
      case Sites.twitchSite:
        return "https://www.twitch.tv/search?term=$q";
      case Sites.soopSite:
        return "https://www.sooplive.co.kr/?szKeyword=$q";
      case Sites.yySite:
        return "https://www.yy.com/search-$q";
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
    pendingSiteCount.v = 0;
    hasMore.v = false;
    searched.v = true;
    errorMessage.v = '';
    _rawResults.clear();
    _hasMoreByPlatform.clear();
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
    final selectedSites = index.v == 0 ? sites : (index.v <= sites.length ? [sites[index.v - 1]] : <Site>[]);
    if (!append) {
      for (final site in selectedSites) {
        final capability = LiveSearchCapabilities.forPlatform(site.id);
        _hasMoreByPlatform[site.id] = capability.supportsNativeSearch;
      }
    }
    final searchableSites = selectedSites.where((site) {
      final capability = LiveSearchCapabilities.forPlatform(site.id);
      return capability.supportsNativeSearch && (!append || (_hasMoreByPlatform[site.id] ?? true));
    }).toList();

    if (searchableSites.isEmpty) {
      if (generation != _searchGeneration) return;
      if (selectedSites.length == 1 &&
          !LiveSearchCapabilities.forPlatform(selectedSites.single.id).supportsNativeSearch) {
        errorMessage.v = i18n('search_web_only_platform', args: {'site': selectedSites.single.name});
      }
      _applyFiltersAndSort();
      hasMore.v = false;
      loading.v = false;
      loadingMore.v = false;
      pendingSiteCount.v = 0;
      return;
    }

    pendingSiteCount.v = searchableSites.length;
    final failures = <String>[];
    var completed = 0;
    final batchStream = Stream<_SiteSearchBatch>.fromFutures(
      searchableSites.map((site) async {
        try {
          final rooms = await site.liveSite
              .searchRooms(keyword, page: page, pageSize: 20)
              .timeout(liveSearchRequestTimeout);
          return _SiteSearchBatch(site: site, rooms: rooms);
        } on TimeoutException catch (error) {
          debugPrint('Native search timed out for ${site.id}: $error');
          return _SiteSearchBatch(site: site, rooms: const [], failed: true);
        } catch (error) {
          debugPrint('Native search failed for ${site.id}: $error');
          return _SiteSearchBatch(site: site, rooms: const [], failed: true);
        }
      }),
    );

    // Render completed platforms immediately instead of holding the whole
    // result grid behind the slowest network request.
    await for (final batch in batchStream) {
      if (generation != _searchGeneration) return;
      final capability = LiveSearchCapabilities.forPlatform(batch.site.id);
      final beforeCount = _rawResults.length;
      for (final room in batch.rooms) {
        _rawResults[_roomKey(room)] = room;
      }
      final addedCount = _rawResults.length - beforeCount;
      if (batch.failed) failures.add(batch.site.name);
      _hasMoreByPlatform[batch.site.id] =
          !batch.failed && capability.supportsPagination && batch.rooms.isNotEmpty && addedCount > 0;
      completed++;
      pendingSiteCount.v = searchableSites.length - completed;
      _applyFiltersAndSort();
      if (results.isNotEmpty || completed == searchableSites.length) {
        loading.v = false;
      }
    }

    if (generation != _searchGeneration) return;
    _currentPage = page;
    hasMore.v = selectedSites.any((site) => _hasMoreByPlatform[site.id] ?? false);
    if (failures.isNotEmpty) {
      errorMessage.v = i18n('search_partial_failure', args: {'sites': failures.join('、')});
    } else {
      errorMessage.v = '';
    }
    loading.v = false;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
  }

  String _roomKey(LiveRoom room) {
    final platform = room.platform?.trim().toLowerCase() ?? 'unknown';
    final roomId = room.roomId?.trim() ?? '';
    if (roomId.isNotEmpty) return '$platform:$roomId';
    return '$platform:${room.nick?.trim()}:${room.title?.trim()}';
  }

  bool get hasFilteredOfflineResults => _rawResults.isNotEmpty && results.isEmpty && !includeOffline.v;

  void _applyFiltersAndSort() {
    final platformOrder = sites.map((site) => site.id).toList();
    results.assignAll(
      LiveSearchRanking.apply(
        rooms: _rawResults.values,
        mode: sortMode.v,
        includeOffline: includeOffline.v,
        platformOrder: platformOrder,
        audienceCompare: _compareAudience,
      ),
    );
  }

  void setIncludeOffline(bool value) {
    includeOffline.v = value;
    _applyFiltersAndSort();
  }

  void setSortMode(LiveSearchSortMode value) {
    sortMode.v = value;
    _applyFiltersAndSort();
  }

  String get capabilityText {
    if (index.v > 0 && index.v <= sites.length) {
      final site = sites[index.v - 1];
      final capability = LiveSearchCapabilities.forPlatform(site.id);
      return switch (capability.coverage) {
        NativeSearchCoverage.liveAndOffline => i18n('search_coverage_live_and_offline', args: {'site': site.name}),
        NativeSearchCoverage.liveOnly => i18n('search_coverage_live_only', args: {'site': site.name}),
        NativeSearchCoverage.localChannels => i18n('search_coverage_local', args: {'site': site.name}),
        NativeSearchCoverage.webOnly => i18n('search_coverage_web_only', args: {'site': site.name}),
      };
    }

    final nativeCount = sites.where((site) => LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch).length;
    final webOnlySites = sites
        .where((site) => !LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch)
        .map((site) => site.name)
        .join('、');
    return i18n(
      webOnlySites.isEmpty ? 'search_coverage_all_native' : 'search_coverage_all',
      args: {'native': '$nativeCount', 'total': '${sites.length}', 'sites': webOnlySites},
    );
  }

  int _compareAudience(LiveRoom left, LiveRoom right) {
    final app = SettingsService.to.app;
    return LiveRoom.compareAudienceRanking(
      left,
      right,
      preferRealOnline: app.preferRealOnlineCounts.v,
      platformEnabled: app.isRealOnlineEnabledFor,
    );
  }

  bool get canOpenWebSearch {
    if (index.v <= 0 || index.v > sites.length) return false;
    return LiveSearchCapabilities.forPlatform(sites[index.v - 1].id).supportsWebSearch;
  }

  Future<void> openWebSearch() async {
    if (index.v == 0) {
      ToastUtil.show(i18n('select_platform_for_web_search'));
      return;
    }
    if (index.v > sites.length) return;
    final site = sites[index.v - 1];
    if (!LiveSearchCapabilities.forPlatform(site.id).supportsWebSearch) {
      ToastUtil.show(i18n('search_web_unavailable', args: {'site': site.name}));
      return;
    }
    final keyword = searchController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n('please_input_keyword'));
      return;
    }
    final url = buildSearchUrl(site.id, keyword);
    if (Platform.isLinux) {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) ToastUtil.show(i18n('external_browser_not_opened'));
      return;
    }
    if (Platform.isWindows && !_isWebView2Available) {
      showWebView2MissingDialog();
      return;
    }
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
    _audienceWorkers.add(ever(SettingsService.to.app.preferRealOnlineCounts, (_) => _applyFiltersAndSort()));
    _audienceWorkers.add(ever(SettingsService.to.app.realOnlinePlatforms, (_) => _applyFiltersAndSort()));
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
    scrollController
      ..removeListener(_handleSearchScroll)
      ..dispose();
    searchController.dispose();
    for (final worker in _audienceWorkers) {
      worker.dispose();
    }
    super.onClose();
  }
}

class _SiteSearchBatch {
  const _SiteSearchBatch({required this.site, required this.rooms, this.failed = false});

  final Site site;
  final List<LiveRoom> rooms;
  final bool failed;
}
