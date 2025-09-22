import 'dart:math';

final class ListUtil {
  /// 切分list
  static List<List<T>> subList<T>(List<T> list, int size) {
    if (list.isEmpty) {
      return List.empty();
    }
    List<List<T>> rs = [];
    for (var i = 0; i < list.length; i += size) {
      var end = min(i + size, list.length);
      var subList = list.sublist(i, end);
      rs.add(subList);
    }
    return rs;
  }

  /// 切分list
  static List<List<T>> splitList<T>(List<T> list, T value) {
    if (list.isEmpty) {
      return List.empty();
    }
    List<List<T>> rs = [];
    var start = 0;
    var i = 0;
    for (; i < list.length; i++) {
      var cur = list[i];
      if (cur == value) {
        var end = i;
        var subList = list.sublist(start, end);
        rs.add(subList);
        start = i + 1;
      }
    }
    var end = min(i, list.length);
    var subList = list.sublist(start, end);
    rs.add(subList);
    return rs;
  }
}
