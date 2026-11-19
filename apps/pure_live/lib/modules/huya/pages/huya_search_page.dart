import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/huya/controller/huya_video.dart';
import 'package:pure_live/modules/huya/widgets/huya_widgets.dart';
import 'package:pure_live/shared/shared.dart';

/// The station's search: its own field over the index, the result grid, and —
/// for a word the index answered with nothing — the station's own completions
/// to try instead. Reached from the module's 搜索 entry and from the shell's
/// toolbar, which hands a word in as the opening query.
/// The search head's column: a wide window reads a field and its verbs in
/// one line, the settings page's own measure — not a field stretched
/// across the window.
const double _kSearchHeadMaxWidth = 960;

final class HuyaSearchPage extends ConsumerStatefulWidget {
  /// The search page.
  const HuyaSearchPage({super.key});

  @override
  ConsumerState<HuyaSearchPage> createState() => _HuyaSearchPageState();
}

final class _HuyaSearchPageState extends ConsumerState<HuyaSearchPage> {
  final TextEditingController _field = TextEditingController();
  String _word = '';

  @override
  void initState() {
    super.initState();
    // A word handed by the shell's toolbar opens this page already searching.
    final handed = ref.read(huyaInlineSearchProvider);
    if (handed != null && handed.isNotEmpty) {
      _word = handed;
      _field.text = handed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(huyaSearchProvider.notifier).search(handed));
      });
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _run(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    setState(() => _word = trimmed);
    unawaited(ref.read(huyaSearchProvider.notifier).search(trimmed));
    unawaited(ref.read(huyaSearchHistoryProvider.notifier).record(trimmed));
  }

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
    final state = ref.watch(huyaSearchProvider);
    final controller = ref.read(huyaSearchProvider.notifier);
    return PageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kSearchHeadMaxWidth),
                child: DsSearchField(
                  controller: _field,
                  autofocus: _word.isEmpty,
                  placeholder: t.huya.searchHint,
                  semanticLabel: t.huya.searchHint,
                  onSubmitted: _run,
                ),
              ),
            ),
          ),
          if (_word.isEmpty)
            Expanded(
              // The page's first face: the words this device searched, each
              // a chip that asks again — the other stations' 搜索历史 wall.
              // A device with no searches keeps the bare invitation.
              child: _HuyaSearchIdle(onPick: _run),
            )
          else ...[
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
              child: Text(
                t.huya.searchResults(count: state.total, word: _word),
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
            // A word with no result still has the station's own completions to
            // offer; each replaces the query and searches again.
            if (!state.loading && state.videos.isEmpty && state.error == null)
              Builder(
                builder: (context) {
                  final words = ref.watch(huyaSearchSuggestProvider(_word)).value ?? const <String>[];
                  if (words.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s8,
                      children: [
                        Text(t.huya.suggestTitle, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                        Wrap(
                          spacing: DsSpace.s8,
                          runSpacing: DsSpace.s8,
                          children: [
                            for (final suggestion in words.take(8))
                              DsChip(
                                label: Text(suggestion),
                                selected: false,
                                onChanged: (on) {
                                  _field.text = suggestion;
                                  _run(suggestion);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            Expanded(
              child: HuyaVideoGrid(
                videos: state.videos,
                loading: state.loading,
                hasMore: false,
                onLoadMore: () async {},
                onOpen: _open,
                error: state.error?.message,
                onRetry: () => unawaited(controller.search(_word)),
                emptyTitle: t.huya.searchEmpty,
                emptyDescription: t.huya.searchEmptyDescription,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The search page's first face: the words this device searched, each one a
/// chip that asks again, with the wall's own way out beside it — the same
/// 搜索历史 wall the other stations keep.
final class _HuyaSearchIdle extends ConsumerWidget {
  const _HuyaSearchIdle({required this.onPick});

  final ValueChanged<String> onPick;

  /// Asks before the whole wall goes: a full clear cannot be undone, and
  /// the button sits beside chips a slip of the finger can reach.
  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.common.clearSearchHistoryTitle,
      description: t.common.clearSearchHistoryBody,
      confirmLabel: t.huya.searchHistoryClear,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    unawaited(ref.read(huyaSearchHistoryProvider.notifier).clear());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final history = ref.watch(huyaSearchHistoryProvider);
    if (history.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.search), title: Text(t.huya.searchEmpty)),
      );
    }
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kSearchHeadMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.huya.searchHistory, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                const SizedBox(height: DsSpace.s8),
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: DsSpace.s8,
                        runSpacing: DsSpace.s8,
                        children: [
                          for (final word in history)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: DsSpace.s4,
                              children: [
                                DsChip(label: Text(word), selected: false, onChanged: (_) => onPick(word)),
                                DsButton.icon(
                                  variant: DsButtonVariant.ghost,
                                  size: DsSize.sm,
                                  semanticLabel: t.huya.searchHistoryRemove(word: word),
                                  onPressed: () => ref.read(huyaSearchHistoryProvider.notifier).remove(word),
                                  icon: const DsIcon(DsIcons.x, size: 14),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.ghost,
                      onPressed: () => unawaited(_clearHistory(context, ref)),
                      child: Text(t.huya.searchHistoryClear),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
