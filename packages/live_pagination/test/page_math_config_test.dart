import 'package:live_pagination/live_pagination.dart';
import 'package:test/test.dart';

void main() {
  group('PageMath', () {
    test('total pages rounds up and tolerates an unknown total', () {
      expect(PageMath.totalPages(null, 20), isNull);
      expect(PageMath.totalPages(0, 20), 0);
      expect(PageMath.totalPages(1, 20), 1);
      expect(PageMath.totalPages(20, 20), 1);
      expect(PageMath.totalPages(21, 20), 2);
      expect(PageMath.totalPages(45, 20), 3);
    });

    test('clamp never leaves the valid range', () {
      expect(PageMath.clampPage(-3, 5), 1);
      expect(PageMath.clampPage(3, null), 3);
      expect(PageMath.clampPage(9, 5), 5);
    });

    test('slice returns the requested window', () {
      final data = List.generate(45, (i) => i);
      expect(PageMath.slice(data, 1, 20), hasLength(20));
      expect(PageMath.slice(data, 3, 20), [40, 41, 42, 43, 44]);
      expect(PageMath.slice(data, 4, 20), isEmpty);
    });
  });

  group('PaginationViewConfig', () {
    test('back-to-top follows the offset threshold', () {
      const config = PaginationViewConfig.defaults;
      expect(config.shouldShowBackToTop(399), isFalse);
      expect(config.shouldShowBackToTop(401), isTrue);
    });

    test('back-to-bottom hides at the edge and near the bottom', () {
      const config = PaginationViewConfig.defaults;
      expect(config.shouldShowBackToBottom(0, 2000, atEdge: true), isTrue);
      expect(config.shouldShowBackToBottom(2000, 2000, atEdge: true), isFalse);
      expect(config.shouldShowBackToBottom(1800, 2000, atEdge: false), isFalse);
      expect(config.shouldShowBackToBottom(1000, 2000, atEdge: false), isTrue);
    });

    test('jump animation scales with distance and clamps', () {
      const config = PaginationViewConfig.defaults;
      // 180 + 0/8 = 180 -> clamped to the 220 ms floor.
      expect(config.jumpAnimationDuration(0), const Duration(milliseconds: 220));
      // 180 + 1600/8 = 380 ms — inside the window.
      expect(config.jumpAnimationDuration(1600), const Duration(milliseconds: 380));
      // 180 + 100000/8 = 12680 -> clamped to the 520 ms ceiling.
      expect(config.jumpAnimationDuration(100000), const Duration(milliseconds: 520));
    });

    test('layout decision matches the legacy breakpoint', () {
      const config = PaginationViewConfig.defaults;
      expect(config.isDesktopLayout(1920, isMobile: false), isTrue);
      expect(config.isDesktopLayout(500, isMobile: false), isFalse);
      expect(config.isDesktopLayout(1920, isMobile: true), isFalse);
      expect(config.isDesktopLayout(680, isMobile: false), isFalse, reason: 'strictly above');
    });

    test('page size honours layout and the user choice survives', () {
      const config = PaginationViewConfig.defaults;
      expect(config.pageSizeFor(isDesktop: false), 20);
      expect(config.pageSizeFor(isDesktop: true), 40);
      expect(config.pageSizeFor(isDesktop: true, userPageSize: 80), 80);
      expect(config.pageSizeFor(isDesktop: true, userPageSize: 0), 40, reason: 'invalid input');

      expect(config.pageSizeOptionsIncluding(40), [20, 40, 60, 80]);
      expect(config.pageSizeOptionsIncluding(50), [20, 40, 50, 60, 80]);
    });
  });
}
