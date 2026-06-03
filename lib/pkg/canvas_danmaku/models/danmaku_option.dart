class DanmakuOption {
  /// 默认的字体大小
  final double fontSize;

  /// 字体粗细
  final int fontWeight;

  /// 显示区域，0.1-1.0
  final double area;

  final double topAreaDistance;

  final double bottomAreaDistance;

  /// 滚动弹幕运行时间，秒
  final int duration;

  /// 不透明度，0.1-1.0
  final double opacity;

  /// 隐藏顶部弹幕
  final bool hideTop;

  /// 隐藏底部弹幕
  final bool hideBottom;

  /// 隐藏滚动弹幕
  final bool hideScroll;

  final bool hideSpecial;
  final int fps;

  /// 弹幕描边
  final bool showStroke;

  /// 海量弹幕模式 (弹幕轨道占满时进行叠加)
  final bool massiveMode;

  /// 为字幕预留空间
  final bool safeArea;

  DanmakuOption({
    this.fontSize = 16,
    this.fontWeight = 4,
    this.area = 1.0,
    this.topAreaDistance = 0.0,
    this.bottomAreaDistance = 0.0,
    this.duration = 10,
    this.opacity = 1.0,
    this.hideBottom = false,
    this.hideScroll = false,
    this.hideTop = false,
    this.hideSpecial = false,
    this.showStroke = true,
    this.massiveMode = false,
    this.safeArea = true,
    this.fps = 60,
  });

  DanmakuOption copyWith({
    double? area,
    double? fontSize,
    int? fontWeight,
    double? topAreaDistance,
    double? bottomAreaDistance,
    int? duration,
    double? opacity,
    bool? hideTop,
    bool? hideBottom,
    bool? hideScroll,
    bool? showStroke,
    bool? massiveMode,
    bool? safeArea,
    int? fps,
  }) {
    return DanmakuOption(
      area: area ?? this.area,
      topAreaDistance: topAreaDistance ?? this.topAreaDistance,
      bottomAreaDistance: bottomAreaDistance ?? this.bottomAreaDistance,
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
      fps: fps ?? this.fps,
    );
  }
}
