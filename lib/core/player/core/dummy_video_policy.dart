/// 解码出来的画面是不是一路"占位视频"（dummy video track）而不是真的画面。
///
/// 猫耳 FM 的直播流里带一路 16×16 的 h264 占位视频，真内容是音频；按画面拉伸
/// 铺满就是一片纯色，用户看到的就是"蓝屏/绿屏"。
///
/// 判据用**短边**：占位轨是为了"有一路视频"而不是为了看，两个方向都只有十几个
/// 像素；真实画面再竖也不会短到这个地步（竖屏 1080×2280 的短边是 1080，最低的
/// 144p 也还有 144）。
///
/// 尺寸未知（解码器还没报）不算占位：那会儿该显示的是加载态，不是封面。
bool isDummyVideoSize({required int width, required int height}) {
  if (width <= 0 || height <= 0) return false;
  final shortSide = width < height ? width : height;
  return shortSide <= dummyVideoShortSideLimit;
}

/// 短边上限（像素）。32 给 16×16 的占位轨留了一倍余量，同时离任何真实档位都还
/// 很远，所以这个阈值不需要按平台分表。
const int dummyVideoShortSideLimit = 32;

/// 语音直播平台：源里只有一路视频但其实没有真画面（背景图/纯色），和占位轨
/// 一样应该显示房间封面而不是黑屏。这些平台的流返回正常的 FLV/HLS 视频轨，
/// [isDummyVideoSize] 的短边判据不会命中，所以按平台名单兜底。
const Set<String> audioOnlyPlatforms = {'kilakila', 'missevan'};

/// 该平台是否为语音直播（即使流带视频轨也不含真画面）。
bool isAudioOnlyPlatform(String? platform) =>
    platform != null && audioOnlyPlatforms.contains(platform);
