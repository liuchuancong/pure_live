import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The title slot every page composes its header controls into — the live
/// room's status tabs, the discovery pages' site picker and search — must
/// reach the screen under every language that draws a bar of its own.
///
/// Fluent composes its header from the library's own primitives and used to
/// read only the `title` string, silently dropping the widget (the languages
/// that host Material's AppBar never had the problem). macOS is documented
/// out: its `ToolBar` centres the title and a wide widget there overflows.
void main() {
  testWidgets('the fluent bar renders the title widget', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const PureConfigProvider(
        config: UiConfig(language: PureDesignLanguage.fluent),
        child: MaterialApp(
          home: PureScaffold(
            appBar: PureAppBar(
              title: 'text title',
              titleWidget: Row(children: [Text('widget title')]),
            ),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('widget title'), findsOneWidget);
    expect(find.text('text title'), findsNothing);
    await tester.pumpAndSettle();
  });
}
