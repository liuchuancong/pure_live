import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:pure_live/common/index.dart';

class LiveDlnaPage extends StatefulWidget {
  final String datasource;

  const LiveDlnaPage({super.key, required this.datasource});

  @override
  State<LiveDlnaPage> createState() => _LiveDlnaPageState();
}

class _LiveDlnaPageState extends State<LiveDlnaPage> {
  final Map<String, DLNADevice> _deviceList = {};
  final DLNAManager searcher = DLNAManager();
  late final Timer stopSearchTimer;
  StreamSubscription? _devicesSubscription;
  String selectDeviceKey = '';
  bool isSearching = true;

  DLNADevice? get device => _deviceList[selectDeviceKey];

  @override
  void initState() {
    stopSearchTimer = Timer(const Duration(seconds: 20), () {
      setState(() => isSearching = false);
      searcher.stop();
    });
    startSearch();
    super.initState();
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    searcher.stop();
    stopSearchTimer.cancel();
    super.dispose();
  }

  void startSearch() async {
    // clear old devices
    isSearching = true;
    selectDeviceKey = '';
    _deviceList.clear();
    setState(() {});
    // start search server
    final m = await searcher.start();
    if (!mounted) {
      searcher.stop();
      return;
    }
    await _devicesSubscription?.cancel();
    _devicesSubscription = m.devices.stream.listen((deviceList) {
      if (!mounted) return;
      deviceList.forEach((key, value) {
        _deviceList[key] = value;
      });
      setState(() {});
    });
    // close the server, the closed server can be start by call searcher.start()
  }

  void selectDevice(String key) {
    if (selectDeviceKey.isNotEmpty) device?.pause();

    selectDeviceKey = key;
    device?.setUrl(widget.datasource);
    device?.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget cur;
    if (isSearching && _deviceList.isEmpty) {
      cur = AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
    } else if (_deviceList.isEmpty) {
      cur = Center(child: Text(i18n("dlan_device_not_found"), style: Theme.of(context).textTheme.bodyLarge));
    } else {
      cur = ListView(
        children: _deviceList.keys
            .map<Widget>(
              (key) => ListTile(
                contentPadding: const EdgeInsets.all(2),
                title: Text(_deviceList[key]!.info.friendlyName),
                subtitle: Text(key),
                onTap: () => selectDevice(key),
              ),
            )
            .toList(),
      );
    }

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(i18n("dlan_title")),
          IconButton(onPressed: startSearch, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      content: SizedBox(height: 200, width: 200, child: cur),
    );
  }
}
