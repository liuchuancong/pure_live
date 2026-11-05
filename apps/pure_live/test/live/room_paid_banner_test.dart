import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/room/chat/paid_banner.dart';

const Color _surface = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF101010);

/// WCAG's contrast ratio - the same floor the chat column holds its name
/// colours to, used here to say how much of the platform is left in a fill.
double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  group('platformColor', () {
    test('reads what a platform writes', () {
      expect(platformColor('#c1c1ff'), const Color(0xFFC1C1FF));
      expect(platformColor('292a60'), const Color(0xFF292A60));
      expect(platformColor('  #c1c1ff  '), const Color(0xFFC1C1FF));

      // The eight-digit form is the platform's own alpha, kept as written.
      expect(platformColor('#80FF0000'), const Color(0x80FF0000));
    });

    test('refuses anything that is not a colour', () {
      // A mis-read string must fall back to the theme, not paint the column
      // grey or black.
      expect(platformColor(''), isNull);
      expect(platformColor('red'), isNull);
      expect(platformColor('rgb(1,2,3)'), isNull);
      expect(platformColor('#12345'), isNull);
      expect(platformColor('#zzzzzz'), isNull);
    });
  });

  group('paidBanner', () {
    test('keeps the platform hue and the theme contrast', () {
      final banner = paidBanner('#c1c1ff', _surface);
      final raw = platformColor('#c1c1ff')!;

      // Held back toward the surface it sits on: the hue survives - the fill is
      // not the surface - but it is lighter than the colour the platform would
      // have painted, which is what keeps the line's own text readable.
      expect(banner, isNotNull);
      expect(_contrast(banner!.fill, _surface), greaterThan(1.0));
      expect(_contrast(banner.fill, _surface), lessThan(_contrast(raw, _surface)));

      // The edge carries more of the platform than the fill does, so the banner
      // still reads as one thing with a border.
      expect(_contrast(banner.edge, _surface), greaterThan(_contrast(banner.fill, _surface)));
    });

    test('a paid line the platform cannot describe keeps the theme', () {
      expect(paidBanner('', _surface), isNull);
    });

    test('the column text stays readable on the fill', () {
      final banner = paidBanner('#246488', _surface)!;

      // The whole reason the colour is lerped rather than painted: dark ink on
      // the platform's own tint still clears the contrast floor.
      expect(_contrast(banner.fill, _ink), greaterThan(4.5));
    });
  });

  group('paidBannerGradient', () {
    test('the money still decides how much of the platform shows', () {
      final light = paidBannerGradient(top: '#c1c1ff', bottom: '#292a60', surface: _surface, weight: 0.05)!;
      final heavy = paidBannerGradient(top: '#c1c1ff', bottom: '#292a60', surface: _surface, weight: 0.16)!;

      expect(_contrast(heavy.colors.first, _surface), greaterThan(_contrast(light.colors.first, _surface)));

      // And the tail is the platform's second colour, not the first repeated:
      // the deep navy shows at the bottom end of the card.
      expect(light.colors.last, isNot(light.colors.first));
    });

    test('a card with only a top colour keeps one hue', () {
      final banner = paidBannerGradient(top: '#c1c1ff', bottom: '', surface: _surface)!;

      expect(banner.colors.first, isNot(_surface));
      expect(banner.colors.last, banner.colors.first);
    });

    test("a card with no top colour is the caller's theme fill", () {
      expect(paidBannerGradient(top: '', bottom: '#292a60', surface: _surface), isNull);
    });
  });
}
