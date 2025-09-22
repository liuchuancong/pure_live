import 'dart:math';

extension ListExtension<T> on List<T> {
  /// 实现类型 string join
  List<T> joinItem(T item) {
    List<T> list = this;
    if (list.length <= 1) {
      return list;
    }
    List<T> newList = [];
    newList.add(list[0]);
    for (var i = 1; i < list.length; i++) {
      newList.add(item);
      newList.add(list[i]);
    }
    return newList;
  }

  /// 切分list
  List<List<T>> subList(int size) {
    List<T> list = this;
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

}