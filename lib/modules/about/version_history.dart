import 'package:pure_live/common/index.dart';

class VersionHistoryPage extends StatefulWidget {
  const VersionHistoryPage({super.key});

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> {
  List<VersionHistoryModel> loadHistoryList() {
    return VersionUtil.allReleased.map((e) => VersionHistoryModel(version: e['tag_name'].toString().replaceAll('v', ''), updateBody: e['body'])).toList();
  }

  List<Widget> getRichTextList() {
    List<VersionHistoryModel> versions = loadHistoryList();
    return versions
        .map((e) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.version,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    e.updateBody,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.version_history_updates),
      ),
      body: ListView(
        scrollDirection: Axis.vertical,
        physics: const AlwaysScrollableScrollPhysics(),
        children: getRichTextList(),
      ),
    );
  }
}

class VersionHistoryModel {
  final String version;
  final String updateBody;

  VersionHistoryModel({required this.version, required this.updateBody});
}
