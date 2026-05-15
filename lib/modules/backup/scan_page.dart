import 'package:pure_live/common/index.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  MobileScannerController cameraController = MobileScannerController(torchEnabled: true);
  bool hasFound = false;
  bool syncResult = false;
  bool isSuccess = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("scan_qr_code")),
        actions: [
          hasFound
              ? Container()
              : IconButton(
                  icon: ValueListenableBuilder(
                    valueListenable: cameraController,
                    builder: (context, state, child) {
                      switch (state.torchState) {
                        case TorchState.off:
                          return const Icon(Icons.flash_off, color: Colors.grey);
                        case TorchState.on:
                          return const Icon(Icons.flash_on, color: Colors.yellow);
                        case TorchState.auto:
                          return IconButton(
                            color: Colors.white,
                            iconSize: 32.0,
                            icon: const Icon(Icons.flash_auto),
                            onPressed: () async {
                              await cameraController.toggleTorch();
                            },
                          );
                        case TorchState.unavailable:
                          return const Icon(Icons.no_flash, color: Colors.grey);
                      }
                    },
                  ),
                  iconSize: 20.0,
                  onPressed: () => cameraController.toggleTorch(),
                ),
          hasFound
              ? Container()
              : IconButton(
                  icon: ValueListenableBuilder(
                    valueListenable: cameraController,
                    builder: (context, state, child) {
                      if (state.cameraDirection == CameraFacing.back) {
                        return const Icon(Icons.camera_rear);
                      } else {
                        return const Icon(Icons.camera_front);
                      }
                    },
                  ),
                  iconSize: 20.0,
                  onPressed: () => cameraController.switchCamera(),
                ),
        ],
      ),
      body: hasFound
          ? Center(
              child: syncResult
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(i18n("syncing"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                       isSuccess ? i18n("sync_success") : i18n("sync_failed"),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              hasFound = false;
                              syncResult = false;
                              isSuccess = false;
                            });
                            cameraController = MobileScannerController();
                          },
                        child: Text(i18n("tap_to_sync"))
                        ),
                      ],
                    ),
            )
          : MobileScanner(
              // fit: BoxFit.contain,
              controller: cameraController,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && FileRecoverUtils.isHostUrl(barcodes[0].rawValue!)) {
                  setState(() {
                    hasFound = true;
                    syncResult = true;
                  });
                  final result = await FileRecoverUtils().recoverSettingsBackup(barcodes[0].rawValue!);
                  ToastUtil.show(result ? '同步成功' : "同步失败");
                  setState(() {
                    isSuccess = result;
                    syncResult = false;
                  });
                }
              },
            ),
    );
  }
}
