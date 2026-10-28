import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/music/controller/music_sources.dart';
import 'package:pure_live/l10n/translations.dart';

/// The music module's views. The reference's rail — 搜索 / 歌单 / 排行榜 /
/// 我的列表 — is what the module's menu lists, so each view is one entry and
/// the page opens on the one the entry names.
enum MusicView {
  /// The song library: songs as a grid that pages in.
  library,

  /// Songlists: the sources' curated lists, the reference's 歌单.
  songlists,

  /// Charts: the sources' ranked lists, the reference's 排行榜.
  toplists,

  /// The viewer's own lists — collected songs and lists, the 我的列表.
  mine;

  /// The view's icon, on its segment and in its empty state.
  DsIconData get icon => switch (this) {
    MusicView.library => DsIcons.discAlbum,
    MusicView.songlists => DsIcons.listMusic,
    MusicView.toplists => DsIcons.chartColumn,
    MusicView.mine => DsIcons.library,
  };
}

/// The music module's entry: the module's views behind a segment switch,
/// each honest about its state while no music source feeds the module yet.
///
/// The playback plumbing already sits in the business packages (the VOD
/// source's audio-only address, the play queue, the lyric lookup), but no
/// source browses a music library today, so every view says what will live
/// here instead of paging in placeholder songs or a loading row that never
/// loads.
final class MusicPage extends StatefulWidget {
  /// The music module's entry page, opening on [view].
  const MusicPage({this.view = MusicView.library, super.key});

  /// The view the page opens on; the module's menu names it.
  final MusicView view;

  @override
  State<MusicPage> createState() => _MusicPageState();
}

final class _MusicPageState extends State<MusicPage> {
  /// The view the page is showing.
  late MusicView _view = widget.view;

  @override
  void didUpdateWidget(MusicPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the menu moves between the module's
    // entries, so a new entry has to move the page to its view.
    if (widget.view != _view) setState(() => _view = widget.view);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ModuleHeader(),
        ),
        Expanded(child: _ViewBody(view: _view)),
      ],
    );
  }
}

/// The module's mark: the music note in a tinted tile, the module's name,
/// and one line on where the module stands — the page's honest headline,
/// which counts the imported sources as soon as any are enabled.
final class _ModuleHeader extends ConsumerWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final enabled = ref.watch(musicSourcesProvider).where((source) => source.enabled).length;
    return Row(
      spacing: DsSpace.s12,
      children: [
        Container(
          width: theme.sizes.md,
          height: theme.sizes.md,
          decoration: DsBoxDecoration(
            color: colors.accentTint,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
          ),
          child: Center(
            child: DsIcon(DsIcons.music, size: theme.sizes.iconMd, color: colors.accentText),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s3,
            children: [
              Text(
                t.music.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Text(
                enabled == 0 ? t.music.tagline : t.music.sourcesReady(count: enabled),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The shown view's content: with no music source wired in yet, a view is
/// an honest empty state that names what will live here once the library
/// arrives — no placeholder songs, no loading that never ends.
final class _ViewBody extends StatelessWidget {
  const _ViewBody({required this.view});

  /// The view whose state shows.
  final MusicView view;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: DsIcon(view.icon),
        title: Text(switch (view) {
          MusicView.library => t.music.libraryEmptyTitle,
          MusicView.songlists => t.music.playlistsEmptyTitle,
          MusicView.toplists => t.music.chartsEmptyTitle,
          MusicView.mine => t.music.myListsEmptyTitle,
        }),
        description: Text(switch (view) {
          MusicView.library => t.music.libraryEmptyDescription,
          MusicView.songlists => t.music.playlistsEmptyDescription,
          MusicView.toplists => t.music.chartsEmptyDescription,
          MusicView.mine => t.music.myListsEmptyDescription,
        }),
      ),
    );
  }
}
