import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/models/record_file_item.dart';
import 'package:pure_live/recorder/pages/record_history/record_history_service.dart';

class RecordHistoryPage extends StatefulWidget {
  const RecordHistoryPage({super.key});

  @override
  State<RecordHistoryPage> createState() => _RecordHistoryPageState();
}

class _RecordHistoryPageState extends State<RecordHistoryPage> {
  final service = RecordHistoryService.to;

  final keyword = ''.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("录制历史"),

        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () async {
              final ok = await Get.dialog<bool>(
                AlertDialog(
                  title: const Text("清空历史"),
                  content: const Text("是否清空所有录制历史？"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(Get.context!, false);
                      },
                      child: const Text("取消"),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(Get.context!, true);
                      },
                      child: const Text("确定"),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                await service.clear();
              }
            },
          ),
        ],
      ),

      body: Column(
        children: [
          /// =========================
          /// 搜索
          /// =========================
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "搜索主播 / 标题 / 平台",

                prefixIcon: const Icon(Icons.search_rounded),

                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),

                filled: true,
              ),

              onChanged: (v) {
                keyword.value = v;
              },
            ),
          ),

          /// =========================
          /// 列表
          /// =========================
          Expanded(
            child: Obx(() {
              final records = keyword.value.isEmpty ? service.records : service.search(keyword.value);

              if (records.isEmpty) {
                return _EmptyView();
              }

              final grouped = _buildGrouped(records);

              return ListView(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),

                children: grouped.entries.map((dateEntry) {
                  final date = dateEntry.key;

                  final platformMap = dateEntry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),

                    child: ExpansionTile(
                      initiallyExpanded: true,

                      leading: const Icon(Icons.calendar_month_rounded),

                      title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),

                      children: platformMap.entries.map((platformEntry) {
                        final platform = platformEntry.key;

                        final nickMap = platformEntry.value;

                        return ExpansionTile(
                          leading: const Icon(Icons.live_tv_rounded),

                          title: Text(platform.toUpperCase()),

                          children: nickMap.entries.map((nickEntry) {
                            final nick = nickEntry.key;

                            final list = nickEntry.value;

                            return ExpansionTile(
                              leading: const Icon(Icons.person_rounded),

                              title: Text(nick),

                              children: list.map((e) {
                                return _RecordTile(item: e);
                              }).toList(),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// =========================
  /// 分组
  /// 日期
  ///   └ 平台
  ///      └ 主播
  ///          └ 文件
  /// =========================
  Map<String, Map<String, Map<String, List<RecordFileItem>>>> _buildGrouped(List<RecordFileItem> list) {
    final result = <String, Map<String, Map<String, List<RecordFileItem>>>>{};

    for (final item in list) {
      /// 日期
      result.putIfAbsent(item.date, () => {});

      final dateMap = result[item.date]!;

      /// 平台
      dateMap.putIfAbsent(item.platform, () => {});

      final platformMap = dateMap[item.platform]!;

      /// 主播
      platformMap.putIfAbsent(item.nick, () => []);

      /// 文件
      platformMap[item.nick]!.add(item);
    }

    return result;
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.item});

  final RecordFileItem item;

  String _sizeText(int size) {
    if (size <= 0) {
      return "0 MB";
    }

    if (size < 1024 * 1024 * 1024) {
      return "${(size / 1024 / 1024).toStringAsFixed(2)} MB";
    }

    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }

  String _durationText(int sec) {
    final h = sec ~/ 3600;

    final m = (sec % 3600) ~/ 60;

    final s = sec % 60;

    return "${h.toString().padLeft(2, '0')}:"
        "${m.toString().padLeft(2, '0')}:"
        "${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,

      margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),

      child: ListTile(
        contentPadding: const EdgeInsets.all(10),

        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),

          child: Image.network(item.cover, width: 100, height: 56, fit: BoxFit.cover),
        ),

        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,

          style: const TextStyle(fontWeight: FontWeight.w600),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text("主播：${item.nick}"),

              Text("时长：${_durationText(item.duration)}"),

              Text("大小：${_sizeText(item.size)}"),

              Text(p.basename(item.path), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),

        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: "open", child: Text("打开")),

            const PopupMenuItem(value: "folder", child: Text("打开目录")),

            const PopupMenuItem(value: "delete", child: Text("删除记录")),
          ],

          onSelected: (v) async {
            switch (v) {
              case "open":
                OpenFilex.open(item.path);
                break;

              case "folder":
                OpenFilex.open(File(item.path).parent.path);
                break;

              case "delete":
                await RecordHistoryService.to.deleteRecord(item);
                break;
            }
          },
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(Icons.video_collection_outlined, size: 72, color: Colors.grey.shade400),

          const SizedBox(height: 16),

          Text("暂无录制历史", style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
