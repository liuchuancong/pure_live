import 'package:media_kit_video/media_kit_video.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_play_quality.dart';

/// 多画面布局枚举。
///
/// 每个布局隐含固定的行列划分，用于把屏幕物理像素均分给每个格子，
/// 作为该格 media_kit 渲染输出（VideoControllerConfiguration.width/height）
/// 的固定分辨率依据。注意行列划分只服务于渲染分辨率计算，
/// focus 布局的视觉排布（左大右小列）由 UI 层决定。
enum MultiviewLayout {
  /// 单画面（1 行 x 1 列）。
  single,

  /// 双画面（1 行 x 2 列，左右并排）。
  dual,

  /// 四画面（2 行 x 2 列）。
  quad,

  /// 一大多小（1 大 + 3 小）。
  ///
  /// 渲染分辨率复用 quad 的 2x2 均分数学：大格上采样、小格下采样的
  /// 画质取舍已接受。
  // TODO: 晋升大画面时重设该格渲染分辨率（VideoController.setSize），
  // 大格按整屏均分、小格按剩余区域均分，消除上采样模糊。
  focus;

  /// 当前布局可容纳的格子数量。
  int get capacity => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad || MultiviewLayout.focus => 4,
  };

  /// 当前列数（渲染分辨率按列均分宽度）。
  int get columns => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad || MultiviewLayout.focus => 2,
  };

  /// 当前行数（渲染分辨率按行均分高度）。
  int get rows => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 1,
    MultiviewLayout.quad || MultiviewLayout.focus => 2,
  };
}

/// 单格生命周期状态。
enum MultiviewCellStatus {
  /// 未分配房间。
  empty,

  /// 正在解析播放地址或正在起播。
  resolving,

  /// 已成功起播。
  playing,

  /// 房间被平台明确标记为未开播/已封禁。
  ///
  /// 这是可预期的业务状态，不是播放地址解析失败；该状态不创建播放器，
  /// UI 展示可重新选台的未开播占位。
  offline,

  /// 解析或起播失败，[MultiviewCellState.errorKind]/[MultiviewCellState.errorDetail] 携带原因。
  error,
}

/// Whether a picker selection may replace this cell without first asking the
/// user to stop an active decoder. Offline and failed cells retain room/error
/// context for display, but are still vacant from a playback-resource point of
/// view.
bool isMultiviewCellAssignable(MultiviewCellStatus status) {
  return status == MultiviewCellStatus.empty ||
      status == MultiviewCellStatus.offline ||
      status == MultiviewCellStatus.error;
}

/// Strict room lookup reported an authoritative non-playable state.
///
/// The resolver uses this typed signal so the controller can distinguish a
/// normal offline room from transport, parser and player failures without
/// parsing localized exception strings.
class MultiviewRoomOffline implements Exception {
  const MultiviewRoomOffline(this.room);

  final LiveRoom room;

  @override
  String toString() => 'MultiviewRoomOffline(${room.identityKey}, ${room.effectiveLiveStatus.name})';
}

/// 单格失败种类。
///
/// 核心层只记录种类与原始错误文本，不硬编码任何自然语言；
/// 展示文案由 UI 按当前语言映射对应的 i18n 键。
enum MultiviewCellErrorKind {
  /// 解析播放地址失败（站点接口/网络原因）。
  resolveFailure,

  /// 已取得地址但起播失败（播放内核打开媒体失败）。
  startFailure,
}

/// 换档加载器：按目标清晰度取回新的播放源（url + headers）。
///
/// 由解析器以闭包形式提供，内部携带 detail/site/headers 等最小上下文，
/// 使换档无需重走 getRoomDetail/getPlayQualites；核心层可注入假实现测试。
typedef MultiviewQualityLoader = Future<MultiviewStreamSource> Function(LivePlayQuality quality);

/// 单格播放源解析结果。
///
/// 直播流普遍需要平台鉴权头（Cookie/UA/Referer），因此除 URL 外
/// 一并携带请求头，交给每格播放器在 open 时使用。
/// qualities/qualityIndex/qualityLoader 支撑每格清晰度选择与换档：
/// 解析时一并取回清晰度列表，loader 保留后续换档所需的最小上下文。
class MultiviewStreamSource {
  const MultiviewStreamSource({
    required this.url,
    required this.headers,
    this.qualities = const <LivePlayQuality>[],
    this.qualityIndex = 0,
    this.qualityLoader,
    this.lines = const <String>[],
    this.lineIndex = 0,
  });

  /// 可直接交给播放内核的媒体地址。
  final String url;

  /// 打开该地址所需的 HTTP 头。
  final Map<String, String> headers;

  /// 该房间可用清晰度列表（约定首项为最高档）。
  final List<LivePlayQuality> qualities;

  /// 本次解析实际采用的档位下标（v1 默认最高档）。
  final int qualityIndex;

  /// 后续换档加载器；解析器未提供时该格不支持换档。
  final MultiviewQualityLoader? qualityLoader;

  /// 当前清晰度下的可用线路列表（getPlayUrls 的完整返回）；空表示未提供。
  final List<String> lines;

  /// 当前线路下标；lines 非空时 [url] 恒等于 lines[lineIndex]。
  final int lineIndex;
}

/// multiview 单格的不可变状态快照。
///
/// 控制器以 `RxList<MultiviewCellState>` 持有，长度恒等于当前布局容量；
/// UI 按 [videoController] 渲染画面、按 [status]/[errorKind] 呈现占位与错误。
class MultiviewCellState {
  const MultiviewCellState({
    required this.index,
    this.room,
    this.status = MultiviewCellStatus.empty,
    this.errorKind,
    this.errorDetail,
    this.videoController,
    this.qualities = const <LivePlayQuality>[],
    this.qualityIndex = 0,
    this.qualityLoader,
    this.headers = const <String, String>{},
    this.lines = const <String>[],
    this.lineIndex = 0,
  });

  /// 该格在当前布局中的固定下标（0 起）。
  final int index;

  /// 分配到该格的直播间模型；未分配时为 null。
  final LiveRoom? room;

  /// 当前生命周期状态。
  final MultiviewCellStatus status;

  /// 失败种类；仅 [MultiviewCellStatus.error] 时非空，UI 据此映射本地化文案。
  final MultiviewCellErrorKind? errorKind;

  /// 原始错误文本（未本地化）；仅 [MultiviewCellStatus.error] 时非空，
  /// 作为 i18n 文案的 {detail} 参数展示。
  final String? errorDetail;

  /// 该格 media_kit 的 VideoController，供 UI 的 Video widget 渲染；
  /// 尚未创建或已释放时为 null。
  final VideoController? videoController;

  /// 该房间可用清晰度列表（约定首项为最高档）；解析阶段一并获取，
  /// 空列表表示尚未解析或不支持换档。
  final List<LivePlayQuality> qualities;

  /// 当前档位下标；默认 0（最高档）。
  final int qualityIndex;

  /// 换档加载器（核心层上下文，UI 不消费）；null 表示不支持换档。
  final MultiviewQualityLoader? qualityLoader;

  /// 打开当前线路所需的 HTTP 头；与 lines 同生命周期。
  final Map<String, String> headers;

  /// 同清晰度下的可用线路列表；空表示未解析或不支持线路切换。
  final List<String> lines;

  /// 当前线路下标；lines 非空时画面即 lines[lineIndex]。
  final int lineIndex;

  /// 构造一个空白格状态。
  factory MultiviewCellState.empty(int index) => MultiviewCellState(index: index);

  MultiviewCellState copyWith({
    LiveRoom? room,
    bool clearRoom = false,
    MultiviewCellStatus? status,
    MultiviewCellErrorKind? errorKind,
    String? errorDetail,
    bool clearError = false,
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualities,
    int? qualityIndex,
    MultiviewQualityLoader? qualityLoader,
    bool clearQuality = false,
    Map<String, String>? headers,
    List<String>? lines,
    int? lineIndex,
  }) {
    return MultiviewCellState(
      index: index,
      room: clearRoom ? null : (room ?? this.room),
      status: status ?? this.status,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      videoController: clearVideoController ? null : (videoController ?? this.videoController),
      qualities: clearQuality ? const <LivePlayQuality>[] : (qualities ?? this.qualities),
      qualityIndex: clearQuality ? 0 : (qualityIndex ?? this.qualityIndex),
      qualityLoader: clearQuality ? null : (qualityLoader ?? this.qualityLoader),
      headers: clearQuality ? const <String, String>{} : (headers ?? this.headers),
      lines: clearQuality ? const <String>[] : (lines ?? this.lines),
      lineIndex: clearQuality ? 0 : (lineIndex ?? this.lineIndex),
    );
  }
}
