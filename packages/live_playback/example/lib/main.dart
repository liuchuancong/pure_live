// A runnable tour of `live_playback`.
//
// Every scenario this package is responsible for is a button here, and every
// button acts on the real service: the same coordinator, the same orchestration,
// the same recovery ladder. Only the *backend* is fake — the kernel runs the
// `testing` adapter instead of a codec — so the tour needs no stream, no
// network and no platform window system.
//
// Two things are worth watching while walking it:
//
// - the audio owner moves by itself. Opening a room, focusing a tile, handing
//   the picture to a small window and returning to a page each end with exactly
//   one window audible, and the log says which;
// - the picture's position and shape come from the service, not from this file.
//   The small window's rect is resolved by the sizing engine and remembered per
//   room, surface and video orientation: drag it in portrait, switch to
//   landscape, drag again, switch back.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:live_playback/live_playback.dart';
import 'package:live_playback_example/demo_runtime.dart';
import 'package:media_core/media_core.dart';

void main() => runApp(const LivePlaybackDemoApp());

/// Root of the demo app.
class LivePlaybackDemoApp extends StatelessWidget {
  /// Creates the app.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'live_playback demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const DemoHomePage(),
    );
  }
}

/// The demo page: state bar, stage, control tabs and a log.
class DemoHomePage extends StatefulWidget {
  /// Creates the page.
  ///
  /// [runtime] is injectable so a widget test can drive the tour without
  /// building a second service; the demo itself creates one.
  const new({super.key, this.runtime});

  /// The runtime to drive, when a test supplies one.
  final DemoRuntime? runtime;

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> with WidgetsBindingObserver {
  late final DemoRuntime _runtime = widget.runtime ?? DemoRuntime();
  late final PlaybackService _service = _runtime.service;

  int _feedIndex = -1;
  bool _portraitVideo = true;
  Rect? _windowRect;
  Size? _stageArea;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.stateStream.listen((_) => unawaited(_syncWindowRect()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.runtime == null) {
      unawaited(_runtime.dispose());
    }
    super.dispose();
  }

  /// Real lifecycle: minimise the window and the policy runs for real.
  ///
  /// The buttons below do the same thing by hand, because "watch the log when
  /// you minimise" is a worse demo than "press this".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    unawaited(_service.setVisible(isVisible: visible));
  }

  PlaybackSystemState get _state => _service.state;

  /// Re-resolves the small window's rect for the current mode and geometry.
  Future<void> _syncWindowRect() async {
    final state = _state;
    final id = state.overlaySessionId;
    final area = _stageArea;

    if (id == null || area == null || !state.isOverlay) {
      if (_windowRect != null) {
        setState(() => _windowRect = null);
      }
      return;
    }

    final surface = state.presentationMode.isPip ? WindowSurface.pip : WindowSurface.floating;
    final rect = await _service.presentation.resolveWindowRect(
      sessionId: id,
      surface: surface,
      area: area,
      geometry: _runtime.geometryOf(portrait: _portraitVideo),
    );

    if (!mounted) {
      return;
    }
    setState(() => _windowRect = rect);
  }

  Future<void> _rememberWindowRect() async {
    final state = _state;
    final id = state.overlaySessionId;
    final rect = _windowRect;
    if (id == null || rect == null) {
      return;
    }

    final surface = state.presentationMode.isPip ? WindowSurface.pip : WindowSurface.floating;
    await _service.presentation.rememberWindowRect(
      sessionId: id,
      surface: surface,
      orientation: _runtime.geometryOf(portrait: _portraitVideo).orientation.effectiveOrientation,
      rect: rect,
    );
    _runtime.note('记住 $id/${surface.storageKey} 的窗口位置 ${rect.left.round()},${rect.top.round()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('live_playback demo'),
        actions: [
          IconButton(
            key: const Key('forget-layout'),
            tooltip: '清除记忆的窗口布局',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final id = _state.overlaySessionId ?? _state.primarySessionId;
              if (id != null) {
                await _service.presentation.preferences.forgetSession(id);
                _runtime.note('清除 $id 的记忆布局');
                await _syncWindowRect();
              }
            },
          ),
        ],
      ),
      // The state bar stays put: the panels below scroll, and a demo whose
      // readout scrolls away while you press buttons is a worse demo.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _StateBar(service: _service),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _Stage(
                  runtime: _runtime,
                  portrait: _portraitVideo,
                  windowRect: _windowRect,
                  onToggleOrientation: () {
                    setState(() => _portraitVideo = !_portraitVideo);
                    _runtime.note('视频方向 -> ${_portraitVideo ? "竖屏" : "横屏"}');
                    unawaited(_syncWindowRect());
                  },
                  onAreaChanged: (area) {
                    if (_stageArea == area) {
                      return;
                    }
                    _stageArea = area;
                    unawaited(_syncWindowRect());
                  },
                  onDragEnd: (rect) {
                    setState(() => _windowRect = rect);
                    unawaited(_rememberWindowRect());
                  },
                ),
                const SizedBox(height: 12),
                _LiveRoomControls(runtime: _runtime, onChanged: () => unawaited(_syncWindowRect())),
                _FeedControls(runtime: _runtime, index: () => _feedIndex, onIndex: (i) => _feedIndex = i),
                _MultiViewControls(runtime: _runtime),
                _PolicyControls(runtime: _runtime),
                const SizedBox(height: 12),
                _LogPanel(runtime: _runtime),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The snapshot the UI renders: one row of chips.
class _StateBar extends StatelessWidget {
  const new({required this.service});

  final PlaybackService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackSystemState>(
      stream: service.stateStream,
      initialData: service.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PlaybackSystemState.idle;
        final primary = state.primary;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(label: '模式: ${state.presentationMode.name}', key: const Key('chip-mode')),
            _Chip(label: '有声音: ${state.primarySessionId ?? "无"}', key: const Key('chip-primary')),
            _Chip(label: '小窗: ${state.overlaySessionId ?? "无"}', key: const Key('chip-overlay')),
            _Chip(label: '后台: ${state.isBackgrounded ? "是" : "否"}', key: const Key('chip-backgrounded')),
            _Chip(label: '全静音: ${state.allMuted ? "是" : "否"}', key: const Key('chip-muted')),
            _Chip(
              label:
                  '弹幕: ${primary == null ? "—" : (primary.danmakuEnabled ? "显示" : "隐藏")}'
                  '${state.allDanmakuDisabled ? "（全局关）" : ""}',
              key: const Key('chip-chat'),
            ),
            _Chip(label: '会话: ${state.sessions.length}', key: const Key('chip-sessions')),
            _Chip(
              label:
                  '画面: ${primary == null ? "—" : "${primary.isPlaying ? "播放中" : "暂停"}${primary.muted ? " / 静音" : ""}"}',
              key: const Key('chip-playback'),
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const new({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// The pretend video: a full-size picture, or a small window on top of it.
class _Stage extends StatelessWidget {
  const new({
    required this.runtime,
    required this.portrait,
    required this.windowRect,
    required this.onToggleOrientation,
    required this.onAreaChanged,
    required this.onDragEnd,
  });

  final DemoRuntime runtime;
  final bool portrait;
  final Rect? windowRect;
  final VoidCallback onToggleOrientation;
  final ValueChanged<Size> onAreaChanged;
  final ValueChanged<Rect> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final state = runtime.service.state;
    final primary = state.primary;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final area = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) => onAreaChanged(area));
          return DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFF101725), borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    primary == null
                        ? '没有会话 — 点下面的按钮开一个'
                        : '${primary.metadata.displayName.isEmpty ? primary.id : primary.metadata.displayName}'
                              '\n${primary.isPlaying ? "▶" : "⏸"} ${primary.muted ? "🔇" : "🔊"}'
                              '${primary.danmakuEnabled ? " 💬" : ""}',
                    key: const Key('stage-main'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                if (windowRect != null && state.isOverlay)
                  Positioned(
                    left: windowRect!.left,
                    top: windowRect!.top,
                    width: windowRect!.width,
                    height: windowRect!.height,
                    child: GestureDetector(
                      key: const Key('stage-window'),
                      onPanUpdate: (details) {
                        // Move locally while dragging; the service is told once
                        // the drag ends — a hundred writes for one drag is a
                        // hundred chances to lose the last one.
                        final moved = windowRect!.shift(details.delta);
                        onDragEnd(moved);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF23324D),
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '小窗 ${windowRect!.width.round()}×${windowRect!.height.round()}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: TextButton(
                    key: const Key('stage-orientation'),
                    onPressed: onToggleOrientation,
                    child: Text(portrait ? '竖屏视频' : '横屏视频', style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Live-room page: open, park, resume, mute, chat, fullscreen, overlays.
class _LiveRoomControls extends StatelessWidget {
  const new({required this.runtime, required this.onChanged});

  final DemoRuntime runtime;
  final VoidCallback onChanged;

  PlaybackService get _service => runtime.service;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '直播页',
      subtitle: '打开直播间 A，再打开一个录播：直播会被暂停保留；返回直播会重开线路回到直播边缘。',
      children: [
        _Action(
          key: const Key('live-a'),
          label: '打开直播间 A',
          onPressed: () async {
            await _service.openLive(id: 'room-1', source: runtime.liveSource('room-1'));
            runtime.note('打开 room-1');
            onChanged();
          },
        ),
        _Action(
          key: const Key('live-b'),
          label: '打开直播间 B',
          onPressed: () async {
            await _service.openLive(id: 'room-2', source: runtime.liveSource('room-2'));
            runtime.note('打开 room-2（另一个直播间会关闭）');
            onChanged();
          },
        ),
        _Action(
          key: const Key('open-recorded'),
          label: '打开录播',
          onPressed: () async {
            await _service.openRecorded(id: 'video-1', source: runtime.recordedSource('video-1'));
            runtime.note('打开录播（直播被 park）');
            onChanged();
          },
        ),
        _Action(
          key: const Key('return-live'),
          label: '返回直播',
          onPressed: () async {
            await _service.returnToSuspendedLive();
            runtime.note('返回直播间，线路重开');
            onChanged();
          },
        ),
        _Action(
          key: const Key('toggle-mute'),
          label: '静音 / 取消',
          onPressed: () async {
            final muted = _service.state.allMuted;
            await _service.setMuted(muted: !muted);
            onChanged();
          },
        ),
        _Action(
          key: const Key('toggle-chat'),
          label: '弹幕开关（全局）',
          onPressed: () async {
            await _service.setDanmakuEnabled(enabled: _service.state.allDanmakuDisabled);
            onChanged();
          },
        ),
        _Action(
          key: const Key('fullscreen'),
          label: '全屏',
          onPressed: () async {
            await _service.setPresentationMode(PresentationMode.fullscreen);
            onChanged();
          },
        ),
        _Action(
          key: const Key('to-floating'),
          label: '交给小窗',
          onPressed: () async {
            await _service.handOffToOverlay();
            runtime.note('画面交给应用内小窗');
            onChanged();
          },
        ),
        _Action(
          key: const Key('to-pip'),
          label: '交给画中画',
          onPressed: () async {
            if (!_service.presentation.canEnterPip) {
              runtime.note('画中画被拒绝：设置或平台不支持（点下面的开关让平台支持它）');
              return;
            }
            await _service.handOffToOverlay(surface: WindowSurface.pip);
            runtime.note('画面交给画中画');
            onChanged();
          },
        ),
        _Action(
          key: const Key('exit-overlay'),
          label: '退出悬浮窗',
          onPressed: () async {
            await _service.exitOverlay();
            onChanged();
          },
        ),
        _Action(
          key: const Key('close-all'),
          label: '关闭全部',
          onPressed: () async {
            await _service.close();
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Feed page: previews, immersive scrolling, detail and its hand-off.
class _FeedControls extends StatelessWidget {
  const new({required this.runtime, required this.index, required this.onIndex});

  final DemoRuntime runtime;
  final int Function() index;
  final void Function(int) onIndex;

  FeedPlaybackManager get _feed => runtime.service.feed;

  Future<FeedEntry> _entry(int i) async => FeedEntry(
    id: 'v-$i',
    source: runtime.recordedSource('v-$i'),
    metadata: PlaybackMetadata(title: '视频 $i'),
    contentType: ContentType.recorded,
  );

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '列表 / 详情',
      subtitle: '预览模式下格子静音且不占声音通道；进详情变可听；退出时可以选择留给小窗（不会被滑动回收）。',
      children: [
        _Action(
          key: const Key('feed-preview'),
          label: '预览模式',
          onPressed: () async {
            await _feed.setMode(FeedPlaybackMode.preview);
            runtime.note('列表 -> 预览模式（静音格子）');
          },
        ),
        _Action(
          key: const Key('feed-immersive'),
          label: '沉浸模式',
          onPressed: () async {
            await _feed.setMode(FeedPlaybackMode.immersive);
            runtime.note('列表 -> 沉浸模式（当前项可听）');
          },
        ),
        _Action(
          key: const Key('feed-next'),
          label: '滑到下一个',
          onPressed: () async {
            final next = index() + 1;
            await _feed.scrollToIndex(next, _entry);
            onIndex(next);
            runtime.note('滑到 index $next');
          },
        ),
        _Action(
          key: const Key('feed-detail'),
          label: '进详情',
          onPressed: () async {
            final current = index() < 0 ? 0 : index();
            await _feed.openDetail(current, _entry);
            onIndex(current);
            runtime.note('详情页：index $current');
          },
        ),
        _Action(
          key: const Key('feed-close'),
          label: '退出详情',
          onPressed: () async {
            await _feed.closeDetail();
            runtime.note('回到列表（暂停并记住位置）');
          },
        ),
        _Action(
          key: const Key('feed-close-overlay'),
          label: '退出详情 → 小窗',
          onPressed: () async {
            final id = runtime.service.state.sessions.keys.firstOrNull;
            await _handOffToSmallWindow(id);
            await _feed.closeDetail(keepInOverlay: true);
            runtime.note('退出详情，画面留在小窗（滑动列表不会回收它）');
          },
        ),
      ],
    );
  }

  Future<void> _handOffToSmallWindow(String? id) async {
    if (id == null) {
      return;
    }
    await runtime.service.handOffToOverlay(id: id);
  }
}

/// Multi-view: tiles, focus, synchronized transport.
class _MultiViewControls extends StatelessWidget {
  const new({required this.runtime});

  final DemoRuntime runtime;

  PlaybackService get _service => runtime.service;

  Future<void> _add(String id) async {
    if (!_service.coordinator.contains(id)) {
      await _service.coordinator.startSession(id: id, source: runtime.liveSource(id), autoPlay: false);
    }
    await _service.multiView.addSlot(MultiViewSlot(id: id));
    runtime.note('加入画面 $id');
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '多画面',
      subtitle: '第一个格子出声、其余静音；点格子只换声音；关掉正在发声的格子会把声音交给下一个。',
      children: [
        for (final id in <String>['room-1', 'room-2', 'room-3'])
          _Action(key: Key('mv-add-$id'), label: '加 $id', onPressed: () => _add(id)),
        for (final id in <String>['room-1', 'room-2', 'room-3'])
          _Action(
            key: Key('mv-focus-$id'),
            label: '听 $id',
            onPressed: () async {
              await _service.multiView.focusSlot(id);
            },
          ),
        _Action(key: const Key('mv-play'), label: '全部播放', onPressed: () => _service.multiView.playAll()),
        _Action(key: const Key('mv-pause'), label: '全部暂停', onPressed: () => _service.multiView.pauseAll()),
        _Action(key: const Key('mv-mute'), label: '全部静音', onPressed: () => _service.multiView.muteAll()),
        _Action(key: const Key('mv-clear'), label: '清空画面', onPressed: () => _service.multiView.clear()),
      ],
    );
  }
}

/// The background policy and the settings it reads.
class _PolicyControls extends StatelessWidget {
  const new({required this.runtime});

  final DemoRuntime runtime;

  PlaybackService get _service => runtime.service;

  @override
  Widget build(BuildContext context) {
    // Two sources, because the two halves of this panel move independently:
    // the viewer's settings are a [Listenable], and the platform's capabilities
    // arrive on the presentation state (a driver attaching, a permission being
    // granted). Watching the controller's state is also what a host does.
    return ListenableBuilder(
      listenable: runtime.settings,
      builder: (context, _) => StreamBuilder<PresentationState>(
        stream: runtime.service.presentationController.state,
        initialData: runtime.service.presentationController.current,
        builder: (context, _) => _panel(context),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final settings = runtime.settings;
    final adapter = runtime.adapter;

    return _Panel(
      title: '后台策略 / 设置',
      subtitle: '退到后台时：允许画中画就进画中画，否则允许后台播放就只留声音，都不允许就暂停。设置可以在播放中改。',
      children: [
        _Action(
          key: const Key('bg-back'),
          label: '模拟退到后台',
          onPressed: () async {
            await _service.setVisible(isVisible: false);
            runtime.note('退到后台');
          },
        ),
        _Action(
          key: const Key('bg-front'),
          label: '回到前台',
          onPressed: () async {
            await _service.setVisible(isVisible: true);
            runtime.note('回到前台');
          },
        ),
        _Action(
          key: const Key('set-bg'),
          label: '后台播放: ${settings.allowBackgroundPlayback ? "开" : "关"}',
          onPressed: () {
            settings.update(allowBackgroundPlayback: !settings.allowBackgroundPlayback);
            runtime.note('设置：后台播放 ${settings.allowBackgroundPlayback}');
          },
        ),
        _Action(
          key: const Key('set-pip'),
          label: '允许画中画: ${settings.allowPictureInPicture ? "开" : "关"}',
          onPressed: () {
            settings.update(allowPictureInPicture: !settings.allowPictureInPicture);
            runtime.note('设置：允许画中画 ${settings.allowPictureInPicture}');
          },
        ),
        _Action(
          key: const Key('set-floating'),
          label: '允许小窗: ${settings.allowFloatingWindow ? "开" : "关"}',
          onPressed: () {
            settings.update(allowFloatingWindow: !settings.allowFloatingWindow);
            runtime.note('设置：允许小窗 ${settings.allowFloatingWindow}');
          },
        ),
        _Action(
          key: const Key('set-platform-pip'),
          label: '平台支持画中画: ${adapter.capabilities.canPip ? "有" : "无"}',
          onPressed: () {
            adapter.setCapabilities(pip: !adapter.capabilities.canPip);
            runtime.note('平台能力：画中画 ${adapter.capabilities.canPip}');
          },
        ),
        _Action(
          key: const Key('set-platform-floating'),
          label: '平台支持小窗: ${adapter.capabilities.canFloating ? "有" : "无"}',
          onPressed: () {
            adapter.setCapabilities(floating: !adapter.capabilities.canFloating);
            runtime.note('平台能力：小窗 ${adapter.capabilities.canFloating}');
          },
        ),
      ],
    );
  }
}

/// The event log.
class _LogPanel extends StatelessWidget {
  const new({required this.runtime});

  final DemoRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '日志',
      subtitle: '服务自己报告的状态变化，不是按钮日志：声音归属、悬浮窗、前后台、静音与弹幕。',
      children: [
        ValueListenableBuilder<List<String>>(
          valueListenable: runtime.log,
          builder: (context, lines, _) {
            final tail = lines.length > 14 ? lines.sublist(lines.length - 14) : lines;
            return SizedBox(
              width: double.infinity,
              child: Text(
                tail.join('\n'),
                key: const Key('log'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const new({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const new({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
