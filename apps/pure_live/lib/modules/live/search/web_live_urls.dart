/// The platform's own live directory on the web, or null when the platform
/// has no web presence worth opening.
///
/// This is the universal fallback: when a platform's native feed is empty or
/// blocked (Cloudflare, no anonymous list), the popular page opens this page
/// in the in-app WebView instead of leaving a dead tab.
Uri? webLiveUrl(String platform) {
  final url = switch (platform.trim().toLowerCase()) {
    'bilibili' => 'https://live.bilibili.com/',
    'douyu' => 'https://www.douyu.com/directory',
    'huya' => 'https://www.huya.com/l',
    'douyin' => 'https://live.douyin.com/',
    'kuaishou' => 'https://live.kuaishou.com/',
    'twitch' => 'https://www.twitch.tv/directory',
    'soop' => 'https://www.sooplive.co.kr/',
    'yy' => 'https://www.yy.com/',
    'acfun' => 'https://live.acfun.cn/',
    'picarto' => 'https://picarto.tv/explore',
    'twitcasting' => 'https://twitcasting.tv/',
    'niconico' => 'https://live.nicovideo.jp/',
    'kilakila' => 'https://live.kilakila.cn/',
    'youtube' => 'https://www.youtube.com/live',
    'chzzk' => 'https://chzzk.naver.com/',
    'kick' => 'https://kick.com/browse',
    'tiktok' => 'https://www.tiktok.com/live',
    'xiaohongshu' => 'https://www.xiaohongshu.com/',
    'fc2live' => 'https://live.fc2.com/',
    'pandalive' => 'https://www.pandalive.co.kr/',
    'showroom' => 'https://www.showroom-live.com/',
    'sixroom' => 'https://www.sixroom.com/',
    'liveme' => 'https://www.liveme.com/',
    'bigo' => 'https://www.bigo.tv/',
    'inke' => 'https://www.inke.cn/',
    'jdlive' => 'https://live.jd.com/',
    'kugoulive' => 'https://live.kugou.com/',
    'missevan' => 'https://live.missevan.com/',
    '17live' => 'https://17.live/',
    'baidulive' => 'https://live.baidu.com/',
    'weibo' => 'https://weibo.com/l/wblive/p/show',
    'steambroadcast' => 'https://steamcommunity.com/?subsection=broadcasts',
    _ => null,
  };
  return url == null ? null : Uri.tryParse(url);
}
