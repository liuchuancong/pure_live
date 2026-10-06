import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:media_core/media_core.dart' show PlayerId;
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/player/presentation/fullscreen_window.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/domains/live/presentation/multiview/multiview_controller.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/domains/live/presentation/multiview/models/multiview_models.dart';
import 'package:pure_live/domains/live/presentation/multiview/widgets/video_output_viewport_sizer.dart';
import 'package:pure_live/domains/live/presentation/playback/pages/danmaku_settings_page.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/danmaku/portrait_danmaku_policy.dart';
import 'package:pure_live/domains/live/presentation/multiview/widgets/focus_rail_visibility.dart';
import 'package:pure_live/domains/live/presentation/multiview/widgets/multiview_room_picker.dart';
import 'package:pure_live/domains/live/presentation/multiview/widgets/multiview_fullscreen_surface.dart';
import 'package:pure_live/domains/live/presentation/multiview/danmaku/multiview_danmaku_settings_source.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

enum _DisplayMode { normal, immersive, fullscreen }

class MultiviewPage extends StatefulWidget {
  const MultiviewPage({super.key});

  @override
  State<MultiviewPage> createState() => _MultiviewPageState();
}

class _MultiviewPageState extends State<MultiviewPage> {
  static const double _wideBreakpoint = 680;

  static const double _sidePanelWidth = 320;

  static const int _focusBigFlex = 3;

  static const int _focusSmallFlex = 1;

  static const int _focusSmallViewportCells = 3;

  final ScrollController _focusRailScrollController = ScrollController();
  List<int> _focusRailCellIndices = const [];
  double _focusRailItemExtent = 0;
  double _focusRailViewportExtent = 0;

  void _syncFocusRailVisibility() {
    final offset = _focusRailScrollController.hasClients ? _focusRailScrollController.offset : 0.0;
    controller.setVisibleFocusSmallCells(
      visibleFocusRailCells(
        cellIndices: _focusRailCellIndices,
        scrollOffset: offset,
        viewportExtent: _focusRailViewportExtent,
        itemExtent: _focusRailItemExtent,
      ),
    );
  }

  _DisplayMode _displayMode = _DisplayMode.normal;

  bool _exiting = false;

  bool _largeControlsVisible = false;

  int _targetCell = 0;

  Worker? _layoutWorker;

  final Map<int, GlobalKey> _cellKeys = {};

  MultiviewController get controller => Get.find<MultiviewController>();

  GlobalKey _cellKey(int index) => _cellKeys.putIfAbsent(index, () => GlobalKey(debugLabel: 'multiview_cell_$index'));

  @override
  void initState() {
    super.initState();
    _targetCell = _firstAssignableCell();
    _layoutWorker = ever<MultiviewLayout>(controller.layout, (_) => _clampTargetCell());
    _focusRailScrollController.addListener(_syncFocusRailVisibility);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _layoutWorker?.dispose();
    _focusRailScrollController.removeListener(_syncFocusRailVisibility);
    _focusRailScrollController.dispose();
    if (Get.isRegistered<MultiviewController>()) controller.setVisibleFocusSmallCells(const []);
    if (_displayMode == _DisplayMode.fullscreen) {
      GlobalPlayerService.instance.player.isSystemFullscreen.value = false;
      unawaited(_restoreSystemFullscreen());
    }
    super.dispose();
  }

  void _handleBackIntent({required bool didPop}) {
    if (didPop) return;
    if (_displayMode != _DisplayMode.normal) {
      unawaited(_changeDisplayMode(_DisplayMode.normal));
      return;
    }
    unawaited(_exitSafely());
  }

  Future<void> _exitSafely() async {
    if (_exiting) return;
    _exiting = true;
    unawaited(controller.disposeAll());
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!mounted || _displayMode == _DisplayMode.normal) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    unawaited(_changeDisplayMode(_DisplayMode.normal));
    return true;
  }

  Future<void> _changeDisplayMode(_DisplayMode mode) async {
    if (!mounted || _displayMode == mode) return;
    final previous = _displayMode;
    setState(() => _displayMode = mode);

    final enterSystemFullscreen = mode == _DisplayMode.fullscreen && previous != _DisplayMode.fullscreen;
    final exitSystemFullscreen = previous == _DisplayMode.fullscreen && mode != _DisplayMode.fullscreen;
    if (!enterSystemFullscreen && !exitSystemFullscreen) return;

    try {
      if (enterSystemFullscreen) {
        GlobalPlayerService.instance.player.isSystemFullscreen.value = true;
        await WindowService().doEnterFullScreen();
        if (PlatformUtils.isMobile) {
          await WindowService().landScape();
        }
      } else {
        GlobalPlayerService.instance.player.isSystemFullscreen.value = false;
        await _restoreSystemFullscreen();
      }
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewPage: system fullscreen transition failed',
        name: 'MultiviewPage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _restoreSystemFullscreen() => WindowService().doExitFullScreen();

  int _firstAssignableCell() {
    for (final cell in controller.cells) {
      if (isMultiviewCellAssignable(cell.status)) return cell.index;
    }
    return 0;
  }

  void _clampTargetCell() {
    final maxIndex = controller.cells.length - 1;
    if (_targetCell > maxIndex && mounted) {
      setState(() => _targetCell = maxIndex);
    }
  }

  void _advanceTarget(int justAssigned) {
    final count = controller.cells.length;
    for (var step = 1; step < count; step++) {
      final index = (justAssigned + step) % count;
      if (isMultiviewCellAssignable(controller.cells[index].status)) {
        setState(() => _targetCell = index);
        return;
      }
    }
  }

  void _pickRoom(LiveRoom liveroom) {
    final target = _targetCell.clamp(0, controller.cells.length - 1);
    unawaited(controller.assignRoom(target, liveroom));
    _advanceTarget(target);
  }

  void _openPickerFor(int cellIndex, {required bool isWide}) {
    setState(() => _targetCell = cellIndex);
    if (isWide) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      builder: (sheetContext) => SafeArea(
        child: MultiviewRoomPicker(
          cellIndex: cellIndex,
          onPicked: (room) {
            Navigator.of(sheetContext).pop();
            _pickRoom(room);
          },
        ),
      ),
    );
  }

  void _showCellActions(MultiviewCellState state) {
    final isWide =
        PlatformUtils.isDesktop &&
        MediaQuery.sizeOf(context).width > _wideBreakpoint &&
        _displayMode == _DisplayMode.normal;
    final hasQuality =
        state.status == MultiviewCellStatus.playing && state.qualities.isNotEmpty && state.qualityLoader != null;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Remix.tv_2_line),
              title: Text(i18n('multiview_change_room')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openPickerFor(state.index, isWide: isWide);
              },
            ),
            ListTile(
              leading: const Icon(Remix.equalizer_line),
              title: Text(i18n('select_quality')),
              enabled: hasQuality,
              onTap: hasQuality
                  ? () {
                      Navigator.of(sheetContext).pop();
                      _showQualitySheet(state);
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(Remix.close_circle_line, color: Theme.of(context).colorScheme.error),
              title: Text(i18n('multiview_close_cell')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.removeCell(state.index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet(MultiviewCellState state) {
    final qualities = state.qualities;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < qualities.length; i++)
              ListTile(
                title: Text(qualities[i].quality),
                trailing: i == state.qualityIndex ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(controller.setCellQuality(state.index, i));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _retryCell(MultiviewCellState state) {
    final room = state.room;
    if (room == null) {
      _openPickerFor(
        state.index,
        isWide: PlatformUtils.isDesktop && MediaQuery.sizeOf(context).width > _wideBreakpoint,
      );
      return;
    }
    unawaited(controller.assignRoom(state.index, room));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBackIntent(didPop: didPop),
      child: switch (_displayMode) {
        _DisplayMode.normal => Scaffold(
          appBar: AppBar(
            title: Text(i18n('multiview_title')),
            actions: [
              IconButton(
                tooltip: i18n('multiview_immersive'),
                icon: const Icon(Remix.expand_diagonal_line),
                onPressed: () => unawaited(_changeDisplayMode(_DisplayMode.immersive)),
              ),
              IconButton(
                tooltip: i18n('multiview_fullscreen'),
                icon: const Icon(Remix.fullscreen_line),
                onPressed: () => unawaited(_changeDisplayMode(_DisplayMode.fullscreen)),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = PlatformUtils.isDesktop && constraints.maxWidth > _wideBreakpoint;
              return Column(
                children: [
                  _buildToolbar(),
                  Expanded(child: _buildContentArea(isWide: isWide)),
                ],
              );
            },
          ),
        ),
        _DisplayMode.immersive => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              _buildContentArea(isWide: false),
              Positioned(
                right: 16,
                bottom: 16,
                child: _ImmersiveRestoreButton(onTap: () => unawaited(_changeDisplayMode(_DisplayMode.normal))),
              ),
            ],
          ),
        ),
        _DisplayMode.fullscreen => Scaffold(
          backgroundColor: Colors.black,
          body: MultiviewFullscreenSurface(
            exitTooltip: i18n('multiview_fullscreen_exit'),
            onExit: () => unawaited(_changeDisplayMode(_DisplayMode.normal)),
            child: _buildContentArea(isWide: false),
          ),
        ),
      },
    );
  }

  Widget _buildContentArea({required bool isWide}) {
    if (!isWide) return _buildGrid(isWide: isWide);
    return Row(
      children: [
        Expanded(child: _buildGrid(isWide: isWide)),
        const VerticalDivider(width: 1),
        SizedBox(width: _sidePanelWidth, child: _buildSidePanel()),
      ],
    );
  }

  Widget _buildToolbar() {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 680;

    Widget buildLayoutSelector() {
      return Obx(() {
        final layout = controller.layout.value;

        return SegmentedButton<MultiviewLayout>(
          showSelectedIcon: false,
          selected: {layout},
          onSelectionChanged: (selection) {
            controller.setLayout(selection.first);
            // Reset the control bar after switching layouts.
            // Only focus layout has the large-cell control bar.
            _largeControlsVisible = false;
          },
          segments: const [
            ButtonSegment(value: MultiviewLayout.single, icon: Icon(Remix.aspect_ratio_line), label: Text('1×1')),
            ButtonSegment(value: MultiviewLayout.dual, icon: Icon(Remix.layout_column_line), label: Text('1×2')),
            ButtonSegment(value: MultiviewLayout.quad, icon: Icon(Remix.layout_grid_line), label: Text('2×2')),
            ButtonSegment(value: MultiviewLayout.focus, icon: Icon(Remix.focus_3_line), label: Text('1+3')),
          ],
        );
      });
    }

    Widget buildActions() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final enabled = controller.danmakuEnabled.value;
            final theme = Theme.of(context);

            return IconButton(
              tooltip: i18n('danmaku'),
              icon: Icon(
                CustomIcons.danmaku_open,
                size: 22,
                color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => controller.danmakuEnabled.toggle(),
            );
          }),
          Obx(() {
            final muted = controller.allMuted.value;
            final theme = Theme.of(context);
            return IconButton(
              key: const ValueKey('multiview-mute-all'),
              tooltip: i18n(muted ? 'multiview_unmute_all' : 'multiview_mute_all'),
              icon: Icon(
                muted ? Remix.volume_mute_line : Remix.volume_vibrate_line,
                size: 22,
                color: muted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: controller.toggleMuteAll,
            );
          }),
          // The selected room volume is available in every layout. In focus
          // mode the selected room is the large cell; in grid layouts it is
          // the cell carrying audio focus.
          Obx(() {
            final selectedIndex = controller.audioFocusIndexState.value;
            final canAdjust =
                selectedIndex >= 0 &&
                selectedIndex < controller.cells.length &&
                controller.cells[selectedIndex].status == MultiviewCellStatus.playing;
            return IconButton(
              tooltip: i18n('multiview_volume'),
              icon: const Icon(Remix.volume_up_line, size: 22),
              onPressed: canAdjust ? () => _showVolumeSheet(selectedIndex) : null,
            );
          }),
          Obx(() {
            final isFocusLayout = controller.layout.value == MultiviewLayout.focus;
            final enabled = controller.smallCellsLowQuality.value;
            final theme = Theme.of(context);

            return IconButton(
              tooltip: i18n('multiview_small_low_quality'),
              icon: Icon(
                Remix.speed_mini_line,
                size: 22,
                color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: isFocusLayout ? () => controller.smallCellsLowQuality.toggle() : null,
            );
          }),
        ],
      );
    }

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Column(
          children: [
            Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: buildLayoutSelector()),
            ),
            const SizedBox(height: 2),
            Align(alignment: Alignment.centerRight, child: buildActions()),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(child: Center(child: buildLayoutSelector())),
          const SizedBox(width: 8),
          buildActions(),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            i18n('multiview_pick_for_cell', args: {'index': '${_targetCell + 1}'}),
            style: AppTextStyles.t15Bold,
          ),
        ),
        Expanded(
          child: MultiviewRoomPicker(cellIndex: _targetCell, onPicked: _pickRoom),
        ),
      ],
    );
  }

  Widget _buildGrid({required bool isWide}) {
    return Obx(() {
      final layout = controller.layout.value;
      final cells = controller.cells;
      final focused = controller.focusedCellIndex.value;
      final audioFocus = controller.audioFocusIndexState.value;
      final danmakuEnabled = controller.danmakuEnabled.value;
      if (layout != MultiviewLayout.focus) controller.setVisibleFocusSmallCells(const []);
      final content = layout == MultiviewLayout.focus
          ? _buildFocusLayout(cells, focused: focused, isWide: isWide, danmakuEnabled: danmakuEnabled)
          : Column(
              children: [
                for (var row = 0; row < layout.rows; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < layout.columns; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: _buildCellAt(
                                cells,
                                row * layout.columns + col,
                                isWide: isWide,
                                showDanmaku: danmakuEnabled && row * layout.columns + col == audioFocus,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
      return Padding(padding: const EdgeInsets.all(6), child: content);
    });
  }

  Widget _buildFocusLayout(
    List<MultiviewCellState> cells, {
    required int focused,
    required bool isWide,
    required bool danmakuEnabled,
  }) {
    final bigIndex = focused.clamp(0, cells.length - 1);
    final others = [
      for (var i = 0; i < cells.length; i++)
        if (i != bigIndex) i,
    ];
    return Row(
      children: [
        Expanded(
          flex: _focusBigFlex,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildCellAt(
                    cells,
                    bigIndex,
                    isWide: isWide,
                    showDanmaku: danmakuEnabled,
                    showQualityEntry: !_largeControlsVisible,
                  ),
                ),
                if (_largeControlsVisible)
                  Positioned(left: 8, right: 8, bottom: 8, child: _buildLargeControlBar(cells, bigIndex)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: _focusSmallFlex,
          child: LayoutBuilder(
            builder: (context, boxConstraints) {
              final extent = boxConstraints.maxHeight / _focusSmallViewportCells;
              _focusRailCellIndices = others;
              _focusRailItemExtent = extent;
              _focusRailViewportExtent = boxConstraints.maxHeight;
              _syncFocusRailVisibility();
              final canAdd = controller.canAddCell;
              return SingleChildScrollView(
                controller: _focusRailScrollController,
                child: Column(
                  children: [
                    for (final index in others)
                      SizedBox(
                        height: extent,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: _buildCellAt(cells, index, isWide: isWide),
                        ),
                      ),
                    if (canAdd)
                      SizedBox(
                        height: extent,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: _AddCellSlot(onTap: () => unawaited(controller.addCell())),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLargeControlBar(List<MultiviewCellState> cells, int bigIndex) {
    final state = cells[bigIndex];
    final iconColor = Colors.white.withValues(alpha: 0.92);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const PureLiveBoundedScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final playing = controller.playingFlags[bigIndex];
              return _controlBarButton(
                icon: playing ? Remix.pause_line : Remix.play_line,
                tooltip: i18n(playing ? 'multiview_pause' : 'multiview_play'),
                onTap: () => unawaited(controller.toggleCellPlayPause(bigIndex)),
              );
            }),
            _controlBarButton(
              icon: Remix.refresh_line,
              tooltip: i18n('multiview_refresh'),
              onTap: () {
                final room = state.room;
                if (room != null) unawaited(controller.assignRoom(bigIndex, room));
              },
            ),
            Obx(() {
              final enabled = controller.danmakuEnabled.value;
              return _controlBarButton(
                icon: CustomIcons.danmaku_open,
                tooltip: i18n('danmaku'),
                iconColor: enabled ? Theme.of(context).colorScheme.primary : iconColor,
                onTap: () => controller.danmakuEnabled.toggle(),
              );
            }),
            _controlBarButton(
              icon: Remix.settings_3_line,
              tooltip: i18n('multiview_danmaku_settings'),
              onTap: _showDanmakuSettings,
            ),
            _controlBarButton(
              icon: Remix.hd_line,
              tooltip: i18n('select_quality'),
              onTap: () => _showQualitySheet(state),
            ),
            if (state.lines.length > 1)
              _controlBarButton(
                icon: Remix.route_line,
                tooltip: i18n('multiview_line_selector'),
                onTap: () => _showLineSheet(state),
              ),
            _controlBarButton(
              icon: Remix.volume_down_line,
              tooltip: i18n('multiview_volume'),
              onTap: () => _showVolumeSheet(bigIndex),
            ),
            _controlBarButton(
              icon: _displayMode == _DisplayMode.fullscreen ? Remix.fullscreen_exit_line : Remix.fullscreen_line,
              tooltip: i18n('multiview_fullscreen'),
              onTap: () => unawaited(
                _changeDisplayMode(
                  _displayMode == _DisplayMode.fullscreen ? _DisplayMode.normal : _DisplayMode.fullscreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.standard,
      constraints: const BoxConstraints(minWidth: kMinInteractiveDimension, minHeight: kMinInteractiveDimension),
      icon: Icon(icon, size: 20, color: iconColor ?? Colors.white.withValues(alpha: 0.92)),
      onPressed: onTap,
    );
  }

  void _showLineSheet(MultiviewCellState state) {
    if (state.lines.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < state.lines.length; i++)
              ListTile(
                title: Text(i18n('multiview_line', args: {'index': '${i + 1}'})),
                trailing: i == state.lineIndex ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(controller.setCellLine(state.index, i));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showVolumeSheet(int cellIndex) {
    var value = controller.cellVolume(cellIndex);
    final room = controller.cells[cellIndex].room;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room?.nick?.trim().isNotEmpty == true ? room!.nick! : i18n('multiview_volume'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    Text('${(value * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Remix.volume_down_line),
                    Expanded(
                      child: Slider(
                        value: value,
                        onChanged: (v) {
                          setSheetState(() => value = v);
                          unawaited(controller.setCellVolume(cellIndex, v));
                        },
                      ),
                    ),
                    const Icon(Remix.volume_up_line),
                  ],
                ),
                Text(
                  i18n('room_volume'),
                  style: Theme.of(sheetContext).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDanmakuSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.72,
        child: DanmakuSettingsContent(controller: MultiviewDanmakuSettingsSource(), embedded: true),
      ),
    );
  }

  Widget _buildCellAt(
    List<MultiviewCellState> cells,
    int index, {
    required bool isWide,
    bool showDanmaku = false,
    bool showQualityEntry = false,
  }) {
    final state = cells[index];
    final status = state.status;
    return _MultiviewCellView(
      key: _cellKey(index),
      cellIndex: index,
      onRenderResize: (width, height) async {
        final wallCell = controller.wallCellAt(index);
        final playerId = wallCell?.playerId;
        final handle = playerId == null ? null : PlayerKernelService.instance.kernel.get(PlayerId(playerId));
        final adapter = handle?.adapter;
        if (adapter is MediaKitPlayerAdapter) {
          await adapter.setRenderTargetSize(width: width, height: height);
        }
      },
      state: state,
      isAudioFocus: controller.audioFocusIndex == index && status == MultiviewCellStatus.playing,
      isPickTarget: _targetCell == index && isMultiviewCellAssignable(status),
      showDanmaku: showDanmaku && status == MultiviewCellStatus.playing && state.videoController != null,
      barrageController: controller.barrageController,
      showQualityEntry: showQualityEntry,
      onSelectQuality: (qualityIndex) => unawaited(controller.setCellQuality(index, qualityIndex)),
      onTap: () {
        switch (status) {
          case MultiviewCellStatus.playing:
            if (controller.layout.value == MultiviewLayout.focus && controller.focusedCellIndex.value != index) {
              unawaited(controller.promoteCell(index));
              _largeControlsVisible = false;
              setState(() {});
              return;
            }
            if (controller.layout.value == MultiviewLayout.focus) {
              setState(() => _largeControlsVisible = !_largeControlsVisible);
              return;
            }
            unawaited(controller.setAudioFocus(index));
          case MultiviewCellStatus.empty || MultiviewCellStatus.offline || MultiviewCellStatus.error:
            _openPickerFor(index, isWide: isWide);
          case MultiviewCellStatus.resolving:
            break;
        }
      },
      onLongPress: status == MultiviewCellStatus.playing ? () => _showCellActions(state) : null,
      onRetry: () => _retryCell(state),
    );
  }
}

class _MultiviewCellView extends StatelessWidget {
  const _MultiviewCellView({
    super.key,
    required this.state,
    required this.isAudioFocus,
    required this.isPickTarget,
    required this.onTap,
    required this.onLongPress,
    required this.onRetry,
    required this.barrageController,
    required this.onSelectQuality,
    required this.cellIndex,
    required this.onRenderResize,
    this.showDanmaku = false,
    this.showQualityEntry = false,
  });

  final MultiviewCellState state;
  final bool isAudioFocus;
  final bool isPickTarget;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onRetry;

  final bool showDanmaku;
  final BarrageController barrageController;

  final int cellIndex;

  final Future<void> Function(int width, int height) onRenderResize;

  final bool showQualityEntry;
  final ValueChanged<int> onSelectQuality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final videoController = state.videoController;
    final showVideo = state.status == MultiviewCellStatus.playing && videoController != null;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: showVideo || isDark ? Colors.black : theme.colorScheme.surfaceContainerLow),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          child: _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final videoController = state.videoController;
    if (state.status == MultiviewCellStatus.playing && videoController != null) {
      final video = Video(
        controller: videoController,
        controls: NoVideoControls,
        pauseUponEnteringBackgroundMode: false,
        resumeUponEnteringForegroundMode: false,
      );
      final videoSurface = PlatformUtils.isWindows
          ? VideoOutputViewportSizer(
              outputIdentity: videoController,
              sourceWidth: videoController.player.stream.width,
              sourceHeight: videoController.player.stream.height,
              fit: BoxFit.contain,
              onResize: (width, height, force) => onRenderResize(width, height),
              child: video,
            )
          : video;
      return Stack(
        fit: StackFit.expand,
        children: [
          videoSurface,
          if (showDanmaku)
            Positioned.fill(
              child: IgnorePointer(
                child: _MultiviewDanmakuLayer(controller: videoController, barrageController: barrageController),
              ),
            ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoomNameChip(state: state),
                if (isAudioFocus) ...[const SizedBox(width: 6), const _AudioFocusBadge()],
              ],
            ),
          ),
          if (showQualityEntry) Positioned(left: 8, bottom: 8, child: _buildQualityEntry(theme)),
        ],
      );
    }
    return switch (state.status) {
      MultiviewCellStatus.empty => _buildEmptyContent(theme),
      MultiviewCellStatus.resolving => _buildResolvingContent(),
      MultiviewCellStatus.offline => _buildOfflineContent(theme),
      MultiviewCellStatus.error => _buildErrorContent(theme),
      MultiviewCellStatus.playing => const SizedBox.shrink(),
    };
  }

  bool get _qualityAvailable =>
      state.status == MultiviewCellStatus.playing && state.qualities.isNotEmpty && state.qualityLoader != null;

  Widget _buildQualityEntry(ThemeData theme) {
    if (!_qualityAvailable) return const SizedBox.shrink();
    final currentName = state.qualities[state.qualityIndex.clamp(0, state.qualities.length - 1)].quality;
    return PopupMenuButton<int>(
      key: const ValueKey('multiview-quality-selector'),
      tooltip: i18n('select_quality'),
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 5),
      position: PopupMenuPosition.under,
      onSelected: onSelectQuality,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: kMinInteractiveDimension, minHeight: kMinInteractiveDimension),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Remix.equalizer_line, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  currentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.t11.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (context) => [
        for (var i = 0; i < state.qualities.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              state.qualities[i].quality,
              style: AppTextStyles.t13.copyWith(
                color: i == state.qualityIndex ? theme.colorScheme.primary : null,
                fontWeight: i == state.qualityIndex ? FontWeight.w700 : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyContent(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            ),
            child: Icon(Remix.add_circle_line, size: 26, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(i18n('multiview_empty_cell_hint'), style: AppTextStyles.t14Medium),
        ],
      ),
    );
  }

  Widget _buildResolvingContent() {
    final roomLabel = _multiviewRoomLabel(state.room);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          if (roomLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(roomLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.t12Muted),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineContent(ThemeData theme) {
    final roomLabel = _multiviewRoomLabel(state.room);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Remix.live_line, size: 30, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(i18n('multiview_room_offline'), style: AppTextStyles.t14Bold, textAlign: TextAlign.center),
          if (roomLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(roomLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.t12Muted),
          ],
          const SizedBox(height: 6),
          Text(i18n('multiview_room_offline_hint'), style: AppTextStyles.t12Muted, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorContent(ThemeData theme) {
    final kind = state.errorKind;
    final detailMessage = kind == null
        ? ''
        : i18n(
            switch (kind) {
              MultiviewCellErrorKind.resolveFailure => 'multiview_error_resolve',
              MultiviewCellErrorKind.startFailure => 'multiview_error_start',
            },
            args: {'detail': state.errorDetail ?? ''},
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Remix.error_warning_line, size: 30, color: theme.colorScheme.error),
          const SizedBox(height: 10),
          Text(i18n('multiview_play_failed'), style: AppTextStyles.t14Bold, textAlign: TextAlign.center),
          if (detailMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detailMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.t12Muted,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Remix.refresh_line, size: 16),
            label: Text(i18n('retry')),
          ),
        ],
      ),
    );
  }
}

String _multiviewRoomLabel(LiveRoom? liveroom) {
  if (liveroom == null) return '';
  for (final candidate in [liveroom.nick, liveroom.title, liveroom.roomId]) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

class _RoomNameChip extends StatelessWidget {
  const _RoomNameChip({required this.state});

  final MultiviewCellState state;

  @override
  Widget build(BuildContext context) {
    final nick = state.room?.nick ?? '';
    final platform = state.room?.platform?.trim().toLowerCase() ?? '';
    final hasLogo = Sites.isSupported(platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLogo) ...[Image.asset(Sites.logoForId(platform), width: 13, height: 13), const SizedBox(width: 5)],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              nick,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.t11.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioFocusBadge extends StatelessWidget {
  const _AudioFocusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Remix.volume_up_line, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            i18n('multiview_audio_focus_badge'),
            style: AppTextStyles.t11.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MultiviewDanmakuLayer extends StatelessWidget {
  const _MultiviewDanmakuLayer({required this.controller, required this.barrageController});

  final VideoController controller;
  final BarrageController barrageController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: controller.player.stream.width,
      initialData: controller.player.state.width,
      builder: (context, width) => StreamBuilder<int?>(
        stream: controller.player.stream.height,
        initialData: controller.player.state.height,
        builder: (context, height) => _buildLayer(width.data, height.data),
      ),
    );
  }

  Widget _buildLayer(int? width, int? height) {
    return Obx(() {
      SettingsService.to.app.refreshRateModeName.v;
      final isVerticalVideo = width != null && height != null && width > 0 && height > 0 && height > width;
      final mode = SettingsService.to.player.portraitDanmakuMode;
      if (PortraitDanmakuPolicy.hidesDanmaku(isVerticalVideo: isVerticalVideo, mode: mode)) {
        return const SizedBox.shrink();
      }
      return FlameBarrageWidget(
        controller: barrageController,
        enablePointerEvents: false,
        config: _buildBarrageConfig(isVerticalVideo: isVerticalVideo),
        emojiAtlas: EmojiAtlas.instance,
      );
    });
  }
}

BarrageConfig _buildBarrageConfig({required bool isVerticalVideo}) {
  final settings = SettingsService.to.danmaku;
  return BarrageConfig(
    emitInterval: 0.05,
    fontSize: settings.danmakuFontSize.v,
    topAreaDistance: settings.danmakuTopArea.v,
    area: PortraitDanmakuPolicy.effectiveArea(
      configuredArea: settings.danmakuArea.v,
      isVerticalVideo: isVerticalVideo,
      mode: SettingsService.to.player.portraitDanmakuMode,
    ),
    bottomAreaDistance: settings.danmakuBottomArea.v,
    baseSpeed: settings.danmakuSpeed.v,
    opacity: settings.danmakuOpacity.v,
    fontWeight: FontWeight(settings.danmakuFontWeight.v),
    letterSpacing: settings.danmakuLetterSpacing.v,
    strokeWidth: settings.danmakuFontBorder.v,
    showStroke: settings.enableDanmakuStroke.v,
    noEmojiMode: settings.noEmojiMode.v,
    realtimeMode: settings.danmakuMassMode.v,
    fps: settings.danmakuAutoFps.v
        ? settings.resolvedDanmakuFps(refreshRateMode: SettingsService.to.app.refreshRateMode)
        : settings.danmakuFps.v.clamp(30, 240).toInt(),
    maxVisibleCount: settings.effectiveMaxVisibleCount,
    maxPendingCount: 120,
    maxPendingAge: const Duration(seconds: 5),
    fontFamily: settings.danmakuFontFamilyName.v,
    trackHeight: (settings.danmakuFontSize.v * 1.55).clamp(24.0, 64.0).toDouble(),
    emojiSize: (settings.danmakuFontSize.v * 1.3).clamp(16.0, 48.0).toDouble(),
    pictureCacheMaxSize: 96,
    barragePoolMaxSize: 72,
    textCacheMaxSize: 320,
    safeArea: false,
  );
}

class _AddCellSlot extends StatelessWidget {
  const _AddCellSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 1.5),
            color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Remix.add_circle_line, size: 22, color: theme.colorScheme.primary),
                const SizedBox(height: 6),
                Text(
                  i18n('multiview_add_cell'),
                  style: AppTextStyles.t12.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImmersiveRestoreButton extends StatelessWidget {
  const _ImmersiveRestoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: i18n('multiview_immersive_exit'),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(
              width: kMinInteractiveDimension,
              height: kMinInteractiveDimension,
            ),
            child: Icon(Remix.collapse_diagonal_line, size: 20, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
