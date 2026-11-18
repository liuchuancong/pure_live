import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_material.dart';
import 'package:pure_live/modules/huya/widgets/huya_widgets.dart';
import 'package:pure_live/shared/shared.dart';

/// The station's 素材库, read over the library's own server-rendered pages
/// instead of an embedded web view: the landing week's picks, one stand at a
/// time, and the library's own search, all as rows of the same grid the
/// station's other pages open their videos with. A clip's `vid` is the video
/// site's own, so opening one rides the player unchanged.
///
/// The library renders each shelf as one whole page and walks no pages — that
/// is how the station ships it — so the page asks once per shelf and the rows
/// it answers are the pool there is.
final class HuyaMaterialPage extends ConsumerStatefulWidget {
  /// The material library.
  const HuyaMaterialPage({super.key});

  @override
  ConsumerState<HuyaMaterialPage> createState() => _HuyaMaterialPageState();
}

final class _HuyaMaterialPageState extends ConsumerState<HuyaMaterialPage> {
  final TextEditingController _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(huyaMaterialProvider.notifier).open());
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _run(String word) => unawaited(ref.read(huyaMaterialProvider.notifier).search(word));

  void _open(String id) {
    if (id.isEmpty) return;
    unawaited(context.push('/huya/$id'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaMaterialProvider);
    final controller = ref.read(huyaMaterialProvider.notifier);
    final searching = state.word.isNotEmpty;
    return PageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
            child: DsSearchField(
              controller: _field,
              placeholder: t.huya.materialSearchHint,
              semanticLabel: t.huya.materialSearchHint,
              onSubmitted: _run,
            ),
          ),
          // The stands ride the same chip strip the station's listings walk;
          // 精选 leads, the landing page the library itself opens with. A
          // search keeps the strip visible, so leaving the answer is one tap
          // back onto the stand it began at.
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: inset),
              itemCount: state.channels.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s8),
              itemBuilder: (context, index) {
                final hot = index == 0;
                final channel = hot ? null : state.channels[index - 1];
                final id = hot ? '' : channel!.id;
                final selected = !searching && state.channelId == id;
                return DsChip(
                  label: Text(hot ? t.huya.materialHot : channel!.label),
                  selected: selected,
                  onChanged: (on) {
                    if (!on) return;
                    _field.clear();
                    unawaited(hot ? controller.backToHot() : controller.select(channel!));
                  },
                );
              },
            ),
          ),
          if (searching)
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
              child: Text(
                t.huya.searchResults(count: state.videos.length, word: state.word),
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
          Expanded(
            child: HuyaVideoGrid(
              videos: state.videos,
              loading: state.loading,
              hasMore: false,
              onLoadMore: () async {},
              onOpen: _open,
              error: state.error?.message,
              onRetry: () => unawaited(controller.retry()),
              emptyTitle: searching ? t.huya.searchEmpty : t.huya.materialEmpty,
              emptyDescription: searching ? t.huya.searchEmptyDescription : t.huya.emptyDescription,
            ),
          ),
        ],
      ),
    );
  }
}
