import 'package:flutter/widgets.dart';

/// A router that goes nowhere, so a host can be pumped without the app's
/// `GoRouter` — these tests assert which library hosts the tree, not how it
/// navigates. [child] is what the single route draws, so a control can be put
/// inside the host rather than beside it.
RouterConfig<Object> stubRouterConfig({Widget? child}) => RouterConfig<Object>(
  routeInformationProvider: _StubProvider(),
  routeInformationParser: _StubParser(),
  routerDelegate: _StubDelegate(child),
);

class _StubProvider extends RouteInformationProvider with ChangeNotifier {
  @override
  RouteInformation get value => RouteInformation(uri: Uri.parse('/'));
}

class _StubParser extends RouteInformationParser<Object> {
  @override
  Future<Object> parseRouteInformation(RouteInformation routeInformation) async => const Object();

  @override
  RouteInformation? restoreRouteInformation(Object configuration) => RouteInformation(uri: Uri.parse('/'));
}

class _StubDelegate extends RouterDelegate<Object> with ChangeNotifier {
  new(this.child);

  final Widget? child;

  @override
  Future<Object?> get currentConfiguration async => null;

  @override
  Widget build(BuildContext context) => child ?? const Placeholder();

  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  Future<bool> popRoute() async => false;
}
