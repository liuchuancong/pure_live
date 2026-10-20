import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:shimmer/shimmer.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The list feeds' first-load placeholder, drawn per the loading-style
/// preference: the bone grid shimmering (the default), a centred spinner,
/// or nothing at all.
///
/// [delegateBuilder] receives the width the placeholder settles at, so the
/// bones tile exactly like the grid they stand in for — content replaces
/// the placeholder without a layout jump.
final class FeedLoadingPlaceholder extends ConsumerWidget {
  /// A placeholder tiling like [delegateBuilder]'s grid.
  const new({
    required this.delegateBuilder,
    this.rows = 3,
    this.padding = const EdgeInsets.all(PureSpacing.sm),
    super.key,
  });

  /// The grid delegate the bones lay into, for the resolved width.
  final SliverGridDelegateWithFixedCrossAxisCount Function(double width) delegateBuilder;

  /// How many rows of bones to draw.
  final int rows;

  /// The grid's own padding. It must match the inset the delegate took back out
  /// of the width, or the bones stand wider than the cards they replace.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(loadingStyleProvider)) {
      case LoadingStyle.none:
        return const SizedBox.shrink();
      case LoadingStyle.spinner:
        return const Center(child: PureLoading());
      case LoadingStyle.shimmer:
        return LayoutBuilder(
          builder: (context, constraints) {
            final theme = PureTheme.of(context);
            return Shimmer.fromColors(
              baseColor: theme.colors.fillTertiary,
              highlightColor: theme.colors.fillQuaternary,
              child: Skeletonizer(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: padding,
                  gridDelegate: delegateBuilder(constraints.maxWidth),
                  itemCount: delegateBuilder(constraints.maxWidth).crossAxisCount * rows,
                  itemBuilder: (context, index) => const RoomBoneTile(),
                ),
              ),
            );
          },
        );
    }
  }
}

/// One bone: a 16:9 cover block over an avatar-and-two-lines caption — the
/// room card's silhouette, shared by every grid that loads one.
///
/// Fixed-height bars rather than placeholder letters: a skeleton has to fit
/// its tile in every design language and text scale, and a `Text('XXXX')`
/// is measured by whichever of those is active.
final class RoomBoneTile extends StatelessWidget {
  /// One bone of a room grid.
  const new({super.key});

  @override
  Widget build(BuildContext context) => PureCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(color: Colors.white24),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 12,
                      width: double.infinity,
                      child: ColoredBox(color: Colors.white24),
                    ),
                    SizedBox(height: 6),
                    SizedBox(width: 96, height: 10, child: ColoredBox(color: Color(0x26FFFFFF))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Arms a feed with the refresh settings' own timers: the foreground
/// interval, and the refresh-on-resume threshold.
///
/// Mix onto a `ConsumerState` and answer [feedRefresh]; [feedVisible] says
/// whether the feed is the one on screen (a kept-alive tab behind the
/// current one skips its ticks). The timers re-arm whenever the refresh
/// preferences move, so dragging the chooser around costs no rebuilds.
mixin FeedAutoRefresh<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _intervalTimer;
  StreamSubscription<Duration>? _resumes;
  StreamSubscription<AppPreferences>? _preferenceChanges;

  /// The refresh to run on a tick or a qualifying resume.
  Future<void> feedRefresh();

  /// Whether this feed is the one on screen; hidden feeds skip their ticks.
  bool get feedVisible => true;

  @override
  void initState() {
    super.initState();
    _armInterval();
    _resumes = ref.read(appResumeSignalsProvider).resumes.listen(_onResume);
    _preferenceChanges = ref.read(appPreferencesStoreProvider).changes.listen((_) => _armInterval());
  }

  @override
  void dispose() {
    _intervalTimer?.cancel();
    unawaited(_resumes?.cancel());
    unawaited(_preferenceChanges?.cancel());
    super.dispose();
  }

  void _armInterval() {
    _intervalTimer?.cancel();
    _intervalTimer = null;
    final interval = ref.read(feedRefreshProvider).interval;
    if (interval == null) {
      return;
    }
    _intervalTimer = Timer.periodic(interval, (_) {
      if (feedVisible) {
        unawaited(feedRefresh());
      }
    });
  }

  void _onResume(Duration away) {
    final settings = ref.read(feedRefreshProvider);
    if (!settings.refreshOnResume || away < settings.resumeThreshold) {
      return;
    }
    if (feedVisible) {
      unawaited(feedRefresh());
    }
  }
}
