/// The platform's web search address for [keyword] (3.x `buildSearchUrl`),
/// or null when the platform has none. The table is the reference's, kept
/// for the platforms this app actually registers; a platform with a
/// first-party API search still gets its web page as the fallback the
/// reference offers (A09.7 继续网页搜索).
Uri? webSearchUrl(String platform, String keyword) {
  final q = Uri.encodeComponent(keyword.trim());
  final url = switch (platform) {
    'bilibili' => 'https://search.bilibili.com/live?keyword=$q',
    'douyu' => 'https://www.douyu.com/search?kw=$q',
    'huya' => 'https://www.huya.com/search?hsk=$q',
    'douyin' => 'https://www.douyin.com/search/$q?type=live',
    'kuaishou' => 'https://live.kuaishou.com/search?keyword=$q',
    'cc' => 'https://cc.163.com/search/all/?query=$q&only=all',
    'twitch' => 'https://www.twitch.tv/search?term=$q',
    'soop' => 'https://www.sooplive.co.kr/?szKeyword=$q',
    'yy' => 'https://www.yy.com/search-$q',
    'acfun' => 'https://www.acfun.cn/search?keyword=$q&type=user',
    'picarto' => 'https://picarto.tv/search?q=$q',
    'twitcasting' => 'https://twitcasting.tv/search/text/?tw_search_query=$q',
    'niconico' => 'https://live.nicovideo.jp/search?keyword=$q&status=onair',
    'kilakila' => 'https://live.kilakila.cn/aboutus/serach/kw/$q',
    _ => null,
  };
  return url == null || q.isEmpty ? null : Uri.parse(url);
}
