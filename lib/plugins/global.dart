import 'package:pure_live/core/index.dart';

typedef _RefreshLayout = ({double height, double? width, TextStyle? textStyle, TextStyle? messageStyle});

void initRefresh() {
  EasyRefresh.defaultHeaderBuilder = () => _buildHeader(_refreshLayout(Get.context));
  EasyRefresh.defaultFooterBuilder = () => _buildFooter(_refreshLayout(Get.context));
}

// App pages pass their local constraints/theme, including panes narrower than
// the navigator. The defaults remain available to other EasyRefresh consumers.
({ClassicHeader header, ClassicFooter footer}) appRefreshIndicators(BuildContext context, {double? maxWidth}) {
  final layout = _refreshLayout(context, maxWidth: maxWidth);
  return (header: _buildHeader(layout), footer: _buildFooter(layout));
}

ClassicHeader _buildHeader(_RefreshLayout layout) => ClassicHeader(
  triggerOffset: layout.height,
  textDimension: layout.width,
  textStyle: layout.textStyle,
  messageStyle: layout.messageStyle,
  armedText: i18n("refresh_release_to_load"),
  dragText: i18n("refresh_pull_up_to_refresh"),
  readyText: i18n("refresh_loading"),
  processingText: i18n("refresh_refreshing"),
  noMoreText: i18n("refresh_no_more_data"),
  failedText: i18n("refresh_load_failed"),
  messageText: i18n("refresh_last_updated_at"),
  processedText: i18n("refresh_load_success"),
  pullIconBuilder: (context, state, animation) {
    if (state.mode == IndicatorMode.processing || state.mode == IndicatorMode.ready) {
      return const AppStatusView(type: AppStatusType.loading, isMini: true);
    }
    return RotationTransition(
      turns: AlwaysStoppedAnimation(animation / 2),
      child: Icon(Icons.arrow_downward_rounded, color: Theme.of(context).colorScheme.outline, size: 24),
    );
  },
);

ClassicFooter _buildFooter(_RefreshLayout layout) => ClassicFooter(
  triggerOffset: layout.height,
  textDimension: layout.width,
  textStyle: layout.textStyle,
  messageStyle: layout.messageStyle,
  armedText: i18n("refresh_release_to_load"),
  dragText: i18n("refresh_pull_down_to_load"),
  readyText: i18n("refresh_loading"),
  processingText: i18n("refresh_refreshing"),
  noMoreText: i18n("refresh_no_more_data"),
  failedText: i18n("refresh_load_failed"),
  messageText: i18n("refresh_last_updated_at"),
  processedText: i18n("refresh_load_success"),
  pullIconBuilder: (context, state, animation) {
    if (state.mode == IndicatorMode.processing || state.mode == IndicatorMode.ready) {
      return const AppStatusView(type: AppStatusType.loading, isMini: true);
    }
    return RotationTransition(
      turns: AlwaysStoppedAnimation(animation / 2),
      child: Icon(Icons.arrow_upward_rounded, color: Theme.of(context).colorScheme.outline, size: 24),
    );
  },
);

// Classic indicators otherwise reserve 70 px for two unconstrained text lines.
// Measure the actual translated styles/scaler without shrinking accessible text.
_RefreshLayout _refreshLayout(BuildContext? context, {double? maxWidth}) {
  if (context == null) return (height: 70, width: null, textStyle: null, messageStyle: null);
  final media = MediaQuery.of(context);
  final theme = Theme.of(context).textTheme;
  final textStyle = theme.titleMedium ?? const TextStyle(fontSize: 16);
  final messageStyle = theme.bodySmall ?? const TextStyle(fontSize: 12);
  final direction = Directionality.of(context);
  final texts = [
    'refresh_release_to_load',
    'refresh_pull_up_to_refresh',
    'refresh_pull_down_to_load',
    'refresh_loading',
    'refresh_refreshing',
    'refresh_no_more_data',
    'refresh_load_failed',
    'refresh_load_success',
  ].map(i18n).toList();
  final message = i18n('refresh_last_updated_at').replaceAll('%T', '23:59');
  Size measure(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: media.textScaler,
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  // 24 px icon + 16 px gap + 12 px breathing room on either side.
  final available = ((maxWidth ?? media.size.width - media.padding.horizontal) - 64).clamp(1.0, double.infinity);
  var width = measure(message, messageStyle, double.infinity).width;
  for (final text in texts) {
    final value = measure(text, textStyle, double.infinity).width;
    if (value > width) width = value;
  }
  width = (width.ceilToDouble() + 8).clamp(1.0, available);
  var textHeight = 0.0;
  for (final text in texts) {
    final value = measure(text, textStyle, width).height;
    if (value > textHeight) textHeight = value;
  }
  final height = (textHeight + 4 + measure(message, messageStyle, width).height + 16).ceilToDouble();
  return (height: height < 70 ? 70 : height, width: width, textStyle: textStyle, messageStyle: messageStyle);
}
