import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show HongguoSigner;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart' show HongguoVendor;

/// The vectors below come from hongguoTV's `server/vendor/hongguo.cjs` run
/// over this exact device map, body, clock and random stream. They pin the
/// four signature bugs this port used to have (rotates above 31, the proto
/// field lookup, the big-endian schedule words, and the XOR rounds), all of
/// which the live endpoints answer with an empty 200.
const List<int> _draws = [
  0x12345678,
  0x9abcdef0,
  0x0f1e2d3c,
  0x24681357,
  0x11223344,
  0x55667788,
  0x99aabbcc,
  0xddeeff00,
  0x10203040,
  0x50607080,
  0x90a0b0c0,
  0xd0e0f000,
];

const int _clockMs = 1793206800123;

const String _base = 'https://api5-normal-sinfonlineb.fqnovel.com/reading/distribution/category/landpage/v/';

const String _expectedUrl =
    'https://api5-normal-sinfonlineb.fqnovel.com/reading/distribution/category/landpage/v/'
    '?iid=1905892595382586&device_id=1905892595378490&ac=wifi&channel=update_64&aid=8662'
    '&app_name=novelread&version_code=71332&version_name=7.1.3.32&device_platform=android'
    '&os=android&ssmix=a&device_type=25053RT47C&device_brand=Redmi&language=zh&os_api=36'
    '&os_version=16&manifest_version_code=71332&resolution=1280%2A2772&dpi=520'
    '&update_version_code=71332&host_abi=arm64-v8a&dragon_device_type=phone&pv_player=71332'
    '&compliance_status=0&need_personal_recommend=1&player_so_load=1&is_android_pad_screen=0'
    '&ts=1793206800&_rticket=1793206800123';

const String _expectedGorgon = '840434124001d01dd0fb772041e91364e71df6105ab6906a2661';
const String _expectedHelios = '8N68moXAadd535kR4Pnt+v5h3parsjG7Nnep6e4KlrQ6lDSs';
const String _expectedMedusa =
    'EyriaufCvZDH/T5RxgAqGkflg3KIdwABHzWMu7qRA+AGOCYkfsU7D6kL2Ff6ggxRO++6nGRhOGhBoH6nubmKqTnFZCxaECQRlKggRnnEj4tp79eUpecc9YLv5Xd0S70BFBtqvXYD6hByb99PWBcS7TXpLs79h3q8SkWTNoUO+wzE0TttAj2Os4uwWwUhdE3KtYZ9rKoEvl6miuH6GGFYRordfd4vR/6bkFWl8GNYTYSDMamY53Qb/a78dXYo2saLxOrrU46dbogHNW85XDdk3bVjcYrXUkM5u7Nn9c3Pok3SbUE2CjwFyLywjQM38/5pWzwiXAbL4lj9hDpH4GZ173wnT8NhubSxJhRl41u6g6vcT4XwOEZpPzH8egKOwe16ATVQ9NlQ9Fcg9haO6ZGXgol6/1FCv5AXIEsNvTwcRP80wTWw+piTZmADJefHo+u8DQIZY1CaicFLuxLeopoxE50aVNGF5u7oiPVfZ9FZyxWjSYN4JUDKfu68HW//HMF4jhKSdiNuDKWKpnqcmi7mjETZKgPPYkeC+/v21Gir7Unml2Z7nryVTJUyAaJHqhZT6gvoifselsQ9w3qNNK20VAR8On0PNNIxGK1TRsM9JgN4fgZxd8vyuCW5DfW7KPb9CkGVmd8oSreErPiSSUp3XBKg8iYSnNA/WN9fopEM3d+0AJnNOmR/6rfv4XfY851FzlGBYJMbtGsDFktVQYhvyM5sKweqTdhcx9P9Kfi2FnRWnByn0+B7AWnznEn9cXyRZxaViQdKSV+6OCTupUzTsWN4V41Vo2TETbuJyOEYr6rmwK1UdpjzD4QDmMFXGYOf+uZPos9x8NShF6MeKHWhx2w9N6YGibwemyyMbEKEkM0buBpzPHqekP2RcD7Hx5lmWjGGtBhR72IxmVCyVpSVGjjQ4Z1meJrOa9jLWuSM4pJZx1tM1Dwm5758IDg0pvGRX08qgqJ4RrNm+OOd6hT0QNYIjGXvbYOH8iSkI87P//zPz//9j2ZV';

String _body() => jsonEncode({
  'offset': 0,
  'limit': 24,
  'need_selector_panel': true,
  'select_items': {'genre': <Object?>[], 'sort': <Object?>[]},
  'session_id': '',
  'req_type': 'default',
  'client_req_type': 3,
  'filter_ids': '',
  'req_scene': 'default',
});

void main() {
  HongguoSigner signer() {
    var at = 0;
    return HongguoSigner(random: () => _draws[at++ % _draws.length], clock: () => _clockMs);
  }

  test('the signed request matches the reference implementation', () {
    final signed = signer().sign(_base, HongguoVendor.device, body: Uint8List.fromList(utf8.encode(_body())));

    expect(signed.url, _expectedUrl);
    expect(signed.headers['x-khronos'], '1793206800');
    expect(signed.headers['x-ss-req-ticket'], '1793206800123');
    expect(signed.headers['x-ladon'], 'auIqEA==');
    expect(signed.headers['x-argus'], 'ECriag==');
    expect(signed.headers['x-gorgon'], _expectedGorgon);
    expect(signed.headers['x-helios'], _expectedHelios);
    expect(signed.headers['x-medusa'], _expectedMedusa);
    expect(signed.headers['x-ss-stub'], '63434F401CF17FE54E83C78D6944A837');
  });

  test('a GET signs without a body and carries no stub', () {
    final signed = signer().sign(_base, HongguoVendor.device);

    expect(signed.body, isNull);
    expect(signed.url, isNot(contains('_rticket=0')));
    expect(signed.headers['x-gorgon'], isNotEmpty);
    expect(signed.headers['x-medusa'], isNotEmpty);
    expect(signed.headers.containsKey('x-ss-stub'), isFalse);
    expect(signed.headers.containsKey('Content-Type'), isFalse);
  });
}
