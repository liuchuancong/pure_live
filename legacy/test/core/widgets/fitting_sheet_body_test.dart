import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/widgets/fitting_sheet_body.dart';

/// `showModalBottomSheet` 把弹层限死在视口的 90%，内容是 loose 约束。
/// 录像页的 ⋮ 弹层在矮屏手机上超出的正是 44 像素——溢出在 Flutter 里不是异常，
/// 只在渲染阶段抛断言，所以这里既测「不炸」也测「滚得到的行才算看得见」，
/// 以及「装得下时不撑满」。401.8 / 446.8 取自那份设备日志，不是编出来的前提。
const double _sheetMaxHeight = 401.8;
const double _testScreenHeight = 600;

Widget _host({required double maxHeight, required List<Widget> children}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FittingSheetBody(children: children),
      ),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable)).position;

void main() {
  group('FittingSheetBody', () {
    testWidgets('装不下时滚动而不是溢出', (tester) async {
      await tester.pumpWidget(
        _host(maxHeight: _sheetMaxHeight, children: [const SizedBox(key: Key('content'), height: 446.8)]),
      );

      expect(tester.takeException(), isNull);
      final position = _position(tester);
      expect(position.maxScrollExtent, moreOrLessEquals(45, epsilon: 0.01));

      // 修好之前，超出的那 45 像素是画不出来的；滚到底后整段内容必须落进视口。
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final viewportTop = _testScreenHeight - _sheetMaxHeight;
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, moreOrLessEquals(viewportTop - 45, epsilon: 0.01));
      expect(tester.getBottomLeft(find.byKey(const Key('content'))).dy, lessThanOrEqualTo(_testScreenHeight + 0.01));
    });

    testWidgets('装得下时保持内容高度，不撑满 90%', (tester) async {
      await tester.pumpWidget(_host(maxHeight: 600, children: [const SizedBox(height: 100)]));

      expect(tester.getSize(find.byType(FittingSheetBody)).height, moreOrLessEquals(100, epsilon: 0.01));
      expect(_position(tester).maxScrollExtent, 0);
    });

    testWidgets('行数变化后最后一行仍然滚得到', (tester) async {
      // 弹幕那一行只在录像带弹幕时出现，所以弹层有两种高度，两种都要能到底。
      for (final extra in <double>[0, 200]) {
        await tester.pumpWidget(
          _host(
            maxHeight: _sheetMaxHeight,
            children: [
              const SizedBox(height: 200),
              SizedBox(height: 200 + extra),
              const SizedBox(key: Key('last'), height: 60),
            ],
          ),
        );

        final position = _position(tester);
        expect(position.maxScrollExtent, moreOrLessEquals(58.2 + extra, epsilon: 0.01));

        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(tester.getBottomLeft(find.byKey(const Key('last'))).dy, lessThanOrEqualTo(_testScreenHeight + 0.01));
      }
    });
  });
}
