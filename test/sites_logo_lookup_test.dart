import 'dart:io';
import 'package:pure_live/core/sites.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  test('lightweight logo lookup preserves registered artwork without creating adapters', () {
    expect(Sites.logoForId(' BILIBILI '), 'assets/images/bilibili_2.png');
    expect(Sites.logoForId(' xiaohongshu '), 'assets/images/xiaohongshu.png');
    final assets = <String>{};
    for (final id in Sites.supportedSiteIds) {
      final asset = Sites.logoForId(id);
      expect(asset, Sites.of(id).logo, reason: id);
      expect(Sites.supportSites.firstWhere((site) => site.id == id).logo, asset, reason: id);
      expect(asset, isNot('assets/images/logo.png'), reason: '$id has its own artwork');
      expect(File(asset).existsSync(), isTrue, reason: id);
      assets.add(asset);
    }
    expect(assets, hasLength(Sites.supportedSiteIds.length), reason: 'no two platforms share a logo');
    expect(File('assets/images/all.png').existsSync(), isTrue, reason: 'the "all" tab logo ships');
    expect(() => Sites.logoForId('unregistered'), throwsStateError);
    // Saved follows of retired platforms still render a neutral badge.
    expect(Sites.logoForId(' ShopeeLive '), 'assets/images/logo.png');
    expect(Sites.isSupported('shopeelive'), isFalse);
    expect(Sites.isRetired('HUAJIAO'), isTrue);
  });
}
