// Module: test/huya_signing_test.dart
// Purpose: Pin the AntiCode recipe and the template fill that must not re-scan what it wrote.
// Author: liuchuancong
// Created: 2026-10-11
//
// The vectors are regression pins: derived from this implementation once and written down as literals, so they
// catch the recipe being edited (which fields are removed, the substitution order, the hash inputs). They are
// not an oracle from the CDN - nothing here proves Huya still accepts these. The query is compared as a parsed
// parameter map rather than as a string, because field order on the wire is not what the signature depends on.

import 'dart:convert';

import 'package:pure_live_huya/pure_live_huya.dart';
import 'package:test/test.dart';

/// base64 of `@/$1/$0-$2-$3?ws=1`, the shape the server ships in `fm`.
const String _template = 'QC8kMS8kMC0kMi0kMz93cz0x';

/// The wsSecret this implementation produces for the pinned non-wap vector below.
const String _pinnedSecret = 'b10e52a682849db4058957e8a09a99d6';

String _antiCode({String ctype = 'html', String t = '100', String wsTime = '6553f100', String? fm = _template}) =>
    Uri(queryParameters: <String, String>{if (fm != null) 'fm': fm, 'ctype': ctype, 'wsTime': wsTime, 't': t}).query;

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

Map<String, String> _parameters(String query) => Uri(query: query).queryParameters;

void main() {
  group('test_huyaSigning_buildAntiCode', () {
    test('test_buildAntiCode_matchesThePinnedNonWapVector', () {
      final signed = buildAntiCode('streamName', 1234567890123, _antiCode(), now: _now);

      expect(_parameters(signed), <String, String>{
        'ctype': 'html',
        'wsTime': '6553f100',
        't': '100',
        'wsSecret': _pinnedSecret,
        'seqid': '${1234567890123 + 1700000000000}',
        'ver': '1',
        'fs': 'bgct',
        'u': '1236867009393',
      });
    });

    test('test_buildAntiCode_dropsTheSigningMaterialFromTheEmittedQuery', () {
      // `fm` is consumed locally by the site's own player and never reaches the CDN url; leaving it in also
      // means a stale template sits next to the secret that was computed from it.
      final signed = buildAntiCode('streamName', 1234567890123, _antiCode(fm: _template), now: _now);

      expect(signed, isNot(contains('fm=')));
      expect(_parameters(signed).length, 8, reason: 'no leftover keys from the original anti code');
    });

    test('test_buildAntiCode_keepsAnUnrelatedFieldTheServerAdded', () {
      final signed = buildAntiCode('s', 1, '${_antiCode()}&future=7', now: _now);

      expect(
        _parameters(signed)['future'],
        '7',
        reason: 'signing rebuilds the known fields, it does not whitelist them away',
      );
    });

    test('test_buildAntiCode_wapCarriesUidAndUuidInsteadOfU', () {
      final signed = buildAntiCode(
        's',
        1400000000001,
        _antiCode(ctype: 'wap', t: '103'),
        now: _now,
      );
      final parameters = _parameters(signed);

      expect(parameters['uid'], '1400000000001');
      expect(parameters['uuid'], isNotNull);
      expect(parameters.containsKey('u'), isFalse, reason: 'the wap lane names the viewer differently');
      expect(int.parse(parameters['uuid']!), lessThan(4294967296));
    });

    test('test_buildAntiCode_passesThroughAnAlreadySignedAntiCode', () {
      const already = 'wsSecret=deadbeef&wsTime=6553f100&t=100';

      expect(buildAntiCode('s', 1, already, now: _now), already);
    });

    test('test_buildAntiCode_refusesAnExpiredLease', () {
      // wsTime 6553f100 is 1700000000; six minutes later the lease is gone and opening the url would 403.
      expect(
        () => buildAntiCode('s', 1, _antiCode(), now: _now.add(const Duration(minutes: 6))),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('lease expired'))),
      );
    });

    test('test_buildAntiCode_refusesAnUnparseableWsTime', () {
      expect(
        () => buildAntiCode('s', 1, _antiCode(wsTime: 'not-hex'), now: _now),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('no valid wsTime'))),
      );
    });

    test('test_buildAntiCode_refusesATemplateMissingAPlaceholder', () {
      final short = base64.encode(r'@/$1/$0-$3'.codeUnits);

      expect(
        () => buildAntiCode('s', 1, _antiCode(fm: short), now: _now),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(r'$2'))),
      );
    });
  });

  group('test_huyaSigning_helpers', () {
    test('test_fillAntiCodeTemplate_neverSignsOverWhatItJustWroteIn', () {
      // Sequential replaceFirst puts the stream in first and then hunts for `$2` again - finding the one
      // inside the room name - so the real placeholder stays unfilled and the signature means nothing.
      expect(
        fillAntiCodeTemplate(r'x$1y$0z$2w$3', calcUid: 7, stream: r'A$2B', secretHash: 'H', wsTime: 'T'),
        r'xA$2By7zHwT',
      );
    });

    test('test_fillAntiCodeTemplate_fillsOnlyTheFirstOccurrence', () {
      expect(fillAntiCodeTemplate(r'$0-$0$1$2$3', calcUid: 1, stream: 's', secretHash: 'h', wsTime: 't'), r'1-$0sht');
    });

    test('test_fillAntiCodeTemplate_refusesATemplateWithoutEveryPlaceholder', () {
      expect(
        () => fillAntiCodeTemplate(r'$0$1', calcUid: 1, stream: 's', secretHash: 'h', wsTime: 't'),
        throwsA(isA<FormatException>()),
      );
    });

    test('test_rotateViewerUid32_keepsTheHighLaneOfARealUid', () {
      expect(rotateViewerUid32(0x123456789), 0x145678923);
      expect(rotateViewerUid32(0x23456789), 0x45678923);
      expect(rotateViewerUid32(0), 0);
    });

    test('test_createFallbackViewerUid_staysInTheBandThePlayerIssues', () {
      final values = <int>{for (var i = 0; i < 300; i++) createFallbackViewerUid()};

      for (final value in values) {
        expect(value, greaterThanOrEqualTo(1400000000000));
        expect(value, lessThan(1500000100000));
      }
      expect(values.length, greaterThan(1), reason: 'it is a nonce, not a constant');
    });
  });
}
