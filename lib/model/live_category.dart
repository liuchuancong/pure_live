import 'dart:convert';

import 'package:pure_live/common/models/index.dart';

class LiveCategory {
  late String name;
  late String id;
  late List<LiveArea> children;

  LiveCategory({
    required this.id,
    required this.name,
    required this.children,
  });

  LiveCategory.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    id = json['id'] ?? '';
    children = <LiveArea>[];
    var childrenList = json['children'] as List;
    if (childrenList.isNotEmpty) {
      for (var i in childrenList) {
        children.add(LiveArea.fromJson(i));
      }
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'id': id,
      'children': children,
    };
  }

  @override
  String toString() {
    return json.encode({
      "name": name,
      "id": id,
      "children": children,
    });
  }
}
