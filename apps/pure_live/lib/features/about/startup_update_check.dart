import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/about/version_controller.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The launch-time update check — the reference's `HomePage._checkForStartupUpdate`.
///
/// Mounted once by the shell route, it waits out the cold start (the reference
/// deliberately runs this low-priority work after the visible room has first
/// use of the network) and, when `autoCheckUpdate` is on, runs the shared
/// version check. A newer release prompts — offering the version page, the
/// same door the about page opens — and the prompt fires at most once per run:
/// navigating back to the shell must not nag again.
final class StartupUpdateCheck extends ConsumerStatefulWidget {
  /// Wraps [child].
  const new({required this.child, this.checkDelay = const Duration(milliseconds: 800), super.key});

  /// The shell below.
  final Widget child;

  /// How long after the first frame the check waits; a test seam.
  final Duration checkDelay;

  @override
  ConsumerState<StartupUpdateCheck> createState() => _StartupUpdateCheckState();
}

final class _StartupUpdateCheckState extends ConsumerState<StartupUpdateCheck> {
  static bool _promptedThisRun = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(widget.checkDelay, _check);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _check() async {
    if (!mounted || !ref.read(appPreferencesProvider).autoCheckUpdate) {
      return;
    }
    // Reading the notifier builds the controller, whose first build already
    // runs a check; awaiting the explicit call settles on a settled state
    // rather than racing the microtask it schedules.
    final controller = ref.read(versionControllerProvider.notifier);
    await controller.check();
    final state = ref.read(versionControllerProvider);
    if (!mounted || _promptedThisRun || !state.hasUpdate || state.releases.isEmpty) {
      return;
    }
    _promptedThisRun = true;
    await _prompt(state.releases.first.tag);
  }

  Future<void> _prompt(String tag) async {
    final go = await showPureDialog<bool>(
      context: context,
      title: context.t.about.newVersion,
      child: Text(context.t.about.startupUpdateBody(tag: tag)),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop(true)),
      ],
    );
    if (go == true && mounted) {
      unawaited(const VersionRoute().push<void>(context));
    }
  }
}
