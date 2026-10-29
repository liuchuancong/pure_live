import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsChild;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';

/// The room the pager takes under the table (its row plus the gap above it),
/// which the page size leaves out of the rows it counts.
const double _kPagerRoom = 48;

/// The room the touch list's footer takes, counted the same way.
const double _kFooterRoom = 36;

/// The free-font categories, in the collection's own order.
const List<String> _kCategories = ['heiti', 'songti', 'kaiti', 'art', 'handwriting', 'english', 'other'];

/// Which catalogue the table lists: the Chinese collection, the same narrowed
/// to the faces already on this device, or Google's.
enum _Script { local, chinese, google }

/// The shown name of a family: the default's label, the system face, the
/// stored name a download remembers, or the family as it stands.
String fontFamilyLabel(Translations t, String? family, {String? name}) {
  if (family == null || family == kDefaultFontFamily) return t.settings.fontDefault;
  if (family == kSystemChineseFontId) return t.settings.fontSystemChinese;
  return name ?? family;
}

/// Bytes as the manager shows them: one decimal from the kilobyte up.
String formatFontBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// The word for a catalogue category: the free collection's own kinds and
/// Google's five.
String fontCategoryLabel(Translations t, String? category) => switch (category) {
  'heiti' => t.settings.fontCategoryHeiti,
  'songti' => t.settings.fontCategorySongti,
  'kaiti' => t.settings.fontCategoryKaiti,
  'art' => t.settings.fontCategoryArt,
  'handwriting' => t.settings.fontCategoryHandwriting,
  'english' => t.settings.fontCategoryEnglish,
  'serif' => t.settings.fontCategorySerif,
  'sans-serif' => t.settings.fontCategorySansSerif,
  'display' => t.settings.fontCategoryDisplay,
  'monospace' => t.settings.fontCategoryMonospace,
  _ => t.settings.fontCategoryOther,
};

/// Opens the font manager — the typeface the app (or the flying danmaku, with
/// [danmaku]) draws in — as a page of the settings surface: the centre pane on
/// desktop, a pushed section route on a touch shell, the way every other
/// section page is entered.
void showFontManagerPage(BuildContext context, WidgetRef ref, {bool danmaku = false}) {
  openSettingsChild(context, ref, danmaku ? SettingsSection.fontDanmaku : SettingsSection.fontApp);
}

/// The page itself: one compact table of families — the Chinese collection or
/// Google's — with the search, the local filter and the category chips above
/// it. A wide window pages the table and pins the pager under it; a touch
/// shell appends a screenful each time the list is scrolled to its end, and
/// says how much of the catalogue it has shown.
final class FontManagerPage extends ConsumerStatefulWidget {
  /// Creates the page; [danmaku] manages the flying layer's typeface.
  const FontManagerPage({this.danmaku = false, super.key});

  /// Whether the flying danmaku's typeface is managed instead of the app's.
  final bool danmaku;

  @override
  ConsumerState<FontManagerPage> createState() => _FontManagerPageState();
}

final class _FontManagerPageState extends ConsumerState<FontManagerPage> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _tableScroll = ScrollController();
  String _query = '';
  _Script _script = _Script.chinese;
  String _category = '';
  int _page = 1;
  DsTableSort? _sort;

  // The touch shell's list: how many rows it holds, how many the filters keep
  // and how many one screenful takes, kept from the last layout so the scroll
  // listener knows when to append.
  int _shown = 0;
  int _total = 0;
  int _batch = 0;
  bool _paged = true;
  bool _loadingMore = false;
  Timer? _moreTimer;

  @override
  void initState() {
    super.initState();
    _tableScroll.addListener(_onTableScroll);
  }

  @override
  void dispose() {
    _moreTimer?.cancel();
    _search.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  /// The touch list's footer: the next batch arrives when the viewer reaches
  /// the table's end, the way the popular feed's blocks do.
  void _onTableScroll() {
    if (_paged || _loadingMore || !_tableScroll.hasClients) return;
    final position = _tableScroll.position;
    if (!position.hasContentDimensions || position.extentAfter > 120) return;
    if (_shown >= _total) return;
    setState(() => _loadingMore = true);
    _moreTimer?.cancel();
    // One beat, so the footer's spinner reads as work rather than a flicker.
    _moreTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _shown = math.min(_shown + math.max(_batch, 1), _total);
        _loadingMore = false;
      });
    });
  }

  bool _isCurrent(FontEntry entry, String? family) =>
      entry.id == family || (entry.isDefault && (family == null || family == kDefaultFontFamily));

  void _setFamily(String? family) {
    if (widget.danmaku) {
      unawaited(ref.read(danmakuStyleProvider.notifier).setFontFamily(family));
      unawaited(loadGoogleFont(family));
      return;
    }
    final scope = AppThemeScope.of(context);
    scope.onChanged(
      scope.settings.rebuild((b) {
        b
          ..fontFamily = family
          ..fontPackage = null;
      }),
    );
    unawaited(loadGoogleFont(family));
  }

  /// Fetches [entry] without applying it: keeping a face and wearing it are
  /// two decisions, and the second belongs to the viewer.
  Future<void> _download(FontEntry entry) async {
    final t = context.t;
    final ok = switch (entry.source) {
      FontSource.freeFont => await ref.read(freeFontStoreProvider.notifier).download(entry),
      FontSource.google => await ref.read(googleFontStoreProvider.notifier).download(entry.id),
      FontSource.bundled || FontSource.system => true,
    };
    if (!mounted) return;
    showDsToast(
      context: context,
      title: ok ? t.settings.fontManagerDownloaded : t.settings.fontManagerDownloadFailed,
      status: ok ? DsStatus.success : DsStatus.danger,
    );
  }

  /// Puts an already downloaded face to work.
  Future<void> _use(FontEntry entry) async {
    final t = context.t;
    if (entry.source == FontSource.freeFont) {
      final registered = await ref.read(freeFontStoreProvider.notifier).register(entry.id);
      if (!mounted) return;
      if (!registered) {
        showDsToast(context: context, title: t.settings.fontManagerNotDownloaded, status: DsStatus.warning);
        return;
      }
    }
    _setFamily(entry.isDefault ? null : entry.id);
    if (entry.source != FontSource.google) return;
    final loaded = await loadGoogleFont(entry.id);
    if (!mounted) return;
    if (!loaded) {
      showDsToast(context: context, title: t.settings.fontManagerDownloadFailed, status: DsStatus.danger);
      return;
    }
    // The file landed after the theme was laid out: one rebuild re-shapes it.
    setState(() {});
  }

  /// Deletes [entry]'s file, after confirming; the default takes over when the
  /// face was in use.
  Future<void> _delete(FontEntry entry, String? family) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.fontManagerDeleteFont,
      description: t.settings.fontManagerDeleteQuestion(name: entry.name),
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    if (_isCurrent(entry, family)) _setFamily(null);
    await ref.read(freeFontStoreProvider.notifier).remove(entry.id);
  }

  /// The entries the chosen catalogue, the chips and the search keep.
  List<FontEntry> _entries(List<FontEntry> catalog, FreeFontStoreState store) {
    final query = _query.trim().toLowerCase();
    final chinese = _script != _Script.google;
    final pool = chinese ? [...kBundledFontEntries, ...catalog] : catalog;
    return [
      for (final entry in pool)
        if (_category.isEmpty || entry.category == _category)
          if (_script != _Script.local || _isLocallyAvailable(entry, store))
            if (query.isEmpty || entry.name.toLowerCase().contains(query)) entry,
    ];
  }

  /// The rows in the sort the header asked for; the table keeps the order
  /// ([DsTable.sortLocally] is off), because a page is only part of the list.
  List<FontEntry> _sorted(List<FontEntry> entries) {
    final sort = _sort;
    if (sort == null) return entries;
    final rows = [...entries];
    int compare(FontEntry a, FontEntry b) => switch (sort.columnId) {
      'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      'size' => a.bytes.compareTo(b.bytes),
      _ => 0,
    };
    rows.sort((a, b) {
      final order = compare(a, b);
      return sort.ascending ? order : -order;
    });
    return rows;
  }

  static bool _isLocallyAvailable(FontEntry entry, FreeFontStoreState store) => switch (entry.source) {
    FontSource.bundled || FontSource.system => true,
    FontSource.freeFont => store.isCached(entry.id),
    FontSource.google => false,
  };

  static bool _isDownloaded(FontEntry entry, FreeFontStoreState store, GoogleFontStoreState google) =>
      switch (entry.source) {
        FontSource.bundled || FontSource.system => true,
        FontSource.freeFont => store.isCached(entry.id),
        FontSource.google => google.isDownloaded(entry.id),
      };

  static bool _isDownloading(FontEntry entry, FreeFontStoreState store, GoogleFontStoreState google) =>
      switch (entry.source) {
        FontSource.freeFont => store.transfers.containsKey(entry.id),
        FontSource.google => google.isDownloading(entry.id),
        FontSource.bundled || FontSource.system => false,
      };

  static bool _hasFailed(FontEntry entry, FreeFontStoreState store, GoogleFontStoreState google) =>
      switch (entry.source) {
        FontSource.freeFont => store.failed.contains(entry.id),
        FontSource.google => google.failed.contains(entry.id),
        FontSource.bundled || FontSource.system => false,
      };

  /// Whether the row can draw its own name: a face the app has already
  /// registered, or the one the theme is wearing.
  static bool _namedInItself(FontEntry entry, FreeFontStoreState store, String? family) => switch (entry.source) {
    FontSource.bundled || FontSource.system => true,
    FontSource.freeFont => store.isCached(entry.id),
    FontSource.google => entry.id == family,
  };

  /// Back to the first page with the page at its top, after a filter change.
  void _refilter(VoidCallback change) {
    _moreTimer?.cancel();
    setState(() {
      change();
      _page = 1;
      // The touch list starts over from one batch.
      _shown = 0;
      _loadingMore = false;
    });
    _scrollToTop();
  }

  /// Turns the table to [next], the page's head in view again.
  void _goToPage(int next) {
    setState(() => _page = next);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_tableScroll.hasClients) _tableScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final family = widget.danmaku
        ? ref.watch(danmakuStyleProvider).fontFamily
        : AppThemeScope.of(context).settings.fontFamily;
    final freeCatalog = ref.watch(freeFontCatalogProvider);
    final googleCatalog = ref.watch(googleFontCatalogProvider);
    final store = ref.watch(freeFontStoreProvider);
    final google = ref.watch(googleFontStoreProvider);
    final chinese = _script != _Script.google;
    final catalog = (chinese ? freeCatalog.value : googleCatalog.value) ?? const <FontEntry>[];
    final loading = chinese ? freeCatalog.isLoading : googleCatalog.isLoading;
    final rows = _sorted(_entries(catalog, store));
    final allCount = chinese
        ? [
            for (final entry in [...kBundledFontEntries, ...?freeCatalog.value])
              if (_script != _Script.local || _isLocallyAvailable(entry, store)) entry,
          ].length
        : googleCatalog.value?.length ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            // The heading, the search, the two catalogues, the local switch
            // and the category chips stay put: only the table under them
            // travels, so a long catalogue never carries the filters away.
            if (!stacked) _buildHeader(context),
            _buildToolbar(context, stacked: stacked, shown: rows.length, allCount: allCount),
            Expanded(
              child: LayoutBuilder(
                builder: (context, area) {
                  // The table takes the room the rest of the page leaves. A
                  // wide window pages it — one page is exactly what the room
                  // holds, so the pager stays in sight; a touch shell starts
                  // with one batch and appends the next as the table's own
                  // scroll reaches its end, and its footer says how much of
                  // the catalogue is listed.
                  final paged = !stacked;
                  final rowHeight = DsTheme.of(context).sizes.listRow;
                  final reserve = paged ? _kPagerRoom : _kFooterRoom;
                  final pageSize = math.max(1, ((area.maxHeight - reserve) / rowHeight).floor());
                  _paged = paged;
                  _total = rows.length;
                  // A row past the fold, so the touch table always has
                  // something to scroll: a first batch that fitted exactly
                  // would leave nothing to reach the end with. A new filter
                  // starts from one batch again; a resize only ever widens
                  // what is already listed.
                  _batch = paged ? pageSize : pageSize + 1;
                  _shown = paged
                      ? 0
                      : _shown == 0
                      ? math.min(_batch, rows.length)
                      : math.min(_shown, rows.length);
                  final pageCount = !paged || rows.isEmpty ? 0 : (rows.length / pageSize).ceil();
                  final page = pageCount == 0 ? 1 : _page.clamp(1, pageCount);
                  final visible = paged
                      ? rows.skip((page - 1) * pageSize).take(pageSize).toList()
                      : rows.take(_shown).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: DsTable<FontEntry>(
                          semanticLabel: t.settings.fontManagerTitle,
                          columns: _columns(
                            context,
                            family: family,
                            store: store,
                            google: google,
                            narrow: area.maxWidth < 560,
                          ),
                          rows: visible,
                          rowKey: (entry) => entry.id,
                          scrollController: _tableScroll,
                          loading: loading,
                          sort: _sort,
                          sortLocally: false,
                          onSortChanged: (sort) => _refilter(() => _sort = sort),
                          onRowPressed: (entry) => unawaited(_openDetails(entry, family: family)),
                          showRowMenuButton: true,
                          rowMenuBuilder: (context, entry) => _rowMenu(context, entry, family: family),
                          emptyView: DsEmptyState(
                            icon: const DsIcon(DsIcons.search),
                            title: Text(t.settings.fontManagerNoResults),
                          ),
                        ),
                      ),
                      if (!paged && rows.isNotEmpty) _buildMoreFooter(context),
                      if (pageCount > 1)
                        Align(
                          alignment: AlignmentDirectional.center,
                          child: DsPagination(
                            page: page,
                            pageCount: pageCount,
                            semanticLabel: t.settings.fontManagerPageLabel,
                            onChanged: (next) {
                              if (next == page) return;
                              _goToPage(next);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// The touch list's footer: a spinner while the next screenful is being
  /// appended, otherwise how much of the catalogue is listed.
  Widget _buildMoreFooter(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final style = theme.typography.caption.copyWith(color: colors.textMuted);
    if (_loadingMore) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: DsSpace.s8,
        children: [
          const SizedBox.square(dimension: 14, child: DsSpinner()),
          Text(t.settings.fontManagerLoadingMore, style: style),
        ],
      );
    }
    return Center(
      child: Text(
        t.settings.fontManagerLoadedCount(shown: '$_shown', total: '$_total'),
        style: style,
      ),
    );
  }

  /// The title and the one-line promise under it.
  Widget _buildHeader(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s4,
      children: [
        Text(t.settings.fontManagerTitle, style: theme.typography.title.copyWith(color: colors.text)),
        Text(t.settings.fontManagerSubtitle, style: theme.typography.small.copyWith(color: colors.textMuted)),
      ],
    );
  }

  /// Search, the catalogue choice — the local faces, the whole Chinese
  /// collection or Google's — the count, and the chips of the chosen one.
  Widget _buildToolbar(BuildContext context, {required bool stacked, required int shown, required int allCount}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final chinese = _script != _Script.google;
    final search = DsSearchField(
      controller: _search,
      placeholder: t.settings.fontManagerSearchPlaceholder,
      semanticLabel: t.settings.fontManagerSearchPlaceholder,
      onChanged: (value) => _refilter(() => _query = value),
    );
    // The control is as wide as its three labels; the theme's own stretch is
    // undone where it would fill the line.
    final script = DsSegmentedControl<_Script>(
      value: _script,
      semanticLabel: t.settings.fontManagerFilterLabel,
      onChanged: (value) => _refilter(() {
        _script = value;
        _category = '';
        // Google's rows have no category or size of their own kind, so the
        // header's sort may name a column that is gone.
        _sort = null;
      }),
      segments: [
        DsSegment(value: _Script.local, label: Text(t.settings.fontManagerLocal)),
        DsSegment(value: _Script.chinese, label: Text(t.settings.fontManagerScriptChinese)),
        DsSegment(value: _Script.google, label: Text(t.settings.fontManagerGoogle)),
      ],
    );
    final count = Text(
      t.settings.fontManagerCount(count: '$shown'),
      style: theme.typography.caption.copyWith(color: colors.textMuted),
    );
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DsSegmentedControl<String>(
        value: _category,
        semanticLabel: t.settings.fontManagerFilterLabel,
        onChanged: (value) => _refilter(() => _category = value),
        segments: [
          DsSegment(value: '', label: Text('${t.settings.fontManagerFilterAll} ($allCount)')),
          for (final category in chinese ? _kCategories : kGoogleFontCategories)
            DsSegment(value: category, label: Text(fontCategoryLabel(t, category))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        if (stacked) ...[
          search,
          Row(
            spacing: DsSpace.s8,
            children: [
              Flexible(
                child: Align(alignment: AlignmentDirectional.centerStart, child: script),
              ),
              count,
            ],
          ),
        ] else
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(child: search),
              script,
              count,
            ],
          ),
        chips,
      ],
    );
  }

  /// The table's columns: the name with its state beside it, then what is true
  /// before a download (the Chinese collection's category and size, dropped on
  /// a narrow table so the row still fits) and the one action of every row.
  List<DsTableColumn<FontEntry>> _columns(
    BuildContext context, {
    required String? family,
    required FreeFontStoreState store,
    required GoogleFontStoreState google,
    required bool narrow,
  }) {
    final t = context.t;
    return [
      DsTableColumn<FontEntry>(
        id: 'name',
        label: t.settings.fontManagerColumnFont,
        value: (entry) => entry.name,
        text: (entry) => entry.name,
        cell: (context, entry) => _nameCell(context, entry, family: family, store: store, google: google),
        width: const DsTableColumnWidth.flex(3, 140),
        sortable: true,
      ),
      if (_script != _Script.google && !narrow) ...[
        DsTableColumn<FontEntry>(
          id: 'category',
          label: t.settings.fontManagerCategory,
          text: (entry) => fontCategoryLabel(t, entry.category),
          width: const DsTableColumnWidth.intrinsic(min: 76),
        ),
        DsTableColumn<FontEntry>(
          id: 'size',
          label: t.settings.fontManagerColumnSize,
          value: (entry) => entry.bytes,
          text: (entry) => entry.bytes > 0 ? formatFontBytes(entry.bytes) : '—',
          numeric: true,
          sortable: true,
          width: const DsTableColumnWidth.intrinsic(min: 80),
        ),
      ],
      DsTableColumn<FontEntry>(
        id: 'actions',
        label: t.settings.fontManagerColumnActions,
        alignment: DsTableCellAlignment.end,
        cell: (context, entry) => _actionButton(context, entry, family: family, store: store, google: google),
        width: const DsTableColumnWidth.fixed(112),
      ),
    ];
  }

  /// The family's name — in its own face once that face is here — with the
  /// state badge beside it, so a narrow table keeps the state without a column
  /// of its own.
  Widget _nameCell(
    BuildContext context,
    FontEntry entry, {
    required String? family,
    required FreeFontStoreState store,
    required GoogleFontStoreState google,
  }) {
    return Row(
      spacing: DsSpace.s8,
      children: [
        Flexible(
          child: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: _namedInItself(entry, store, family) ? resolvedFontFamily(entry.id) : null),
          ),
        ),
        ?_stateBadge(context, entry, family: family, store: store, google: google),
      ],
    );
  }

  /// What the manager knows about a row: in use, moving, failed, here, or
  /// still to come — each with its own tone; null when there is nothing to say.
  Widget? _stateBadge(
    BuildContext context,
    FontEntry entry, {
    required String? family,
    required FreeFontStoreState store,
    required GoogleFontStoreState google,
  }) {
    final t = context.t;
    if (_isDownloading(entry, store, google)) {
      final fraction = store.transfers[entry.id]?.fraction;
      return DsBadge(
        status: DsStatus.info,
        label: Text(
          fraction == null
              ? t.settings.fontManagerDownloadingShort
              : t.settings.fontManagerDownloading(percent: '${(fraction * 100).round()}'),
        ),
      );
    }
    if (_isCurrent(entry, family)) {
      return DsBadge(status: DsStatus.success, label: Text(t.settings.fontManagerInUse));
    }
    if (_hasFailed(entry, store, google)) {
      return DsBadge(status: DsStatus.danger, label: Text(t.settings.fontManagerDownloadFailed));
    }
    if (entry.isDefault) return DsBadge(label: Text(t.settings.fontManagerDefaultBadge));
    return switch (entry.source) {
      FontSource.freeFont || FontSource.google when _isDownloaded(entry, store, google) => DsBadge(
        status: DsStatus.info,
        label: Text(t.settings.fontManagerDownloaded),
      ),
      FontSource.freeFont ||
      FontSource.google => DsBadge(status: DsStatus.warning, label: Text(t.settings.fontManagerNotDownloaded)),
      FontSource.bundled || FontSource.system => null,
    };
  }

  /// The row's one button: fetch the face, put a downloaded one to work, or
  /// try a fetch that failed.
  Widget _actionButton(
    BuildContext context,
    FontEntry entry, {
    required String? family,
    required FreeFontStoreState store,
    required GoogleFontStoreState google,
  }) {
    final t = context.t;
    final downloading = _isDownloading(entry, store, google);
    final current = _isCurrent(entry, family);
    final downloaded = _isDownloaded(entry, store, google);
    final failed = _hasFailed(entry, store, google);
    return DsButton(
      size: DsSize.xs,
      variant: current || downloading ? DsButtonVariant.secondary : DsButtonVariant.primary,
      onPressed: current || downloading
          ? null
          : downloaded
          ? () => unawaited(_use(entry))
          : () => unawaited(_download(entry)),
      child: Text(
        downloading
            ? t.settings.fontManagerDownloadingShort
            : current
            ? t.settings.fontManagerInUse
            : downloaded
            ? t.settings.fontManagerUse
            : failed
            ? t.common.retry
            : t.settings.fontManagerDownload,
      ),
    );
  }

  /// The row's context menu: the same decisions the row and the detail panel
  /// carry, so a right click is enough on a wide window.
  List<Widget> _rowMenu(BuildContext context, FontEntry entry, {required String? family}) {
    final t = context.t;
    final store = ref.read(freeFontStoreProvider);
    final google = ref.read(googleFontStoreProvider);
    final current = _isCurrent(entry, family);
    final downloaded = _isDownloaded(entry, store, google);
    final failed = _hasFailed(entry, store, google);
    final isDefault = family == null || family == kDefaultFontFamily;
    return [
      if (!current && !_isDownloading(entry, store, google))
        DsMenuItem(
          leading: DsIcon(downloaded ? DsIcons.check : DsIcons.download),
          label: Text(
            downloaded
                ? t.settings.fontManagerUse
                : failed
                ? t.common.retry
                : t.settings.fontManagerDownload,
          ),
          onPressed: () => unawaited(downloaded ? _use(entry) : _download(entry)),
        ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.slidersHorizontal),
        label: Text(t.settings.fontManagerDetails),
        onPressed: () => unawaited(_openDetails(entry, family: family)),
      ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.copy),
        label: Text(t.settings.fontManagerCopyName),
        onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: entry.name))),
      ),
      if (current && !isDefault) ...[
        const DsMenuDivider(),
        DsMenuItem(
          leading: const DsIcon(DsIcons.rotateCcw),
          label: Text(t.settings.fontManagerReset),
          onPressed: () => _setFamily(null),
        ),
      ],
      if (!current && entry.source == FontSource.freeFont && store.isCached(entry.id)) ...[
        const DsMenuDivider(),
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.common.delete),
          destructive: true,
          onPressed: () => unawaited(_delete(entry, family)),
        ),
      ],
    ];
  }

  /// The family's own panel: what it looks like — in itself once the file is
  /// here — and everything that can be done with it. A bottom sheet on a touch
  /// shell, a side panel on a wide window.
  Future<void> _openDetails(FontEntry entry, {required String? family}) {
    return showDsPanel<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, ref, _) {
          final t = sheetContext.t;
          final theme = DsTheme.of(sheetContext);
          final colors = DsTheme.colorsOf(sheetContext);
          final store = ref.watch(freeFontStoreProvider);
          final google = ref.watch(googleFontStoreProvider);
          final current = _isCurrent(entry, family);
          final downloaded = _isDownloaded(entry, store, google);
          final downloading = _isDownloading(entry, store, google);
          final isDefault = family == null || family == kDefaultFontFamily;
          return DsPanel(
            title: Text(entry.name),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                DsButton(
                  leading: DsIcon(current || downloaded ? DsIcons.check : DsIcons.download, size: 16),
                  onPressed: current || downloading
                      ? null
                      : downloaded
                      ? () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_use(entry));
                        }
                      : () => unawaited(_download(entry)),
                  child: Text(
                    downloading
                        ? t.settings.fontManagerDownloadingShort
                        : current
                        ? t.settings.fontManagerInUse
                        : downloaded
                        ? t.settings.fontManagerUse
                        : _hasFailed(entry, store, google)
                        ? t.common.retry
                        : t.settings.fontManagerDownload,
                  ),
                ),
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    if (current && !isDefault)
                      Expanded(
                        child: DsButton(
                          variant: DsButtonVariant.secondary,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _setFamily(null);
                          },
                          child: Text(t.settings.fontManagerReset),
                        ),
                      ),
                    if (!current && entry.source == FontSource.freeFont && downloaded)
                      Expanded(
                        child: DsButton(
                          variant: DsButtonVariant.secondary,
                          leading: const DsIcon(DsIcons.trash2, size: 16),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_delete(entry, family));
                          },
                          child: Text(t.common.delete),
                        ),
                      ),
                    Expanded(
                      child: DsButton(
                        variant: DsButtonVariant.secondary,
                        leading: const DsIcon(DsIcons.copy, size: 16),
                        onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: entry.name))),
                        child: Text(t.settings.fontManagerCopyName),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [
                _specimen(sheetContext, entry, loaded: downloaded),
                Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    if (entry.category != null) DsBadge(label: Text(fontCategoryLabel(t, entry.category))),
                    if (entry.bytes > 0) DsBadge(label: Text(formatFontBytes(entry.bytes))),
                    ?_stateBadge(sheetContext, entry, family: family, store: store, google: google),
                  ],
                ),
                Text(_sourceNote(sheetContext, entry), style: theme.typography.small.copyWith(color: colors.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The face on its own ground: its name and a Latin line in the family once
  /// the file is here, the default face with a note until then.
  Widget _specimen(BuildContext context, FontEntry entry, {required bool loaded}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final face = loaded ? resolvedFontFamily(entry.id) : null;
    return Container(
      height: 104,
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: BoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: DsSpace.s4,
        children: [
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.title.copyWith(fontFamily: face, fontSize: 28, color: colors.text),
          ),
          Text(
            'AaBbCc 1234567890 · ${t.settings.fontManagerSample}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(fontFamily: face, fontSize: 12, color: colors.textMuted),
          ),
          if (!loaded)
            Text(
              t.settings.fontManagerPreviewPending,
              maxLines: 1,
              style: theme.typography.caption.copyWith(fontSize: 10, color: colors.textSubtle),
            ),
        ],
      ),
    );
  }

  /// One sentence about where the face comes from.
  String _sourceNote(BuildContext context, FontEntry entry) {
    final t = context.t;
    return switch (entry.source) {
      FontSource.bundled => t.settings.fontManagerBundledNote,
      FontSource.system => t.settings.fontManagerSystemDescription(
        face: systemChineseFontFamily() ?? kDefaultFontFamily,
      ),
      FontSource.freeFont => t.settings.fontManagerFreeFontNote,
      FontSource.google => t.settings.fontManagerGoogleNote,
    };
  }
}
