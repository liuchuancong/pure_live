part of 'settings_split_view.dart';

/// The widgets of a split view's panes: the list pane and the detail
/// navigator, side by side or in the pages of the stack navigator.
extension _Panes on _SettingsSplitViewState {
  static const _listPageKey = ValueKey<String>('settings_split_list');

  /// The [list] pane next to the detail navigator.
  Widget _buildTwoPanes(
    ResolvedSettingsStyle style,
    SplitPaneStyle paneStyle,
    Widget list,
  ) {
    final theme = style.themeData;
    final geometry = paneStyle.geometry;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Its own semantics container: the routes of the detail navigator block
    // the semantics of what was painted before them in their container,
    // which would hide the list pane.
    final Widget detailPane = Semantics(
      container: true,
      explicitChildNodes: true,
      child: ClipRect(
        child: MediaQuery.removePadding(
          context: context,
          removeLeft: !isRtl,
          removeRight: isRtl,
          child: paneStyle.detailColumn(_buildDetailNavigator(style)),
        ),
      ),
    );

    Widget listPane = Semantics(
      container: true,
      explicitChildNodes: true,
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: isRtl,
        removeRight: !isRtl,
        child: list,
      ),
    );

    // The line between the panes: a hairline on the macOS sidebar, GNOME's
    // 1px sidebar border. Windows Settings has none (one Mica surface).
    final edge = paneStyle.paneEdge(theme);
    if (edge != null) {
      listPane = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: BorderDirectional(end: edge)),
        child: listPane,
      );
    }

    // Tab visits the list pane, then the page, whatever the reading order
    // of their contents says: the page's first control can sit above the
    // first row, under a taller pane header.
    listPane = FocusTraversalOrder(
      order: const NumericFocusOrder(0),
      child: listPane,
    );
    final orderedDetailPane = FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: detailPane,
    );

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ColoredBox(
        color:
            theme.listPaneBackground ??
            theme.settingsListBackground ??
            const Color(0x00000000),
        // The Windows style's icon rail opens over the detail pane.
        child: geometry.compactPane
            ? FluentCompactPaneLayout(
                open: _fluentPaneOpen,
                railWidth: geometry.listWidth,
                openWidth: math.min(
                  widget.listPaneWidth ?? kFluentOverlayPaneWidth,
                  geometry.listWidth + geometry.detailWidth,
                ),
                onDismiss: _closeFluentPane,
                pane: listPane,
                detail: orderedDetailPane,
              )
            : Row(
                children: [
                  SizedBox(width: geometry.listWidth, child: listPane),
                  if (geometry.gap > 0) SizedBox(width: geometry.gap),
                  Expanded(child: orderedDetailPane),
                ],
              ),
      ),
    );
  }

  /// The stack navigator: the [list] pane and, over it, the picked page.
  Widget _buildOnePane(ResolvedSettingsStyle style, Widget list) {
    final picked = _pickedId;
    final pages = <Page<void>>[
      _PlainPage(key: _listPageKey, restorationId: 'list', child: list),
      if (picked != null) _hostPage(style, picked),
    ];
    return NotificationListener<NavigationNotification>(
      onNotification: _handleStackNavigation,
      child: Navigator(
        key: _stackKey,
        restorationScopeId: widget.restorationId == null ? null : 'stack',
        // Tab leaves the navigator's pages for the rest of the app, as in
        // the app's own navigator (nested ones default to a closed loop).
        routeTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
        observers: [_stackObserver],
        pages: pages,
        onGenerateRoute: _generateStackRoute,
        onUnknownRoute: _unknownStackRoute,
        onDidRemovePage: _handleStackPageRemoved,
      ),
    );
  }

  /// The page one pane pushes over the list for the destination with [id].
  Page<void> _hostPage(ResolvedSettingsStyle style, String id) {
    final child = PopScope<Object?>(
      // The page's back swipe (and predictive back) would close it even
      // while a page pushed inside it could go back, or the page vetoes
      // back with a PopScope: then back goes through the split view.
      canPop: !_detailCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: _DetailHost(
        generation: _hostGeneration,
        background: style.themeData.settingsListBackground,
        child: _buildDetailNavigator(style),
      ),
    );
    if (settingsUsesCupertinoRoutes(settingsStyleFamily(style.platform))) {
      return CupertinoPage<void>(
        key: _hostPageKey,
        name: id,
        restorationId: 'detail',
        child: child,
      );
    }
    return MaterialPage<void>(
      key: _hostPageKey,
      name: id,
      restorationId: 'detail',
      child: child,
    );
  }

  Widget _buildDetailNavigator(ResolvedSettingsStyle style) {
    return NotificationListener<NavigationNotification>(
      onNotification: _handleDetailNavigation,
      child: Navigator(
        key: _detailKey,
        restorationScopeId: widget.restorationId == null ? null : 'detail',
        // Tab moves on from the detail pane to the list pane (a closed loop
        // would keep the focus in the page). Showing a page picked in the
        // list leaves the focus in the list, like the platforms' sidebars;
        // pages opened inside the pane take it (see _DetailObserver).
        routeTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
        requestFocus: false,
        observers: [_detailObserver],
        pages: [_detailRootPage(style)],
        onDidRemovePage: (_) {},
      ),
    );
  }

  Page<void> _detailRootPage(ResolvedSettingsStyle style) {
    final id = _detailRootId;
    final entry = _lookup(id);
    if (entry == null) {
      return _PlainPage(
        key: const ValueKey<String>('settings_split_empty'),
        child: Material(
          color: style.themeData.settingsListBackground,
          child: Builder(
            builder: (context) =>
                widget.emptyDetailBuilder?.call(context) ??
                const SizedBox.expand(),
          ),
        ),
      );
    }
    return _PlainPage(
      key: ValueKey<String>('settings_split_page_$id'),
      name: id,
      restorationId: 'page_$id',
      child: SettingsDestinationPage(
        destination: entry.destination,
        title: entry.title,
        config: style.resolvedConfig,
        isDetailRoot: true,
      ),
    );
  }

  /// The list pane: the sections in a [SettingsList] under the style's
  /// header, in both layouts. What differs between the styles comes from
  /// [paneStyle].
  Widget _buildListPane(
    ResolvedSettingsStyle style,
    SplitPaneStyle paneStyle,
    bool canLeave,
  ) {
    final theme = style.themeData;
    final isSplit = paneStyle.isSplit;
    final sidebar = paneStyle.sidebar;
    final background = isSplit || sidebar
        ? (theme.listPaneBackground ?? theme.settingsListBackground)
        : theme.settingsListBackground;

    // The list pane's own background, for the tiles too (iOS descriptions
    // are drawn on it).
    SettingsThemeData withBackground(SettingsThemeData? theme) =>
        (theme ?? const SettingsThemeData()).merge(
          theme: SettingsThemeData(settingsListBackground: background),
        );

    final title = widget.title;
    final list = SettingsList(
      platform: style.platform,
      brightness: widget.brightness,
      lightTheme: withBackground(widget.lightTheme),
      darkTheme: withBackground(widget.darkTheme),
      applicationType: widget.applicationType,
      contentPadding: paneStyle.listPadding,
      // A copy: the pane's lazy list must not read the app's list after
      // the app changed it in place without rebuilding the view.
      sections: paneStyle.listSections([...widget.sections], title),
    );

    // The content is built in the pane, for its `MediaQuery`: with two
    // panes it has no padding at the end side, which the pane doesn't touch.
    final content = Builder(
      builder: (paneContext) => paneStyle.buildListPane(
        SplitListPaneParts(
          viewContext: paneContext,
          title: title,
          onBack: canLeave ? _leave : null,
          onTogglePane: _toggleFluentPane,
          background: background,
          largeTitleHidden: _largeTitleHidden,
          list: list,
        ),
      ),
    );

    return SettingsSplitListScope(
      isSplit: isSplit,
      sidebar: sidebar || isSplit,
      selectedId: _shownId,
      onOpen: _openFromTile,
      onTileBuilt: _handleTileBuilt,
      hideLeading: paneStyle.hidesLeading,
      child: KeyedSubtree(
        key: const ValueKey<String>('settings_split_list_pane'),
        child: Material(
          key: _listKey,
          color: background,
          child: Focus(focusNode: _listFocusNode, child: content),
        ),
      ),
    );
  }
}
