import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/router.dart';
import 'package:pure_live/storage/services.dart';

/// The booted composition root, overridden with its value in `main()` —
/// everything below the `ProviderScope` reads the same instance instead of
/// receiving it through constructor chains.
final appServicesProvider = Provider<AppServices>((ref) => throw UnimplementedError('overridden in main()'));

/// The application router. One instance for the process; navigation state is
/// its own, so a theme change re-skins but never resets the stack.
final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter());
