import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/widgets/qr_code_widget.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_protocol.dart';

class RemoteSyncPage extends StatefulWidget {
  const RemoteSyncPage({super.key});

  @override
  State<RemoteSyncPage> createState() => _RemoteSyncPageState();
}

class _RemoteSyncPageState extends State<RemoteSyncPage> {
  final RemoteSyncService service = Get.find<RemoteSyncService>();

  final TextEditingController addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    service.confirmRequest = _confirmIncoming;
  }

  @override
  void dispose() {
    if (identical(service.confirmRequest, _confirmIncoming)) service.confirmRequest = null;
    addressController.dispose();
    super.dispose();
  }

  /// Another device asks to read or overwrite this device's settings.
  Future<bool> _confirmIncoming(String action, String remoteAddress) async {
    if (!mounted) return false;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('remote_sync')),
        content: Text(
          i18n(
            action == 'import' ? 'remote_sync_incoming_import' : 'remote_sync_incoming_export',
            args: {'address': remoteAddress},
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('confirm'))),
        ],
      ),
      barrierDismissible: false,
    );
    return allowed == true;
  }

  /// The code is shown under the QR code on the other device.
  Future<String?> _askPairingCode() async {
    final controller = TextEditingController();
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(i18n('remote_sync_pairing_code')),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: RemoteSyncProtocol.pairingCodeLength,
            decoration: InputDecoration(hintText: i18n('remote_sync_pairing_code_hint')),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel'))),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(i18n('confirm')),
            ),
          ],
        ),
      );
      final normalized = RemoteSyncProtocol.normalizePairingCode(code);
      if (code == null) return null;
      if (normalized.length != RemoteSyncProtocol.pairingCodeLength) {
        ToastUtil.show(i18n('remote_sync_pairing_code_invalid'));
        return null;
      }
      return normalized;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _sendToDevice(String ip, int port, {String? code}) async {
    final pairing = code ?? await _askPairingCode();
    if (pairing == null) return;
    final success = await service.syncToAddress(ip, port, pairing);
    if (!mounted) return;
    ToastUtil.show(success ? i18n('remote_sync_send_success') : i18n('remote_sync_send_failed'));
  }

  Future<void> _receiveFromDevice(String ip, int port, {String? code}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('remote_sync_receive')),
        content: Text(i18n('remote_sync_receive_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('confirm'))),
        ],
      ),
    );
    if (confirm != true) return;
    final pairing = code ?? await _askPairingCode();
    if (pairing == null) return;

    final settings = await service.getRemoteSettings(ip, port, pairing);
    if (settings == null) {
      ToastUtil.show(i18n('remote_sync_receive_failed'));
      return;
    }
    final success = await _applyRemoteSettings(settings);
    if (!mounted) return;
    ToastUtil.show(success ? i18n('remote_sync_receive_success') : i18n('remote_sync_receive_failed'));
  }

  Future<bool> _applyRemoteSettings(Map<String, dynamic> settings) async {
    try {
      final backup = Get.find<BackupController>();
      backup.importAllSettings(settings);
      return true;
    } catch (_) {
      return false;
    }
  }

  ({String ip, int port})? _manualAddress() {
    final value = addressController.text.trim();
    if (value.isEmpty) {
      ToastUtil.show(i18n('remote_sync_enter_address'));
      return null;
    }
    final parsed = RemoteSyncProtocol.parseHttpAddress(value);
    if (parsed == null) ToastUtil.show(i18n('remote_sync_invalid_address'));
    return parsed;
  }

  Future<void> _scanQr() async {
    if (PlatformUtils.isDesktop) return;
    final result = await Get.to<String>(() => const _RemoteSyncScannerPage());
    if (!mounted || result == null || result.trim().isEmpty) return;

    final parsed = RemoteSyncProtocol.parseQr(result);
    if (parsed == null) {
      ToastUtil.show(i18n('remote_sync_invalid_qr'));
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('remote_sync_select_action')),
        content: Text('${parsed.ip}:${parsed.port}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('receive'),
            child: Text(i18n('remote_sync_receive')),
          ),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop('send'), child: Text(i18n('remote_sync_send'))),
        ],
      ),
    );

    if (action == 'send') {
      await _sendToDevice(parsed.ip, parsed.port, code: parsed.code);
    } else if (action == 'receive') {
      await _receiveFromDevice(parsed.ip, parsed.port, code: parsed.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('remote_sync')),
        actions: [
          if (!PlatformUtils.isDesktop) IconButton(onPressed: _scanQr, icon: const Icon(Icons.qr_code_scanner)),
          Obx(
            () => IconButton(
              onPressed: service.isDiscovering.value ? service.stop : service.start,
              icon: Icon(service.isDiscovering.value ? Remix.stop_circle_line : Remix.play_circle_line),
              tooltip: service.isDiscovering.value ? i18n('stop') : i18n('start'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(
        () => ListView(
          physics: const PureLiveScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildLocalDevice(),
            const SizedBox(height: 16),
            _buildDiscoveredDevices(),
            const SizedBox(height: 16),
            _buildManualAddress(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalDevice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(i18n('remote_sync_my_device'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (service.qrData.isNotEmpty)
              QrCodeWidget(data: service.qrData, size: 180, padding: const EdgeInsets.all(12)),
            const SizedBox(height: 12),
            SelectableText(
              service.address.isEmpty ? i18n('remote_sync_no_address') : service.address,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (service.pairingCode.value.isNotEmpty) ...[
              Text(i18n('remote_sync_pairing_code')),
              SelectableText(
                service.pairingCode.value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6),
              ),
              const SizedBox(height: 8),
            ],
            Text(i18n('remote_sync_scan_hint'), textAlign: TextAlign.center),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i18n('remote_sync_include_accounts')),
              subtitle: Text(i18n('remote_sync_include_accounts_hint')),
              value: service.includeAccounts.value,
              onChanged: (value) => service.includeAccounts.value = value,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(service.isServerRunning.value ? Icons.check_circle : Icons.error, size: 18),
                const SizedBox(width: 6),
                Text(service.isServerRunning.value ? i18n('remote_sync_running') : i18n('remote_sync_not_running')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredDevices() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    i18n('remote_sync_devices'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (service.isDiscovering.value)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),
            if (service.devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(i18n('remote_sync_no_devices'))),
              )
            else
              ...service.devices.map(_buildDevice),
          ],
        ),
      ),
    );
  }

  Widget _buildDevice(RemoteSyncDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.devices),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(device.address),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: service.isSyncing.value ? null : () => _receiveFromDevice(device.ip, device.port),
                    icon: const Icon(Icons.download),
                    label: Text(i18n('remote_sync_receive')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: service.isSyncing.value ? null : () => _sendToDevice(device.ip, device.port),
                    icon: const Icon(Icons.upload),
                    label: Text(i18n('remote_sync_send')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualAddress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i18n('remote_sync_manual'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: '192.168.1.100:39888',
                prefixIcon: Icon(Icons.lan),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: service.isSyncing.value
                    ? null
                    : () async {
                        final parsed = _manualAddress();
                        if (parsed != null) await _sendToDevice(parsed.ip, parsed.port);
                      },
                icon: const Icon(Icons.upload),
                label: Text(i18n('remote_sync_send')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: service.isSyncing.value
                    ? null
                    : () async {
                        final parsed = _manualAddress();
                        if (parsed != null) await _receiveFromDevice(parsed.ip, parsed.port);
                      },
                icon: const Icon(Icons.download),
                label: Text(i18n('remote_sync_receive')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteSyncScannerPage extends StatefulWidget {
  const _RemoteSyncScannerPage();

  @override
  State<_RemoteSyncScannerPage> createState() => _RemoteSyncScannerPageState();
}

class _RemoteSyncScannerPageState extends State<_RemoteSyncScannerPage> {
  final MobileScannerController controller = MobileScannerController();

  bool found = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('remote_sync_scan_qr'))),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (found) {
            return;
          }

          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim();

            if (value == null || value.isEmpty) {
              continue;
            }

            if (RemoteSyncProtocol.parseQr(value) == null) {
              continue;
            }

            found = true;
            Navigator.of(context).pop(value);
            break;
          }
        },
      ),
    );
  }
}
