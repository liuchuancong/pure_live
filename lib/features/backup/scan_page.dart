import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/backup/backup_controller.dart';
import 'package:pure_live/features/backup/backup_recovery_service.dart';
import 'package:pure_live/features/backup/backup_section_picker.dart';

typedef ScanCodeDetector = Future<void> Function(BarcodeCapture capture);
typedef ScanCodeScannerBuilder = Widget Function(
  BuildContext context,
  MobileScannerController controller,
  ScanCodeDetector onDetect,
);
typedef ScanCodeSyncCallback = Future<bool?> Function(String address);
typedef ScanCodeControllerFactory = MobileScannerController Function({required bool torchEnabled});

/// Returns a canonical HTTP(S) origin for a TV settings-sync QR code.
///
/// Settings synchronization only needs a server origin. Rejecting credentials,
/// paths, queries, fragments, and surrounding prose prevents a visually similar
/// QR payload from silently changing the destination request.
@visibleForTesting
String? normalizeScanSyncAddress(String? rawValue) {
  if (rawValue == null) return null;

  final value = rawValue.trim();
  if (value.isEmpty || RegExp(r'[\u0000-\u0020\u007f]').hasMatch(value)) {
    return null;
  }

  try {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.userInfo.isNotEmpty || (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    if (uri.hasQuery || uri.hasFragment) return null;

    final port = uri.hasPort ? uri.port : null;
    if (port != null && (port < 1 || port > 65535)) return null;

    return Uri(scheme: scheme, host: uri.host.toLowerCase(), port: port).toString();
  } on FormatException {
    return null;
  }
}

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key, this.scannerBuilder, this.syncSettings, this.controllerFactory});

  @visibleForTesting
  final ScanCodeScannerBuilder? scannerBuilder;
  @visibleForTesting
  final ScanCodeSyncCallback? syncSettings;
  @visibleForTesting
  final ScanCodeControllerFactory? controllerFactory;

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  late MobileScannerController cameraController;
  bool hasFound = false;
  bool syncResult = false;
  bool isSuccess = false;
  bool _isRestarting = false;
  int _operationGeneration = 0;
  final Set<MobileScannerController> _disposedControllers = {};

  @override
  void initState() {
    super.initState();
    cameraController = _createController();
  }

  MobileScannerController _createController() {
    return widget.controllerFactory?.call(torchEnabled: false) ?? MobileScannerController(torchEnabled: false);
  }

  Future<bool?> _syncSettings(String address) async {
    final custom = widget.syncSettings;
    if (custom != null) return custom(address);
    if (!mounted) return null;
    // 推送哪些模块由观众在模块页勾选；取消返回 null，不算一次失败的同步。
    final sections = await pickBackupSections(
      direction: BackupSectionDirection.export,
      available: BackupController.tvSectionNames,
    );
    if (sections == null) return null;
    return BackupRecoveryService().pushSettingsToRemoteServer(address, sections: sections);
  }

  Future<void> _disposeController(MobileScannerController controller) async {
    if (!_disposedControllers.add(controller)) return;
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      debugPrint('Failed to dispose the QR scanner controller: $error\n$stackTrace');
    }
  }

  Future<void> _runCameraAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('QR scanner camera action failed: $error\n$stackTrace');
    }
  }

  Future<void> _restartScanner() async {
    if (_isRestarting) return;

    setState(() => _isRestarting = true);
    final previousController = cameraController;
    _operationGeneration++;
    await _disposeController(previousController);
    if (!mounted) return;

    final nextController = _createController();
    setState(() {
      cameraController = nextController;
      hasFound = false;
      syncResult = false;
      isSuccess = false;
      _isRestarting = false;
    });
  }

  @override
  void dispose() {
    _operationGeneration++;
    unawaited(_disposeController(cameraController));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('scan_qr_code')),
        actions: hasFound || _isRestarting ? null : _buildScannerActions(),
      ),
      body: hasFound ? _buildSyncStatus() : _buildScanner(),
    );
  }

  List<Widget> _buildScannerActions() {
    return [
      ValueListenableBuilder<MobileScannerState>(
        valueListenable: cameraController,
        builder: (context, state, child) {
          final available = state.torchState != TorchState.unavailable;
          final (icon, color) = switch (state.torchState) {
            TorchState.off => (Icons.flash_off, Colors.grey),
            TorchState.on => (Icons.flash_on, Colors.yellow),
            TorchState.auto => (Icons.flash_auto, null),
            TorchState.unavailable => (Icons.no_flash, Colors.grey),
          };
          return IconButton(
            tooltip: i18n('scanner_toggle_torch'),
            icon: Icon(icon, color: color),
            onPressed: available ? () => _runCameraAction(cameraController.toggleTorch) : null,
          );
        },
      ),
      ValueListenableBuilder<MobileScannerState>(
        valueListenable: cameraController,
        builder: (context, state, child) {
          final icon = state.cameraDirection == CameraFacing.back ? Icons.camera_rear : Icons.camera_front;
          return IconButton(
            tooltip: i18n('scanner_switch_camera'),
            icon: Icon(icon),
            onPressed: () => _runCameraAction(cameraController.switchCamera),
          );
        },
      ),
    ];
  }

  Widget _buildScanner() {
    final scannerBuilder = widget.scannerBuilder;
    if (scannerBuilder != null) {
      return scannerBuilder(context, cameraController, _onDetect);
    }

    return MobileScanner(
      key: ValueKey(cameraController),
      controller: cameraController,
      onDetect: _onDetect,
      errorBuilder: (context, error) => _buildCameraError(),
      overlayBuilder: (context, constraints) => SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                i18n('scanner_sync_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError() {
    return ColoredBox(
      color: Colors.black,
      child: _ScrollableCenteredBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 44),
            const SizedBox(height: 16),
            Text(
              i18n('scanner_camera_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _isRestarting ? null : _restartScanner, child: Text(i18n('retry'))),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    return _ScrollableCenteredBody(
      child: syncResult
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppStatusView(type: AppStatusType.loading, title: '', subtitle: ''),
                const SizedBox(height: 20),
                Text(
                  i18n('syncing'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? Colors.green : Theme.of(context).colorScheme.error,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(
                  isSuccess ? i18n('sync_success') : i18n('sync_failed'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _isRestarting ? null : _restartScanner, child: Text(i18n('retry'))),
              ],
            ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || hasFound) return;

    String? address;
    for (final barcode in capture.barcodes) {
      address = normalizeScanSyncAddress(barcode.rawValue);
      if (address != null) break;
    }
    if (address == null) return;

    final operation = ++_operationGeneration;
    setState(() {
      hasFound = true;
      syncResult = true;
    });

    var result = false;
    bool? cancelled;
    try {
      final outcome = await _syncSettings(address);
      if (outcome == null) {
        cancelled = true;
      } else {
        result = outcome;
      }
    } catch (error, stackTrace) {
      debugPrint('TV settings synchronization failed: $error\n$stackTrace');
    }

    if (!mounted || operation != _operationGeneration) return;
    if (cancelled == true) {
      // 观众在模块页取消：重新起一次扫码，不报失败。
      await _restartScanner();
      return;
    }
    ToastUtil.show(result ? i18n('sync_success') : i18n('sync_failed'));
    setState(() {
      isSuccess = result;
      syncResult = false;
    });
  }
}

class _ScrollableCenteredBody extends StatelessWidget {
  const _ScrollableCenteredBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity)),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
