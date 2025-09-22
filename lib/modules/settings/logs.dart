import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keframe/keframe.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/plugins/catcher/file_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late File logsPath;
  late String fileContent;
  List logsContent = [];

  @override
  void initState() {
    getPath();
    super.initState();
  }

  void getPath() async {
    logsPath = await CoreLog.getLogsPath();
    fileContent = await logsPath.readAsString();
    logsContent = await parseLogs(fileContent);
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> parseLogs(String fileContent) async {
    List contentList = fileContent.replaceAll(CustomizeFileHandler.lineSeparator, "\n").split(CoreLog.splitToken).map((item) {
      return item
          .replaceAll('============================== CATCHER 2 LOG ==============================', '错误日志\n********************')
          .replaceAll('DEVICE INFO', '设备信息')
          .replaceAll('APP INFO', '应用信息')
          .replaceAll('ERROR', '错误信息')
          .replaceAll('STACK TRACE', '错误堆栈')
          .replaceAll('#', '＃');
    }).toList();
    List<Map<String, dynamic>> result = [];
    for (String i in contentList) {
      String date = "";
      String body = i
          .split("\n")
          .map((l) {
            if (l.startsWith("Crash occurred on")) {
              try {
                date = DateTime.parse(
                  l.split("Crash occurred on")[1].trim(), //.split('.')[0],
                ).toString();
              } catch (e) {
                debugPrint(e.toString());
                date = l.toString();
              }
              return "";
            }
            return l;
          })
          .where((dynamic l) => l.replaceAll("\n", "").trim().isNotEmpty)
          .join("\n");
      if (date.isNotEmpty && body.isNotEmpty) {
        result.add({'date': date, 'body': body, 'expand': false});
      }
    }
    return result.reversed.toList();
  }

  void copyLogs() async {
    await Clipboard.setData(ClipboardData(text: fileContent));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('复制成功')),
      );
    }
  }

  void feedback() {
    launchUrl(
      Uri.parse('https://github.com/orz12/pilipala/issues'),
      // 系统自带浏览器打开
      mode: LaunchMode.externalApplication,
    );
  }

  void clearLogsHandle() async {
    if (await CoreLog.clearLogs()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空')),
        );
        logsContent = [];
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(S.current.settings_log, style: Theme.of(context).textTheme.titleMedium),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String type) {
              // 处理菜单项选择的逻辑
              switch (type) {
                case 'copy':
                  copyLogs();
                  break;
                case 'feedback':
                  feedback();
                  break;
                case 'clear':
                  clearLogsHandle();
                  break;
                default:
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'copy',
                child: Text('复制日志'),
              ),
              const PopupMenuItem<String>(
                value: 'feedback',
                child: Text('错误反馈'),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('清空日志'),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: logsContent.isNotEmpty
          ? SizeCacheWidget(
              child: ListView.builder(
                  itemCount: logsContent.length,
                  cacheExtent: 3,
                  itemBuilder: (context, index) {
                    final log = logsContent[index];
                    // var lineList = log['date'].toString().split("\n");
                    return FrameSeparateWidget(
                        index: index,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: RichText(
                                    text: TextSpan(
                                      text: log['date'].toString(),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: log['body']),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '已将 ${log['date'].toString()} 复制至剪贴板',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_outlined, size: 16),
                                  label: const Text('复制'),
                                )
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Card(
                                elevation: 1,
                                clipBehavior: Clip.antiAliasWithSaveLayer,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: RichText(text: TextSpan(text: log['body'], style: TextStyle(color: Colors.black))),
                                ),
                              ),
                            ),
                            const Divider(indent: 12, endIndent: 12),
                          ],
                        ));
                  }))
          // SingleChildScrollView(
          //     child: Padding(
          //         padding: const EdgeInsets.all(8.0),
          //         child: RichText(
          //             text: TextSpan(
          //           style: Theme.of(context).textTheme.bodyMedium,
          //           children: () {
          //             List<InlineSpan> list = [];
          //             for (var log in logsContent) {
          //               var bodyList = log['body'].toString().split("\n");
          //               var head = WidgetSpan(
          //                 alignment: PlaceholderAlignment.middle,
          //                 style: TextStyle(backgroundColor: Theme.of(context).colorScheme.onPrimary),
          //                 child: Row(
          //                   textDirection: TextDirection.rtl,
          //                   children: [
          //                     Padding(
          //                       padding: const EdgeInsets.all(8.0),
          //                       child: Text(
          //                         log['date'].toString(),
          //                         style: Theme.of(context).textTheme.titleMedium,
          //                       ),
          //                     ),
          //                     TextButton.icon(
          //                       onPressed: () async {
          //                         await Clipboard.setData(
          //                           ClipboardData(text: log['body']),
          //                         );
          //                         if (context.mounted) {
          //                           ScaffoldMessenger.of(context).showSnackBar(
          //                             SnackBar(
          //                               content: Text(
          //                                 '已将 ${log['date'].toString()} 复制至剪贴板',
          //                               ),
          //                             ),
          //                           );
          //                         }
          //                       },
          //                       icon: const Icon(Icons.copy_outlined, size: 16),
          //                       label: const Text('复制'),
          //                     )
          //                   ],
          //                 ),
          //               );
          //               list.add(head);
          //               for (var text in bodyList) {
          //                 list.add(TextSpan(text: "$text\n"));
          //               }
          //               list.add(TextSpan(text: "\n"));
          //               list.add(TextSpan(text: "\n"));
          //             }
          //             return list;
          //           }(),
          //         ))))
          : const CustomScrollView(
              slivers: <Widget>[],
            ),
    );
  }
}
