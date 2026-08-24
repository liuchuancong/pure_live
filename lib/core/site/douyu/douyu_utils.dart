import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pure_live/core/common/http_client.dart';


class DouyuUtils {
  // params
  static final _did = "10000000000000000000000000001501";
  static Map<String, dynamic> _encKey = {};

  // api
  // douyu-enc
  static final _apiDouyuEnc = "https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption";

  static bool _encKeyCheck() {
    return (_encKey["expire_at"] ?? 0) > (DateTime.now().microsecondsSinceEpoch ~/ 1000);
  }

  static Future<void> _encKeyUpdate() async {
    if (_encKeyCheck()) {
      return;
    }
    var res = await HttpClient.instance.getJson(
      _apiDouyuEnc,
      queryParameters: {"did": _did},
      header: {
        'user-agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43",
      },
    );
    res['data']?['cpp']?['expire_at'] = DateTime.now().microsecondsSinceEpoch ~/ 1000 + 86400;
    _encKey = res['data'];
  }

  // 用于流/登录/弹幕，暂时只需要流获取
  static Future<String> sign(String rid, {int rate = -1, String cdn = ""}) async {
    var ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _encKeyUpdate();
    String randStr = _encKey["rand_str"] ?? "";
    int encTime = _encKey["enc_time"] ?? 1;
    String salt = (_encKey['is_special'] ?? 0) == 1 ? "" : "$rid$ts";
    String key = _encKey['key'];

    String secret = randStr;
    // 其实只有一次
    for (var i = 0; i < encTime; i++) {
      secret = md5.convert(utf8.encode("$secret$key")).toString();
    }
    String auth = md5.convert(utf8.encode("$secret$key$salt")).toString();
    var postData =
        "enc_data=${_encKey['enc_data']}&tt=$ts&did=$_did&auth=$auth&cdn=$cdn&rate=$rate&hevc=0&fa=0&ive=0&ver=Douyu_new&iar=0";
    return postData;
  }
  // todo: 获取real_rid 暂未发现 fake_id
}
