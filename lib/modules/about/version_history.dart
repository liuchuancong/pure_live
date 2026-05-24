import 'package:pure_live/common/index.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown_block.dart';

class VersionHistoryPage extends StatefulWidget {
  const VersionHistoryPage({super.key});

  @override
  State<VersionHistoryPage> createState() => _VersionHistoryPageState();
}

class _VersionHistoryPageState extends State<VersionHistoryPage> {
  List<VersionHistoryModel> loadHistoryList() {
    return VersionUtil.allReleased
        .map((e) => VersionHistoryModel(version: e['tag_name'].toString().replaceAll('v', ''), updateBody: e['body']))
        .toList();
  }

  List<Widget> getRichTextList() {
    List<VersionHistoryModel> versions = loadHistoryList();
    final config = Get.isDarkMode ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    return versions
        .map(
          (e) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.version, style: AppTextStyles.t20.copyWith(fontWeight: FontWeight.bold)),
                MarkdownBlock(data: e.updateBody, config: config),
              ],
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("version_history_desc"))),
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
