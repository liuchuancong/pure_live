// Module: test/update_feed_test.dart
// Purpose: Verify the feed reader answers through its transport seam and never throws at its caller.
// Author: liuchuancong
// Created: 2026-10-10
import 'dart:async';

import 'package:pure_live_release/pure_live_release.dart';
import 'package:test/test.dart';

/// A transport replaying one canned answer, failing, or stalling.
final class _FakeTransport implements UpdateFeedTransport {
  _FakeTransport.reply(this.statusCode, this.body, {this.delay = Duration.zero}) : failure = null;

  _FakeTransport.failWith(Object error) : statusCode = 0, body = '', delay = Duration.zero, failure = error;

  /// Never answers, so the checker's own deadline is what ends the call.
  _FakeTransport.hang() : statusCode = 0, body = '', delay = null, failure = null;

  final int statusCode;
  final String body;

  /// null means "stall forever" rather than "no delay": the two hang and reply cases are different fakes.
  final Duration? delay;
  final Object? failure;

  int calls = 0;
  String? lastUrl;

  @override
  Future<UpdateFeedResponse> fetch(String url) async {
    calls++;
    lastUrl = url;
    if (failure != null) {
      throw failure!;
    }
    final wait = delay;
    if (wait == null) {
      return Completer<UpdateFeedResponse>().future;
    }
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    return UpdateFeedResponse(statusCode: statusCode, body: body);
  }
}

const String _feed = '''
[
  {"version":"4.1.0+5100","title":"4.1.0","date":"2026-10-01","changelog":"fixes","files":[
    {"name":"pure_live-4.1.0-android.apk","url":"https://example.test/a.apk"},
    {"name":"pure_live-4.1.0-windows.zip","url":"https://example.test/w.zip"}
  ]},
  {"version":"4.0.0+5000","title":"4.0.0","date":"2026-09-01","files":[
    {"name":"pure_live-4.0.0-android.apk","url":"https://example.test/b.apk"}
  ]}
]
''';

UpdateChecker _checker(
  UpdateFeedTransport transport, {
  UpdateTarget target = UpdateTarget.android,
  Duration timeout = kDefaultUpdateFeedTimeout,
}) => UpdateChecker(
  feedUrl: 'https://example.test/releases.json',
  transport: transport,
  target: target,
  timeout: timeout,
);

void main() {
  group('UpdateChecker.check', () {
    test('test_check_newestEntry_winsAndCarriesThePlatformAsset', () async {
      final transport = _FakeTransport.reply(200, _feed);

      final result = await _checker(transport).check(AppVersion.parse('4.0.0+5000'));

      expect(transport.lastUrl, 'https://example.test/releases.json');
      expect(result.isSuccessful, isTrue);
      expect(result.entry?.version.full, '4.1.0+5100');
      expect(result.entry?.changelog, 'fixes');
      expect(result.asset?.url, 'https://example.test/a.apk');
      expect(result.decide().action, UpdateAction.available);
    });

    test('test_check_currentIsAlreadyNewest_answersNone', () async {
      final result = await _checker(_FakeTransport.reply(200, _feed)).check(AppVersion.parse('4.1.0+5100'));

      expect(result.decide().action, UpdateAction.none);
    });

    test('test_check_errorStatus_reportsTheStatusWithoutThrowing', () async {
      final result = await _checker(_FakeTransport.reply(404, 'not found')).check(AppVersion.parse('4.0.0+5000'));

      expect(result.isSuccessful, isFalse);
      expect(result.error, 'feed status 404');
      expect(result.decide().action, UpdateAction.none);
    });

    test('test_check_unparsableVersion_skipsTheRowAndTakesTheNext', () async {
      // A feed whose head row carries a non-semver version is the shape that used to poison the whole choice.
      final body = _feed.replaceFirst('4.1.0+5100', 'nightly');

      final result = await _checker(_FakeTransport.reply(200, body)).check(AppVersion.parse('3.9.0+4900'));

      expect(result.entry?.version.full, '4.0.0+5000');
    });

    test('test_check_malformedJson_reportsFailure', () async {
      final result = await _checker(_FakeTransport.reply(200, '{not json')).check(AppVersion.parse('4.0.0+5000'));

      expect(result.isSuccessful, isFalse);
      expect(result.error, isNotNull);
    });

    test('test_check_objectInsteadOfList_reportsEmptyFeed', () async {
      final result = await _checker(_FakeTransport.reply(200, '{}')).check(AppVersion.parse('4.0.0+5000'));

      expect(result.error, 'feed carried no parsable release');
    });

    test('test_check_transportThrows_reportsTheFailureInsteadOfThrowing', () async {
      final result = await _checker(_FakeTransport.failWith(StateError('no route')))
          .check(AppVersion.parse('4.0.0+5000'));

      expect(result.isSuccessful, isFalse);
      expect(result.error, contains('no route'));
    });

    test('test_check_transportNeverAnswers_hitsItsOwnDeadline', () async {
      // A short budget rather than the 15s default: the assertion is that the deadline ends the call, not
      // that it is the right number of seconds.
      final result = await _checker(
        _FakeTransport.hang(),
        timeout: const Duration(milliseconds: 30),
      ).check(AppVersion.parse('4.0.0+5000'));

      expect(result.isSuccessful, isFalse);
      expect(result.error, startsWith('feed did not answer within'));
    });

    test('test_check_slowAnswerInsideDeadline_stillSucceeds', () async {
      final transport = _FakeTransport.reply(200, _feed, delay: const Duration(milliseconds: 20));

      final result = await _checker(transport).check(AppVersion.parse('4.0.0+5000'));

      expect(result.isSuccessful, isTrue);
      expect(transport.calls, 1);
    });

    test('test_check_windowsPrefersTheAssetNamingItsPlatform', () async {
      final result = await _checker(
        _FakeTransport.reply(200, _feed),
        target: UpdateTarget.windows,
      ).check(AppVersion.parse('4.0.0+5000'));

      expect(result.asset?.url, 'https://example.test/w.zip');
    });
  });

  group('ReleaseEntry.assetFor', () {
    final entry = ReleaseEntry(
      version: AppVersion.parse('4.1.0+5100'),
      title: '4.1.0',
      date: '2026-10-01',
      assets: const <ReleaseAsset>[
        ReleaseAsset(name: 'app-android.apk', url: 'a'),
        ReleaseAsset(name: 'pure_live-windows.zip', url: 'w'),
        ReleaseAsset(name: 'other.zip', url: 'o'),
      ],
    );

    test('test_assetFor_android_takesTheApk', () {
      expect(entry.assetFor(UpdateTarget.android)?.url, 'a');
    });

    test('test_assetFor_linux_nothingBuiltForIt_answersNull', () {
      expect(entry.assetFor(UpdateTarget.linux), isNull);
    });

    test('test_assetFor_macos_nothingBuiltForIt_answersNull', () {
      expect(entry.assetFor(UpdateTarget.macos), isNull);
    });
  });
}
