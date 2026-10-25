/// The platform's own web-search page for [keyword], or null when the
/// platform has none (or the keyword is blank).
///
/// The addresses are the platforms' public search pages, the same list the
/// reference app uses; a platform missing here simply offers no web search.
Uri? webSearchUrl(String platform, String keyword) {
  final query = Uri.encodeComponent(keyword.trim());
  if (query.isEmpty) return null;
  final url = switch (platform) {
    'bilibili' => 'https://search.bilibili.com/live?keyword=$query',
    'douyu' => 'https://www.douyu.com/search?kw=$query',
    'huya' => 'https://www.huya.com/search?hsk=$query',
    'douyin' => 'https://www.douyin.com/search/$query?type=live',
    'kuaishou' => 'https://live.kuaishou.com/search?keyword=$query',
    'cc' => 'https://cc.163.com/search/all/?query=$query&only=all',
    'twitch' => 'https://www.twitch.tv/search?term=$query',
    'soop' => 'https://www.sooplive.co.kr/?szKeyword=$query',
    'yy' => 'https://www.yy.com/search-$query',
    'acfun' => 'https://www.acfun.cn/search?keyword=$query&type=user',
    'picarto' => 'https://picarto.tv/search?q=$query',
    'twitcasting' => 'https://twitcasting.tv/search/text/?tw_search_query=$query',
    'niconico' => 'https://live.nicovideo.jp/search?keyword=$query&status=onair',
    'kilakila' => 'https://live.kilakila.cn/aboutus/serach/kw/$query',
    'youtube' => 'https://www.youtube.com/results?search_query=$query',
    'chzzk' => 'https://chzzk.naver.com/search?query=$query',
    'kick' => 'https://kick.com/search?query=$query',
    'tiktok' => 'https://www.tiktok.com/search?q=$query',
    _ => null,
  };
  return url == null ? null : Uri.tryParse(url);
}
