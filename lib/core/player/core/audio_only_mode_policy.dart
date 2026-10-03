/// 纯音频模式的两条路，以及什么时候真的关视频解码。
///
/// 手动切换（耳机按钮）只换 UI：视频组件留在树上继续解码，画面被
/// `AudioOnlyPresentation` 盖住，所以切回视频是即时的——不重建纹理、不重新等
/// 首帧、不黑屏一下。助眠会话自动进入时要真省电，关掉视频轨。
///
/// 退出纯音频模式**总是**恢复视频轨：进来的那条路可能是助眠，它把轨关掉了，
/// 而"当前是不是纯音频"这个标记并不记录当初是谁设的。
///
/// 这条判断放在 core 而不是 facade 里，因为它是播放器管线的策略，不是某个域的
/// 业务；`background_playback_policy.dart` 是同一种边界。
bool audioOnlyStopsVideoDecoding({required bool entering, required bool stopVideoDecoding}) {
  return !entering || stopVideoDecoding;
}
