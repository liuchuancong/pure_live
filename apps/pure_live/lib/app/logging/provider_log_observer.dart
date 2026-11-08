import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/logging/app_log.dart' show appLog;

/// The provider tree's own log: a provider that fails (a FutureProvider whose
/// read threw, an async notifier that errored) announces it here, so a page
/// showing 「打开失败」 has a console line naming the cause. Errors the page
/// catches and re-reports already log on their own paths.
final class LogProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final provider = context.provider;
    final name = provider.name ?? provider.runtimeType.toString();
    appLog.forCategory('providers.$name').error(
      'provider failed',
      fields: {'provider': name},
      error: error,
      stackTrace: stackTrace,
    );
  }
}
