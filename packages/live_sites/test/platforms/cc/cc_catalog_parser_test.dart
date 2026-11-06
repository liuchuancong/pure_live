import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_catalog_parser.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:test/test.dart';

// Fixture bodies encoded from E:\study\Pure_live\fixtures\cc
// (S01-cate-all, S01-cate-online, S01-dashen-games, S01-dashen-config).
const String _cateAll = '''
{"msg":"","code":0,"data":{"category_info":{
  "cate_list":[
    {"priority":0,"cate_type":0,"name":"全部"},
    {"priority":10,"cate_type":1,"name":"网游"},
    {"priority":8,"cate_type":2,"name":"手游"},
    {"priority":6,"cate_type":4,"name":"竞技"},
    {"priority":4,"cate_type":5,"name":"综艺"},
    {"priority":2,"cate_type":3,"name":""}
  ],
  "game_list":[]}}}
''';

const String _cateEsports = '''
{"msg":"","code":0,"data":{"category_info":{"game_list":[
  {"url":"http://api.cc.163.com/v1/wapcc/liveinfo?gametype=3&page=1","cover":"http://cotton.res.netease.com/buckets/4NhQWd/files/QikDCNI","name":"梦幻西游电脑版","gametype":"3"},
  {"url":"http://api.cc.163.com/v1/wapcc/liveinfo?gametype=1001&page=1","cover":"http://cotton.res.netease.com/buckets/4NhQWd/files/UEnuqFM","name":"魔兽世界","gametype":1001},
  {"url":"http://api.cc.163.com/v1/wapcc/liveinfo?gametype=9133&page=1","cover":"http://cotton.res.netease.com/buckets/4NhQWd/files/SRoEGir","name":"永劫无间","gametype":"9133"},
  {"cover":"","name":"&amp;无类型","gametype":""},
  {"cover":"","name":"重复的区域","gametype":"3"}
]}}}
''';

const String _dashenGames = '''
{"result":[
  {"squareId":"a","type":"NETEASE","name":"炉石传说","icon":"https://ok.166.net/reunionpub/hs.png","appKey":"ld2"},
  {"squareId":"b","type":"NETEASE","name":"炉石传说","icon":"https://ok.166.net/reunionpub/hs2.png","appKey":"ld2"},
  {"squareId":"c","type":"NETEASE","name":"","icon":"https://ok.166.net/x.png","appKey":"no-name"},
  {"squareId":"d","type":"OTHER","name":"别的平台","icon":"https://ok.166.net/x.png","appKey":"other"},
  {"squareId":"e","type":"NETEASE","name":"永劫无间","icon":"https://ok.166.net/reunionpub/2026-06-24/ntesgod_cms/1782286149721_ycl64j.png","appKey":"d90"}
],"code":200,"errmsg":""}
''';

const String _dashenConfig = '''
{"result":{
  "id":"67b32cdd1801fc391a6c2657","configType":"WEB_COMMON_PAGE","hidden":false,
  "itemList":[
    {"weight":50,"hidden":false,"name":"圈子页重定向列表","itemList":[
      {"weight":50,"hidden":false,"name":"射雕","content":"6284e8066776790001843126","itemList":[]}
    ]},
    {"weight":50,"hidden":false,"name":"直播入口列表","itemList":[
      {"weight":100,"hidden":false,"name":"d90","content":"https://cc.163.com/249133/?open=blizzardtv&from=8382&platform=ds","itemList":[]},
      {"weight":99,"hidden":false,"name":"ld2","content":"https://cc.163.com/720953/","itemList":[]},
      {"weight":98,"hidden":false,"name":"ld2","content":"https://cc.163.com/720953/","itemList":[]},
      {"weight":97,"hidden":false,"name":"unknown","content":"https://cc.163.com/111/","itemList":[]},
      {"weight":96,"hidden":false,"name":"ld2","content":"https://cc.163.com/n/ds_category/mhxy/","itemList":[]},
      {"weight":95,"hidden":false,"name":"ld2","content":"http://cc.163.com/222/","itemList":[]},
      {"weight":94,"hidden":false,"name":"ld2","content":"https://cc.163.com/0/","itemList":[]},
      {"weight":93,"hidden":true,"name":"ld2","content":"https://cc.163.com/333/","itemList":[]},
      {"weight":92,"hidden":false,"name":"h73","content":"https://cc.163.com/444/#top","itemList":[]}
    ]}
  ]
},"code":200,"errmsg":""}
''';

CcFailure _failure(Object Function() read) {
  try {
    read();
  } on CcFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

void main() {
  group('categoryTypes (S01-cate-all)', () {
    test('the categories of the mobile site, in server order, without 全部', () {
      expect(CcCatalogParser.categoryTypes(_cateAll), [
        (id: '1', name: '网游'),
        (id: '2', name: '手游'),
        (id: '4', name: '竞技'),
        (id: '5', name: '综艺'),
      ]);
    });

    test('a row without a positive type or a name is skipped, once each', () {
      const body =
          '{"code":0,"data":{"category_info":{"cate_list":['
          '{"cate_type":2,"name":"手游"},{"cate_type":2,"name":"再来"},{"cate_type":"x","name":"文字"},'
          '{"cate_type":0,"name":"全部"},{"cate_type":9,"name":"  "}]},"cate_type":0}}';
      expect(CcCatalogParser.categoryTypes(body), [(id: '2', name: '手游')]);
    });

    test('a code other than 0 is api-changed', () {
      expect(_failure(() => CcCatalogParser.categoryTypes('{"code":1}')).kind, CcFailureKind.apiChanged);
    });
  });

  group('categoryAreas (S01-cate-online)', () {
    test('the areas of the category, grouped under it, a repeated gametype once', () {
      final areas = CcCatalogParser.categoryAreas(_cateEsports, id: '4', name: '竞技');
      expect(areas, hasLength(3));
      expect(areas[0].platform, ccSiteId);
      expect(areas[0].areaId, '3');
      expect(areas[0].areaName, '梦幻西游电脑版');
      expect(areas[0].parentAreaId, '4');
      expect(areas[0].parentAreaName, '竞技');
      expect(areas[0].iconUrl, 'http://cotton.res.netease.com/buckets/4NhQWd/files/QikDCNI');
      // A numeric gametype is read the same as a string one.
      expect(areas[1].areaId, '1001');
      expect(areas[1].areaName, '魔兽世界');
      expect(areas[2].areaId, '9133');
    });

    test('an empty gametype or name is skipped', () {
      final areas = CcCatalogParser.categoryAreas(_cateEsports, id: '4', name: '竞技');
      expect(areas.where((area) => area.areaId.isEmpty), isEmpty);
      expect(areas.map((area) => area.areaName), everyElement(isNot('&amp;无类型')));
    });
  });

  group('officialAreas (S01-dashen-games + S01-dashen-config)', () {
    test('the cc.163.com entries of the live entry group, named by the registry', () {
      final areas = CcCatalogParser.officialAreas(_dashenGames, _dashenConfig);
      expect(areas, hasLength(2));
      expect(areas[0].areaId, 'official:249133');
      expect(areas[0].areaName, '永劫无间');
      expect(areas[0].parentAreaId, 'official');
      expect(areas[0].parentAreaName, '官方房间/专题');
      expect(areas[0].iconUrl, 'https://ok.166.net/reunionpub/2026-06-24/ntesgod_cms/1782286149721_ycl64j.png');
      expect(areas[1].areaId, 'official:720953');
      expect(areas[1].areaName, '炉石传说');
      expect(areas[1].iconUrl, 'https://ok.166.net/reunionpub/hs.png');
    });

    test('everything else is skipped: repeats, unknown games, other links, hidden rows', () {
      final areas = CcCatalogParser.officialAreas(_dashenGames, _dashenConfig);
      expect(areas.where((area) => area.areaId == 'official:720953'), hasLength(1));
      expect(areas.where((area) => area.areaId == 'official:111'), isEmpty);
      expect(areas.where((area) => area.areaId == 'official:222'), isEmpty);
      expect(areas.where((area) => area.areaId == 'official:0'), isEmpty);
      expect(areas.where((area) => area.areaId == 'official:333'), isEmpty);
      expect(areas.where((area) => area.areaId == 'official:444'), isEmpty);
    });

    test('a hidden configuration lists none; a wrong id or two groups are api-changed', () {
      final hidden = _dashenConfig.replaceFirst('"hidden":false,\n  "itemList"', '"hidden":true,\n  "itemList"');
      expect(CcCatalogParser.officialAreas(_dashenGames, hidden), isEmpty);
      expect(
        _failure(
          () => CcCatalogParser.officialAreas(
            _dashenGames,
            _dashenConfig.replaceFirst('67b32cdd1801fc391a6c2657', 'other-id'),
          ),
        ).kind,
        CcFailureKind.apiChanged,
      );
      expect(
        _failure(() => CcCatalogParser.officialAreas(_dashenGames, _dashenConfig.replaceFirst('直播入口列表', '别的列表'))).kind,
        CcFailureKind.apiChanged,
      );
    });

    test('a non-200 Dashen envelope is api-changed', () {
      expect(
        _failure(
          () => CcCatalogParser.officialAreas(_dashenGames.replaceFirst('"code":200', '"code":500'), _dashenConfig),
        ).kind,
        CcFailureKind.apiChanged,
      );
    });
  });

  group('area kinds', () {
    final area = LiveArea.normalized(platform: 'cc', areaId: '9141', areaName: '蛋仔派对');
    final other = LiveArea.normalized(platform: 'douyu', areaId: '9141', areaName: '蛋仔派对');
    final official = LiveArea.normalized(platform: 'cc', areaId: 'official:249133', areaName: '炉石传说');

    test('a numeric game type of cc or of none is listable', () {
      expect(CcCatalogParser.isListableArea(area), isTrue);
      expect(CcCatalogParser.isListableArea(other), isFalse);
      expect(CcCatalogParser.isListableArea(official), isFalse);
      expect(CcCatalogParser.isListableArea(LiveArea.normalized(areaId: '0')), isTrue);
      expect(CcCatalogParser.isListableArea(LiveArea.normalized(platform: 'cc', areaId: '-1')), isFalse);
    });

    test('an official entry is recognized and rebuilt from its id', () {
      expect(CcCatalogParser.isOfficialEntry(official), isTrue);
      expect(CcCatalogParser.isOfficialEntry(area), isFalse);
      expect(
        CcCatalogParser.officialEntryUri(official),
        Uri.parse('https://cc.163.com/249133/?open=blizzardtv&from=8382&platform=ds'),
      );
      expect(CcCatalogParser.officialEntryUri(area), isNull);
      expect(CcCatalogParser.officialEntryUri(LiveArea.normalized(platform: 'cc', areaId: 'official:x')), isNull);
    });
  });
}
