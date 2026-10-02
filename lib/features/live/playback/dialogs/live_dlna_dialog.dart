import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:pure_live/core/index.dart';

abstract interface class DlnaCastDevice {
  String get id;

  String get name;

  Future<void> pause();

  Future<void> setSource(String source);

  Future<void> play();
}

abstract interface class DlnaDiscoverySession {
  Stream<List<DlnaCastDevice>> get devices;

  Future<void> stop();
}

typedef DlnaDiscoveryStarter = Future<DlnaDiscoverySession> Function();

@visibleForTesting
String? normalizeDlnaSource(String value) {
  final normalized = value.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      (uri.scheme.toLowerCase() != 'http' && uri.scheme.toLowerCase() != 'https') ||
      !uri.hasAuthority ||
      uri.host.trim().isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return normalized;
}

class _PackageDlnaDevice implements DlnaCastDevice {
  _PackageDlnaDevice(this.id, this._delegate);

  @override
  final String id;
  final DLNADevice _delegate;

  @override
  String get name => _delegate.info.friendlyName;

  @override
  Future<void> pause() async {
    await _delegate.pause();
  }

  @override
  Future<void> setSource(String source) async {
    await _delegate.setUrl(source);
  }

  @override
  Future<void> play() async {
    await _delegate.play();
  }
}

class _PackageDlnaSession implements DlnaDiscoverySession {
  _PackageDlnaSession(this._manager, DeviceManager deviceManager)
    : devices = deviceManager.devices.stream.map(
        (snapshot) => [for (final entry in snapshot.entries) _PackageDlnaDevice(entry.key, entry.value)],
      );

  final DLNAManager _manager;
  bool _stopped = false;

  @override
  final Stream<List<DlnaCastDevice>> devices;

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _manager.stop();
  }
}

Future<DlnaDiscoverySession> _startPackageDiscovery() async {
  final manager = DLNAManager();
  try {
    final deviceManager = await manager.start();
    return _PackageDlnaSession(manager, deviceManager);
  } catch (_) {
    try {
      manager.stop();
    } catch (_) {
      // The package may already have released a partially opened socket.
    }
    rethrow;
  }
}

enum LiveDlnaViewStatus { searching, ready, empty, failed, invalidSource }

class LiveDlnaPage extends StatefulWidget {
  const LiveDlnaPage({
    super.key,
    required this.datasource,
    this.startDiscovery = _startPackageDiscovery,
    this.searchDuration = const Duration(seconds: 20),
    this.notice,
  });

  final String datasource;
  final DlnaDiscoveryStarter startDiscovery;
  final Duration searchDuration;
  final ValueChanged<String>? notice;

  @override
  State<LiveDlnaPage> createState() => _LiveDlnaPageState();
}

class _LiveDlnaPageState extends State<LiveDlnaPage> {
  final Map<String, DlnaCastDevice> _devices = {};

  DlnaDiscoverySession? _session;
  StreamSubscription<List<DlnaCastDevice>>? _devicesSubscription;
  Timer? _searchTimer;
  Future<void>? _startTask;
  Future<void>? _castTask;

  late final String? _source;
  LiveDlnaViewStatus _status = LiveDlnaViewStatus.searching;
  String? _selectedDeviceId;
  String? _castingDeviceId;
  String? _inlineErrorKey;
  int _searchRevision = 0;
  int _lifecycleRevision = 0;
  bool _starting = false;
  bool _closed = false;

  bool get _isActive => mounted && !_closed;

  @override
  void initState() {
    super.initState();
    _source = normalizeDlnaSource(widget.datasource);
    if (_source == null) {
      _status = LiveDlnaViewStatus.invalidSource;
    } else {
      unawaited(startSearch());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _lifecycleRevision++;
    _searchRevision++;
    _searchTimer?.cancel();
    unawaited(_releaseDiscovery());
    super.dispose();
  }

  Future<void> _releaseDiscovery() async {
    final subscription = _devicesSubscription;
    _devicesSubscription = null;
    final session = _session;
    _session = null;
    try {
      await Future.wait([if (subscription != null) subscription.cancel(), if (session != null) _stopSession(session)]);
    } catch (_) {
      // A stream may already be closed while a refresh is replacing it.
    }
  }

  Future<void> _stopSession(DlnaDiscoverySession session) async {
    try {
      await session.stop();
    } catch (_) {
      // Discovery cleanup is best-effort and must not surface after exit.
    }
  }

  Future<void> startSearch() {
    if (_source == null || _closed) return Future<void>.value();
    final current = _startTask;
    if (_starting && current != null) return current;

    final completer = Completer<void>();
    final task = completer.future;
    _startTask = task;
    unawaited(_runSearchTransaction(completer, task));
    return task;
  }

  Future<void> _runSearchTransaction(Completer<void> completer, Future<void> task) async {
    try {
      await _startSearch();
    } catch (_) {
      if (_isActive) {
        setState(() {
          _starting = false;
          _status = LiveDlnaViewStatus.failed;
        });
      }
    } finally {
      if (identical(_startTask, task)) _startTask = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _startSearch() async {
    final revision = ++_searchRevision;
    _searchTimer?.cancel();
    if (_isActive) {
      setState(() {
        _starting = true;
        _status = LiveDlnaViewStatus.searching;
        _inlineErrorKey = null;
        _devices.clear();
      });
    }

    // Both cancellation and the package stop call begin synchronously. Do not
    // make a new search wait for a slow stream-cancellation acknowledgement;
    // the revision below already fences every late snapshot.
    unawaited(_releaseDiscovery());
    if (!_isSearchCurrent(revision)) return;

    DlnaDiscoverySession session;
    try {
      session = await widget.startDiscovery();
    } catch (_) {
      if (_isSearchCurrent(revision)) {
        setState(() {
          _starting = false;
          _status = LiveDlnaViewStatus.failed;
        });
      }
      return;
    }

    if (!_isSearchCurrent(revision)) {
      try {
        await session.stop();
      } catch (_) {
        // A late session owns no visible state.
      }
      return;
    }

    _session = session;
    _devicesSubscription = session.devices.listen(
      (snapshot) => _receiveDevices(revision, snapshot),
      onError: (_) => unawaited(_finishSearch(revision, failed: true)),
      onDone: () => unawaited(_finishSearch(revision)),
    );
    setState(() => _starting = false);
    _searchTimer = Timer(widget.searchDuration, () => unawaited(_finishSearch(revision)));
  }

  bool _isSearchCurrent(int revision) => _isActive && revision == _searchRevision;

  void _receiveDevices(int revision, List<DlnaCastDevice> snapshot) {
    if (!_isSearchCurrent(revision)) return;
    final next = <String, DlnaCastDevice>{};
    for (final device in snapshot) {
      final id = device.id.trim();
      if (id.isNotEmpty) next[id] = device;
    }
    setState(() {
      _devices
        ..clear()
        ..addAll(next);
      if (_selectedDeviceId != null && !_devices.containsKey(_selectedDeviceId)) {
        _selectedDeviceId = null;
      }
      _status = _devices.isEmpty ? LiveDlnaViewStatus.searching : LiveDlnaViewStatus.ready;
    });
  }

  Future<void> _finishSearch(int revision, {bool failed = false}) async {
    if (!_isSearchCurrent(revision)) return;
    _searchTimer?.cancel();
    _searchTimer = null;
    setState(() {
      _starting = false;
      if (_devices.isEmpty) {
        _status = failed ? LiveDlnaViewStatus.failed : LiveDlnaViewStatus.empty;
      } else {
        _status = LiveDlnaViewStatus.ready;
        if (failed) _inlineErrorKey = 'dlna_search_interrupted';
      }
    });
    await _releaseDiscovery();
  }

  Future<void> castToDevice(String deviceId) {
    if (_source == null || _closed) return Future<void>.value();
    final current = _castTask;
    if (current != null) return current;
    final target = _devices[deviceId];
    if (target == null) return Future<void>.value();

    final completer = Completer<void>();
    final task = completer.future;
    _castTask = task;
    unawaited(_runCastTransaction(target, completer, task));
    return task;
  }

  Future<void> _runCastTransaction(DlnaCastDevice target, Completer<void> completer, Future<void> task) async {
    try {
      await _castToDevice(target);
    } finally {
      if (identical(_castTask, task)) _castTask = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _castToDevice(DlnaCastDevice target) async {
    final revision = _lifecycleRevision;
    setState(() {
      _castingDeviceId = target.id;
      _inlineErrorKey = null;
    });
    try {
      final previous = _selectedDeviceId == null ? null : _devices[_selectedDeviceId];
      if (previous != null && previous.id != target.id) {
        try {
          await previous.pause();
        } catch (_) {
          // A receiver that no longer answers must not block a new receiver.
        }
      }
      if (!_isCastCurrent(revision, target.id)) return;

      await target.setSource(_source!);
      if (!_isCastCurrent(revision, target.id)) return;

      await target.play();
      if (!_isCastCurrent(revision, target.id)) return;

      setState(() {
        _selectedDeviceId = target.id;
        _inlineErrorKey = null;
      });
      _notify('dlna_cast_started');
    } catch (_) {
      if (_isCastCurrent(revision, target.id)) {
        setState(() => _inlineErrorKey = 'dlna_cast_failed');
        _notify('dlna_cast_failed');
      }
    } finally {
      if (_isActive && revision == _lifecycleRevision) {
        setState(() => _castingDeviceId = null);
      }
    }
  }

  bool _isCastCurrent(int revision, String deviceId) =>
      _isActive && revision == _lifecycleRevision && _devices.containsKey(deviceId);

  void _notify(String messageKey) {
    final notice = widget.notice;
    if (notice != null) {
      notice(messageKey);
    } else {
      ToastUtil.show(i18n(messageKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxContentHeight = (media.size.height * 0.52).clamp(120.0, 420.0);
    return AlertDialog(
      key: const ValueKey('dlna-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Row(
        children: [
          Expanded(child: Text(i18n('dlan_title'))),
          const SizedBox(width: 8),
          if (_starting)
            const SizedBox.square(
              dimension: 40,
              child: Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_source != null)
            IconButton(
              key: const ValueKey('dlna-refresh'),
              tooltip: i18n('retry'),
              onPressed: _castTask == null ? startSearch : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: _buildContent(context)),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('close')))],
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_status) {
      case LiveDlnaViewStatus.invalidSource:
        return _DlnaStatusPane(
          key: const ValueKey('dlna-invalid-source'),
          icon: Icons.link_off_rounded,
          title: i18n('dlna_invalid_source'),
        );
      case LiveDlnaViewStatus.failed:
        return _DlnaStatusPane(
          key: const ValueKey('dlna-search-failed'),
          icon: Icons.wifi_find_rounded,
          title: i18n('dlna_search_failed'),
          action: _statusAction(),
        );
      case LiveDlnaViewStatus.empty:
        return _DlnaStatusPane(
          key: const ValueKey('dlna-empty'),
          icon: Icons.cast_connected_rounded,
          title: i18n('dlan_device_not_found'),
          subtitle: i18n('dlna_search_hint'),
          action: _statusAction(),
        );
      case LiveDlnaViewStatus.searching:
        return _DlnaStatusPane(
          key: const ValueKey('dlna-searching'),
          icon: Icons.cast_rounded,
          title: i18n('dlna_searching'),
          subtitle: i18n('dlna_search_hint'),
          progress: true,
        );
      case LiveDlnaViewStatus.ready:
        return _buildDeviceList(context);
    }
  }

  Widget _statusAction() => FilledButton.icon(
    key: const ValueKey('dlna-retry'),
    onPressed: _starting ? null : startSearch,
    icon: const Icon(Icons.refresh_rounded),
    label: Text(i18n('retry')),
  );

  Widget _buildDeviceList(BuildContext context) {
    final devices = _devices.values.toList(growable: false);
    return CustomScrollView(
      key: const ValueKey('dlna-device-list'),
      shrinkWrap: true,
      physics: const PureLiveBoundedScrollPhysics(),
      slivers: [
        if (_searchTimer != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(semanticsLabel: i18n('dlna_searching')),
            ),
          ),
        if (_inlineErrorKey != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                i18n(_inlineErrorKey!),
                key: const ValueKey('dlna-inline-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        SliverList.separated(
          itemCount: devices.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            final name = device.name.trim().isEmpty ? i18n('dlna_unknown_device') : device.name.trim();
            final casting = _castingDeviceId == device.id;
            final selected = _selectedDeviceId == device.id;
            return ListTile(
              key: ValueKey('dlna-device-${device.id}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              leading: Icon(selected ? Icons.cast_connected_rounded : Icons.cast_rounded),
              title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(device.id, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: casting
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : selected
                  ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                  : null,
              enabled: _castTask == null,
              onTap: _castTask == null ? () => castToDevice(device.id) : null,
            );
          },
        ),
      ],
    );
  }
}

class _DlnaStatusPane extends StatelessWidget {
  const _DlnaStatusPane({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.progress = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const PureLiveBoundedScrollPhysics(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (progress) ...[const SizedBox(height: 16), LinearProgressIndicator(semanticsLabel: title)],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
