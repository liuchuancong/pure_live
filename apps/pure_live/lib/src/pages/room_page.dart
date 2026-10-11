import 'dart:async';

import 'package:flutter/material.dart';
import 'package:live_interaction/live_interaction.dart';
import 'package:live_log/live_log.dart';
import 'package:live_sites/live_sites.dart' as sites;
import 'package:live_uikit/live_uikit.dart';

import 'package:pure_live/src/services.dart';

/// One room: what it is, what it offers, and what it is saying.
///
/// The page is the application's proof that the layers line up: the site
/// adapter loads the detail and resolves the play qualities and lines, the
/// interaction session connects the danmaku through the same site's
/// capability, and the library records the visit. The player kernel itself is
/// `media_core`, which owns the video surface; this page resolves everything a
/// player needs — signed URLs with their headers, leases, codecs — and hands
/// that to the shell, so wiring the kernel changes no page and no site.
class RoomPage extends StatefulWidget {
  /// A room page for [room].
  const new({required this.services, required this.room, super.key});

  /// The service graph.
  final PureLiveServices services;

  /// The room to open; a directory snapshot, refined by `getRoomDetail`.
  final sites.LiveRoom room;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late sites.LiveRoom _room = widget.room;
  final List<sites.LiveMessage> _messages = [];
  InteractionSession? _interaction;
  StreamSubscription<InteractionState>? _interactionState;
  List<sites.LivePlayQuality> _qualities = const [];
  sites.LivePlayQuality? _quality;
  List<sites.LivePlayLine> _lines = const [];
  InteractionPhase _interactionPhase = InteractionPhase.idle;
  bool _loading = true;
  bool _resolving = false;
  bool _followed = false;
  Object? _failure;

  sites.LiveSite get _site => widget.services.sites[_room.platform]!;

  @override
  void initState() {
    super.initState();
    _followed = widget.services.library.isFollowed(_room);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_open()));
  }

  @override
  void dispose() {
    final states = _interactionState;
    _interactionState = null;
    if (states != null) {
      unawaited(states.cancel());
    }
    // The session's teardown closes sockets; it is deliberately not awaited,
    // because disposing a page cannot block on a network round trip.
    final interaction = _interaction;
    if (interaction != null) {
      unawaited(interaction.dispose());
    }
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final log = widget.services.log.forCategory('app.room');
    try {
      final detail = await _site.getRoomDetail(_room);
      final qualities = await _site.getPlayQualities(detail);
      if (!mounted) {
        return;
      }
      setState(() {
        _room = detail;
        _qualities = qualities;
        _quality = qualities.isEmpty ? null : qualities.reduce((a, b) => a.sort >= b.sort ? a : b);
        _loading = false;
      });
      if (_quality != null) {
        await _resolveLines(_quality!);
      }
      await _recordVisit();
      await _connectDanmaku();
    } on Object catch (error, stack) {
      log.log(LogLevel.warning, 'opening ${_room.identity} failed', error: error, stackTrace: stack);
      if (mounted) {
        setState(() {
          _failure = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _resolveLines(sites.LivePlayQuality quality) async {
    setState(() {
      _resolving = true;
      _failure = null;
    });
    try {
      final lines = await _site.getPlayUrls(_room, quality);
      if (mounted) {
        setState(() {
          _lines = lines;
          _resolving = false;
        });
      }
    } on Object catch (error, stack) {
      widget.services.log
          .forCategory('app.room')
          .log(LogLevel.warning, 'resolving ${_room.identity} lines failed', error: error, stackTrace: stack);
      if (mounted) {
        setState(() {
          _failure = error;
          _resolving = false;
        });
      }
    }
  }

  /// Records the visit so the room appears in the history and its snapshot is
  /// refreshed for the next cold start.
  Future<void> _recordVisit() async {
    await widget.services.history.record(_room);
    final record = widget.services.library.recordOf(_room);
    if (record != null) {
      await widget.services.library.replaceRoom(_room);
    }
  }

  /// Connects the danmaku through the site's capability.
  ///
  /// A site that cannot connect a room simply does not implement the
  /// capability, and the page says so instead of pretending to listen.
  Future<void> _connectDanmaku() async {
    final log = widget.services.log.forCategory('app.room.danmaku');
    final site = _site;
    if (site is! sites.LiveDanmakuCapability) {
      return;
    }
    // The capability is resolved once: the connect callback runs again on
    // every reconnect, and it must call this site's session, not a lookup.
    final capability = site as sites.LiveDanmakuCapability;
    final session = InteractionSession(sources: [DanmakuInteractionSource(connect: () => capability.connect(_room))]);
    _interactionState = session.states.listen((state) {
      if (mounted) {
        setState(() => _interactionPhase = state.phase);
      }
    });
    _interaction = session;
    await session.start();
    session.messages.listen(
      (message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _messages.add(message);
          if (_messages.length > 200) {
            _messages.removeRange(0, _messages.length - 200);
          }
        });
      },
      onError: (Object error, StackTrace stack) =>
          log.log(LogLevel.warning, 'danmaku stream failed', error: error, stackTrace: stack),
    );
  }

  Future<void> _toggleFollow() async {
    final library = widget.services.library;
    if (library.isFollowed(_room)) {
      await library.unfollow(_room);
    } else {
      await library.follow(_room);
    }
    if (mounted) {
      setState(() => _followed = library.isFollowed(_room));
    }
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _site.refreshLiveStatus(_room);
      if (mounted) {
        setState(() => _room = fresh);
      }
    } on Object catch (error, stack) {
      widget.services.log
          .forCategory('app.room')
          .log(LogLevel.warning, 'refreshing ${_room.identity} failed', error: error, stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final environment = LiveEnvironmentScope.of(context);
    final geometry = theme.componentTheme;
    return Scaffold(
      backgroundColor: theme.colors.surface,
      body: SafeArea(
        child: Padding(
          padding: geometry.pagePaddingFor(environment.layoutMode),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              SizedBox(height: geometry.sectionGap),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return Row(
      children: [
        LiveIconButton(icon: Icons.arrow_back, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        SizedBox(width: geometry.iconGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _room.title.isEmpty ? _room.roomId : _room.title,
                style: theme.typography.title.copyWith(color: theme.colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_room.platform} · ${_room.nick} · ${_room.status.name}'
                '${_room.watching == null ? '' : ' · ${_room.watching} watching'}'
                '${_room.onlineViewers == null ? '' : ' · ${_room.onlineViewers} viewers'}',
                style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        LiveIconButton(
          icon: _followed ? Icons.favorite : Icons.favorite_outline,
          tooltip: _followed ? 'Unfollow' : 'Follow',
          selected: _followed,
          onPressed: _toggleFollow,
        ),
        SizedBox(width: geometry.iconGap),
        LiveIconButton(icon: Icons.refresh, tooltip: 'Refresh status', onPressed: _refresh),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const LiveLoadingView(message: 'Loading the room…');
    }
    if (_failure != null && _lines.isEmpty && _qualities.isEmpty) {
      return LiveErrorView(
        message: 'This room could not be opened.',
        details: '$_failure',
        retryLabel: 'Retry',
        onRetry: _open,
      );
    }
    final environment = LiveEnvironmentScope.of(context);
    final wide = environment.layoutMode != LiveLayoutMode.mobile;
    final details = _details(context);
    final chat = _chat(context);
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: details),
              SizedBox(width: LiveTheme.of(context).componentTheme.sectionGap),
              Expanded(child: chat),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: details)],
          );
  }

  Widget _details(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return ListView(
      children: [
        if (_room.restriction case final restriction?)
          Padding(
            padding: EdgeInsets.only(bottom: geometry.iconGap),
            child: Text(
              'This room is ${restriction.name}.',
              style: theme.typography.bodySmall.copyWith(color: theme.colors.warning),
            ),
          ),
        Text('Qualities', style: theme.typography.subtitle.copyWith(color: theme.colors.textPrimary)),
        SizedBox(height: geometry.iconGap),
        Wrap(
          spacing: geometry.iconGap,
          runSpacing: geometry.iconGap,
          children: [
            for (final quality in _qualities)
              LiveButton(
                label: quality.label,
                size: LiveControlSize.small,
                variant: quality == _quality ? LiveButtonVariant.primary : LiveButtonVariant.outline,
                onPressed: _resolving
                    ? null
                    : () {
                        setState(() => _quality = quality);
                        unawaited(_resolveLines(quality));
                      },
              ),
            if (_qualities.isEmpty)
              Text(
                'No qualities reported',
                style: theme.typography.bodySmall.copyWith(color: theme.colors.textSecondary),
              ),
          ],
        ),
        SizedBox(height: geometry.sectionGap),
        Row(
          children: [
            Expanded(
              child: Text('Lines', style: theme.typography.subtitle.copyWith(color: theme.colors.textPrimary)),
            ),
            if (_resolving) const LiveProgressIndicator(size: LiveControlSize.small),
          ],
        ),
        SizedBox(height: geometry.iconGap),
        if (_lines.isEmpty && !_resolving)
          Text('No line resolved yet.', style: theme.typography.bodySmall.copyWith(color: theme.colors.textSecondary)),
        for (final (index, line) in _lines.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: geometry.iconGap),
            child: LiveCard(
              dense: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Line ${index + 1} · ${line.format.name}'
                    '${line.codec == null ? '' : ' · ${line.codec}'}'
                    '${line.lineId == null ? '' : ' · ${line.lineId}'}',
                    style: theme.typography.bodySmall.copyWith(color: theme.colors.textPrimary),
                  ),
                  const SizedBox(height: LiveSpacing.xxs),
                  Text(
                    line.url,
                    style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (line.lease case final lease? when lease.isExpiring)
                    Text(
                      lease.expiresAt == null
                          ? 'Lease refreshes at ${lease.refreshAt!.toIso8601String()}'
                          : 'Lease expires at ${lease.expiresAt!.toIso8601String()}',
                      style: theme.typography.caption.copyWith(color: theme.colors.textDisabled),
                    ),
                ],
              ),
            ),
          ),
        SizedBox(height: geometry.sectionGap),
        Text(
          'Playback is handed to the media kernel (media_core), which owns the video surface; '
          'this page resolves the lines it needs — URLs, headers and leases.',
          style: theme.typography.caption.copyWith(color: theme.colors.textDisabled),
        ),
      ],
    );
  }

  Widget _chat(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Danmaku', style: theme.typography.subtitle.copyWith(color: theme.colors.textPrimary)),
            ),
            Text(
              _interactionPhase.name,
              style: theme.typography.caption.copyWith(
                color: _interactionPhase == InteractionPhase.connected
                    ? theme.colors.success
                    : theme.colors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: geometry.iconGap),
        Expanded(
          child: LiveCard(
            padding: geometry.cardPaddingDense,
            child: _messages.isEmpty
                ? LiveEmptyView(
                    compact: true,
                    title: _site is sites.LiveDanmakuCapability ? 'No messages yet' : 'No danmaku for this site',
                    message: _site is sites.LiveDanmakuCapability
                        ? null
                        : 'The site adapter does not implement the danmaku capability.',
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: LiveSpacing.xxs),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${message.userName}: ',
                                style: theme.typography.bodySmall.copyWith(color: theme.colors.primary),
                              ),
                              TextSpan(
                                text: message.message,
                                style: theme.typography.bodySmall.copyWith(color: theme.colors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
