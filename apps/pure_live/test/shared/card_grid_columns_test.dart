import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/grids/card_grid.dart';

/// The wall's arithmetic: the columns a width takes by itself or under the
/// viewer's pin (never fewer than the width says, never more than fit), the
/// share one column then gets — hair included, so the grid never tips into
/// one more — the list's whole rows, the feed's fewest columns that keep a
/// card in range, and the viewer's own count speaking on a phone.
void main() {
  group('the pin', () {
    test('a pin raises the count to what still fits, and a low pin changes nothing', () {
      expect(pinnedColumnsForWidth(1000, spacing: 16, pinned: 0, base: 3, minWidth: 220), 3); // no pin
      expect(pinnedColumnsForWidth(1000, spacing: 16, pinned: -2, base: 3, minWidth: 220), 3);
      expect(pinnedColumnsForWidth(0, spacing: 16, pinned: 5, base: 3, minWidth: 220), 3);

      expect(pinnedColumnsForWidth(1000, spacing: 16, pinned: 5, base: 3, minWidth: 220), 4); // three fit, four asked
      expect(pinnedColumnsForWidth(1000, spacing: 16, pinned: 9, base: 3, minWidth: 220), 4); // the fit caps it
      expect(pinnedColumnsForWidth(1000, spacing: 16, pinned: 2, base: 3, minWidth: 220), 3); // a low pin never thins
    });
  });

  group('the share', () {
    test('one column gets its even share, plus the hair that keeps the count', () {
      expect(columnExtentForWidth(368, 2, 16), closeTo(176.01, 1e-9));
      expect(columnExtentForWidth(368, 1, 16), closeTo(368.01, 1e-9));
    });
  });

  group('the list rows', () {
    test('as many whole rows of 360 as the width holds', () {
      expect(listCardColumnsForWidth(0), 1);
      expect(listCardColumnsForWidth(360), 1);
      expect(listCardColumnsForWidth(800), 2);
      expect(listCardColumnsForWidth(1500), 4);

      expect(listCardExtentForWidth(0), 360.0); // no content: the measure itself
      expect(listCardExtentForWidth(360), closeTo(360.01, 1e-9));
      expect(listCardExtentForWidth(800), closeTo(394.01, 1e-9));
      expect(listCardExtentForWidth(1500), closeTo(366.01, 1e-9));
    });
  });

  group('the feed cards', () {
    test('the fewest columns keep a card within its range', () {
      expect(browseCardColumnsForWidth(0), 1);
      expect(browseCardColumnsForWidth(300), 1); // a phone: one wide card
      expect(browseCardColumnsForWidth(450), 1); // a second card would sit under the floor
      expect(browseCardColumnsForWidth(460), 2);
      expect(browseCardColumnsForWidth(1000), 3);
      expect(browseCardColumnsForWidth(4000), 12); // however wide, the count caps
    });

    test('the share follows the count the columns chose', () {
      expect(browseCardExtentForWidth(0), 340.0);
      expect(browseCardExtentForWidth(300), closeTo(300.01, 1e-9));
      expect(browseCardExtentForWidth(460), closeTo(222.01, 1e-9));
      expect(browseCardExtentForWidth(1000), closeTo(322.6767, 0.001));
      expect(browseCardExtentForWidth(4000), closeTo(318.6767, 0.001));
    });
  });

  group("the viewer's own count", () {
    test("a phone's width speaks directly, a wider one through the pin", () {
      const phone = (crossSpacing: 16.0, mainSpacing: 16.0, gridColumns: 0, phoneColumns: 2);
      const pinned = (crossSpacing: 16.0, mainSpacing: 16.0, gridColumns: 5, phoneColumns: 2);
      const nopin = (crossSpacing: 16.0, mainSpacing: 16.0, gridColumns: 0, phoneColumns: 2);

      expect(browseSettingsExtentForWidth(0, phone), 340.0); // no content: the measure itself

      // under two cards' floor, the phone's own count splits the row
      expect(browseSettingsExtentForWidth(400, phone), closeTo(192.01, 1e-9));

      // the width's own count stands when the viewer pinned nothing
      expect(browseSettingsExtentForWidth(1000, nopin), closeTo(322.6767, 0.001));

      // a pin above the width's count raises it, to what still fits
      expect(browseSettingsExtentForWidth(1000, pinned), closeTo(238.01, 1e-9));
    });
  });
}
