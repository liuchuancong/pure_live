import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('lightweight logo lookup preserves registered artwork without creating adapters', () {
    expect(Sites.logoForId(' BILIBILI '), 'assets/images/bilibili_2.png');
    // Xiaohongshu gained artwork after this test was written upstream; the
    // neutral fallback is now only reachable for retired platforms.
    expect(Sites.logoForId(' xiaohongshu '), 'assets/images/xiaohongshu.png');
    for (final id in Sites.supportedSiteIds) {
      final asset = Sites.logoForId(id);
      expect(asset, Sites.of(id).logo, reason: id);
      expect(File(asset).existsSync(), isTrue, reason: id);
    }
    expect(() => Sites.logoForId('unregistered'), throwsStateError);
    // Saved follows of retired platforms still render a neutral badge.
    expect(Sites.logoForId(' ShopeeLive '), 'assets/images/logo.png');
    expect(Sites.isSupported('shopeelive'), isFalse);
    expect(Sites.isRetired('HUAJIAO'), isTrue);
  });
}
