import 'package:flutter/material.dart';

abstract class DanmakuControllerBase {
  bool _running = true;

  /// 是否运行中
  /// 可以调用pause()暂停弹幕
  bool get running => _running;

  set running(bool e) {
    _running = e;
  }

  /// 类型
  String getType();

  DanmakuSettingOption _option = DanmakuSettingOption();

  DanmakuSettingOption get option => _option;

  set option(DanmakuSettingOption e) {
    _option = e;
  }

  /// 暂停弹幕
  void pause();

  /// 继续弹幕
  void resume();

  /// 清空弹幕
  void clear();

  /// 添加弹幕
  void addDanmaku(IDanmakuContentItem item);

  /// 更新弹幕配置
  void updateOption(DanmakuSettingOption option);

  void dispose();

  /// 获取弹幕视图
  Widget getWidget({Key? key});
}

class DanmakuSettingOption {
  /// 默认的字体大小
   double fontSize;

  /// 字体粗细
   int fontWeight;

  /// 显示区域，0.1-1.0
   double area;

  /// 滚动弹幕运行时间，秒
   int duration;

  /// 不透明度，0.1-1.0
   double opacity;

  /// 隐藏顶部弹幕
   bool hideTop;

  /// 隐藏底部弹幕
   bool hideBottom;

  /// 隐藏滚动弹幕
   bool hideScroll;

  /// 弹幕描边
   bool showStroke;

  /// 海量弹幕模式 (弹幕轨道占满时进行叠加)
   bool massiveMode;

  /// 为字幕预留空间
  bool safeArea;

  DanmakuSettingOption({
    this.fontSize = 16,
    this.fontWeight = 4,
    this.area = 1.0,
    this.duration = 10,
    this.opacity = 1.0,
    this.hideBottom = false,
    this.hideScroll = false,
    this.hideTop = false,
    this.showStroke = true,
    this.massiveMode = false,
    this.safeArea = true,
  });

  DanmakuSettingOption copyWith({
    double? fontSize,
    int? fontWeight,
    double? area,
    int? duration,
    double? opacity,
    bool? hideTop,
    bool? hideBottom,
    bool? hideScroll,
    bool? showStroke,
    bool? massiveMode,
    bool? safeArea,
  }) {
    return DanmakuSettingOption(
      area: area ?? this.area,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      duration: duration ?? this.duration,
      opacity: opacity ?? this.opacity,
      hideTop: hideTop ?? this.hideTop,
      hideBottom: hideBottom ?? this.hideBottom,
      hideScroll: hideScroll ?? this.hideScroll,
      showStroke: showStroke ?? this.showStroke,
      massiveMode: massiveMode ?? this.massiveMode,
      safeArea: safeArea ?? this.safeArea,
    );
  }
}

class IDanmakuContentItem {
  /// 弹幕文本
  final String text;

  /// 弹幕颜色
  final Color color;

  /// 弹幕类型
  final IDanmakuItemType type;

  /// 是否为自己发送
  final bool selfSend;

  IDanmakuContentItem(this.text, {this.color = Colors.white, this.type = IDanmakuItemType.scroll, this.selfSend = false});
}

enum IDanmakuItemType {
  scroll,
  top,
  bottom,
}
