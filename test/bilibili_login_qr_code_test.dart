import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/account/bilibili/bilibili_login_qr_code.dart';
import 'package:qr/qr.dart';

void main() {
  testWidgets('Bilibili login QR renders the current qr matrix at a fixed size', (tester) async {
    const data = 'https://passport.bilibili.com/h5-app/passport/login/scan?qrkey=test';
    final matrix = QrImage(QrCode(payload: QrPayload.fromString(data), errorCorrectLevel: QrErrorCorrectLevel.low));
    expect(matrix.moduleCount, greaterThan(20));
    expect(matrix.isDark(0, 0), isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BilibiliLoginQrCode(data: data, size: 180)),
      ),
    );

    final qr = find.byKey(const ValueKey('bilibili-login-qr-code'));
    expect(qr, findsOneWidget);
    expect(tester.getSize(qr), const Size(180, 180));
    expect(find.descendant(of: qr, matching: find.byType(CustomPaint)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
