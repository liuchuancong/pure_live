import 'package:get/get.dart';
import 'package:pure_live/common/services/settings_service.dart';

class DanmuMerge {
  DanmuMerge._internal();
  //单例模式，只创建一次实例
  static late DanmuMerge _instance;
  static DanmuMerge getInstance() {
    _instance = DanmuMerge._internal();
    return _instance;
  }

  static List<MsgModel> _msgList = [];

  List<MsgModel> get msgList => _msgList;

  void add(String msg) {
    if (!isRepeat(msg)) {
      _msgList.add(MsgModel(msg: msg, dateTime: DateTime.now()));
    }
    refreshList();
  }

  void refreshList() {
    var dateTime = DateTime.now();
    _msgList = _msgList.where((element) => dateTime.difference(element.dateTime).inSeconds <= 20).toList();
  }

  bool isRepeat(String msg) {
    final settings = Get.find<SettingsService>();
    double repeatFlag = settings.mergeDanmuRating.value;
    for (var i = 0; i < _msgList.length; i++) {
      var rating = compareTwoStrings(_msgList[i].msg, msg);
      if (rating >= (1.0 - repeatFlag)) {
        return true;
      }
    }
    return false;
  }

  double compareTwoStrings(String? first, String? second) {
    // if both are null
    if (first == null && second == null) {
      return 1;
    }
    // as both are not null if one of them is null then return 0
    if (first == null || second == null) {
      return 0;
    }

    first = first.replaceAll(RegExp(r'\s+\b|\b\s'), ''); // remove all whitespace
    second = second.replaceAll(RegExp(r'\s+\b|\b\s'), ''); // remove all whitespace

    // if both are empty strings
    if (first.isEmpty && second.isEmpty) {
      return 1;
    }
    // if only one is empty string
    if (first.isEmpty || second.isEmpty) {
      return 0;
    }
    // identical
    if (first == second) {
      return 1;
    }
    // both are 1-letter strings
    if (first.length == 1 && second.length == 1) {
      return 0;
    }
    // if either is a 1-letter string
    if (first.length < 2 || second.length < 2) {
      return 0;
    }

    final firstBigrams = <String, int>{};
    for (var i = 0; i < first.length - 1; i++) {
      final bigram = first.substring(i, i + 2);
      final count = firstBigrams.containsKey(bigram) ? firstBigrams[bigram]! + 1 : 1;
      firstBigrams[bigram] = count;
    }

    var intersectionSize = 0;
    for (var i = 0; i < second.length - 1; i++) {
      final bigram = second.substring(i, i + 2);
      final count = firstBigrams.containsKey(bigram) ? firstBigrams[bigram]! : 0;

      if (count > 0) {
        firstBigrams[bigram] = count - 1;
        intersectionSize++;
      }
    }

    return (2.0 * intersectionSize) / (first.length + second.length - 2);
  }

  DanmuMerge();
}

class MsgModel {
  final String msg;
  final DateTime dateTime;
  MsgModel({required this.msg, required this.dateTime});
}
