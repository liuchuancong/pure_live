import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';

/// The music module's entry: the module's three future views — the song
/// library, the playlists, the charts — behind a segment switch, each
/// honest about its state while no music source feeds the module yet.
///
/// The playback plumbing already sits in the business packages (the VOD
/// source's audio-only address, the play queue, the lyric lookup), but no
/// source browses a music library today, so every view says what will live
/// here instead of paging in placeholder songs or a loading row that never
/// loads.
final class MusicPage extends StatefulWidget {
  /// The music module's entry page.
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

final class _MusicPageState extends State<MusicPage> {
  /// The view the page is showing; a module lands on its library.
  _MusicView _view = _MusicView.library;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ModuleHeader(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: _ViewSegments(view: _view, onChanged: (view) => setState(() => _view = view)),
        ),
        Expanded(child: _ViewBody(view: _view)),
      ],
    );
  }
}

/// The page's views: the module's three surfaces, the library first.
enum _MusicView {
  /// The song library: songs as a masonry grid that pages in.
  library,

  /// Playlists: the lists the viewer curates and follows.
  playlists,

  /// Charts: the sources' popular songs, ranked.
  charts;

  /// The view's icon, on its segment and in its empty state.
  DsIconData get icon => switch (this) {
    _MusicView.library => DsIcons.discAlbum,
    _MusicView.playlists => DsIcons.listMusic,
    _MusicView.charts => DsIcons.trendingUp,
  };
}

/// The module's mark: the music note in a tinted tile, the module's name,
/// and one line on where the module stands — the page's honest headline.
final class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
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
                context.t.music.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Text(
                context.t.music.tagline,
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

/// The page's view switch: one segment per view, each carrying its own
/// icon; the selection rides the segment control's radio group.
final class _ViewSegments extends StatelessWidget {
  const _ViewSegments({required this.view, required this.onChanged});

  /// The view the page is showing.
  final _MusicView view;

  /// Receives a newly chosen view.
  final ValueChanged<_MusicView> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsSegmentedControl<_MusicView>(
      value: view,
      onChanged: onChanged,
      semanticLabel: t.music.viewsLabel,
      segments: [
        for (final view in _MusicView.values)
          DsSegment(
            value: view,
            icon: DsIcon(view.icon),
            label: Text(switch (view) {
              _MusicView.library => t.music.tabLibrary,
              _MusicView.playlists => t.music.tabPlaylists,
              _MusicView.charts => t.music.tabCharts,
            }),
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
  final _MusicView view;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: DsIcon(view.icon),
        title: Text(switch (view) {
          _MusicView.library => t.music.libraryEmptyTitle,
          _MusicView.playlists => t.music.playlistsEmptyTitle,
          _MusicView.charts => t.music.chartsEmptyTitle,
        }),
        description: Text(switch (view) {
          _MusicView.library => t.music.libraryEmptyDescription,
          _MusicView.playlists => t.music.playlistsEmptyDescription,
          _MusicView.charts => t.music.chartsEmptyDescription,
        }),
      ),
    );
  }
}
