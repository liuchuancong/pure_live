import 'package:pure_live/common/index.dart';

void initRefresh() {
  EasyRefresh.defaultHeaderBuilder = () => ClassicHeader(
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

  EasyRefresh.defaultFooterBuilder = () => ClassicFooter(
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
}
