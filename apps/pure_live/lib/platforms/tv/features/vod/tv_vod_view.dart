import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart' show VodFailure, VodVideo;
import 'package:pure_live/features/vod/vod_page.dart' show vodClientProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_pill.dart';
import 'package:pure_live/system/navigation/route_paths.dart' show RoutePath;
import 'package:pure_uikit/pure_uikit.dart';

/// 视频 on the ten-foot screen: a search pill row and the hits as a focus
/// wall of cover tiles; a tile opens the same player page the phone list
/// opens, so playback stays one seam.
final class TvVodView extends ConsumerWidget {
  /// The TV video pane.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _TvVodBody();
  }
}

final class _TvVodBody extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TvVodBody> createState() => _TvVodBodyState();
}

final class _TvVodBodyState extends ConsumerState<_TvVodBody> {
  final TextEditingController _keyword = TextEditingController();
  List<VodVideo> _results = const [];
  bool _loading = false;
  Object? _failure;

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty || _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await ref.read(vodClientProvider).search(keyword);
      if (mounted) {
        setState(() => _results = page.videos);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failure = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _open(VodVideo video) {
    unawaited(
      context.push<void>(
        Uri(path: RoutePath.vodPlay, queryParameters: {'videoId': video.id, 'title': video.title}).toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.vod.title, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(width: 24),
                Expanded(
                  child: PureTextField(
                    key: const ValueKey('tv-vod-search'),
                    controller: _keyword,
                    placeholder: t.vod.searchHint,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                  ),
                ),
                const SizedBox(width: 12),
                TvPill(key: const ValueKey('tv-vod-go'), label: t.vod.search, onTap: () => unawaited(_search())),
              ],
            ),
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _failure is VodFailure ? (_failure! as VodFailure).message : t.errors.network,
                style: theme.text.bodySmall.copyWith(color: theme.colors.error),
              ),
            ),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: PureSpinner(size: 40))
                : _results.isEmpty
                ? Center(
                    child: PureEmpty(title: t.vod.empty, icon: Icons.videocam_outlined),
                  )
                : FocusTraversalGroup(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1600 ? 5 : 4;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(48, 16, 48, 48),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 0.86,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (context, index) => _TvVideoTile(
                            key: ValueKey('tv-vod-${_results[index].id}'),
                            video: _results[index],
                            autofocus: index == 0,
                            onTap: () => _open(_results[index]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One video tile: the cover, the duration, the title; an accent ring and a
/// lift on focus.
final class _TvVideoTile extends StatefulWidget {
  const new({required this.video, required this.onTap, this.autofocus = false, super.key});

  final VodVideo video;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TvVideoTile> createState() => _TvVideoTileState();
}

final class _TvVideoTileState extends State<_TvVideoTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final cover = widget.video.coverUrl;
    final duration = widget.video.duration;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) {
        if (value != _focused) {
          setState(() => _focused = value);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _focused ? theme.colors.primary : Colors.transparent, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover == null)
                          ColoredBox(color: theme.colors.fillQuaternary)
                        else
                          CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => ColoredBox(color: theme.colors.fillQuaternary),
                          ),
                        if (duration != null)
                          PositionedDirectional(
                            bottom: 6,
                            end: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xCC000000),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _label(duration),
                                style: theme.text.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    color: theme.colors.bgContainer,
                    child: Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.text.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _label(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }
}
