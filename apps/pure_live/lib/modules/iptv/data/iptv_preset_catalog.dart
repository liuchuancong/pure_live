import 'package:pure_live/modules/iptv/data/iptv_preset.dart';

/// The catalogue the app ships: what a fresh install adds on the first visit
/// to the IPTV screens, and what the start screen offers to add back.
///
/// The default is the reference IPTV app's own pairing: its merged Migu list
/// (rebuilt by its CI every quarter hour) and the raw Migu list under it,
/// with the two public Chinese guides it falls back to. Both lists sign
/// their stream addresses, so both are short-lived. The GitHub addresses are
/// the raw origin on purpose: every download goes through the viewer's
/// GitHub accelerator, never a mirror written into the catalogue.
///
/// The feed the repository publishes ([iptvPresetFeedUrl]) replaces this
/// list without a release when a source dies.
const List<IptvPreset> builtinIptvPresets = [
  IptvPreset(
    id: 'lemontv',
    names: {'zh-CN': '柠檬直播源', 'en': 'LemonTV'},
    descriptions: {
      'zh-CN': '柠檬IPTV维护的咪咕合并源：央视、卫视与地方台约百个频道，自带回看模板与节目单地址。',
      'en':
          'The Migu list LemonTV maintains: about a hundred CCTV, provincial and local channels, '
          'with its own replay template and guide.',
    },
    url: 'https://raw.githubusercontent.com/jia070310/lemonTV/main/iptv-fe.m3u',
    guideUrls: ['http://epg.51zmt.top:8000/e1.xml.gz', 'https://epg.zsdc.eu.org/t.xml.gz'],
    tags: [
      {'zh-CN': '央视', 'en': 'CCTV'},
      {'zh-CN': '卫视', 'en': 'Provincial'},
      {'zh-CN': '回看', 'en': 'Replay'},
    ],
    shortLived: true,
  ),
  IptvPreset(
    id: 'migu',
    names: {'zh-CN': '咪咕直播源', 'en': 'Migu'},
    descriptions: {
      'zh-CN': 'ioptu/migu_video 维护的咪咕视频频道列表；频道地址带时效签名，过期前会自动刷新。',
      'en':
          'The Migu Video channel list ioptu/migu_video maintains; its addresses are signed and '
          'refreshed before they expire.',
    },
    url: 'https://raw.githubusercontent.com/ioptu/migu_video/main/migu.m3u',
    guideUrls: ['http://epg.51zmt.top:8000/e1.xml.gz', 'https://epg.zsdc.eu.org/t.xml.gz'],
    tags: [
      {'zh-CN': '央视', 'en': 'CCTV'},
      {'zh-CN': '回看', 'en': 'Replay'},
    ],
    shortLived: true,
  ),
  IptvPreset(
    id: 'iptv-org-cn',
    names: {'zh-CN': 'iptv-org 中国频道', 'en': 'iptv-org China'},
    descriptions: {
      'zh-CN': 'iptv-org 开源目录的中国频道集（约 150 个，以央视和少数省级为主），地址无签名依赖；来源公开、更新自动，但清晰度与可用性参差。',
      'en':
          "iptv-org's China collection (about 150 channels, mostly CCTV and a few provincial), "
          'unsigned public addresses; automatically updated, but quality and availability vary.',
    },
    url: 'https://iptv-org.github.io/iptv/countries/cn.m3u',
    tags: [
      {'zh-CN': '公开源', 'en': 'Public'},
      {'zh-CN': '央视', 'en': 'CCTV'},
    ],
  ),
];

/// The preset the first visit adds.
const String iptvDefaultPresetId = 'lemontv';

/// The remote feed's address: the same catalogue shape, published in the
/// repository's config directory and fetched through the app's GitHub
/// mirrors — the pattern the mirror table itself uses.
const String iptvPresetFeedUrl =
    'https://raw.githubusercontent.com/liuchuancong/pure_live/master/config/iptv_presets/iptv_presets.json';
