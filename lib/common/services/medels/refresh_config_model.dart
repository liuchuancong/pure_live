class RefreshConfig {
  final bool autoRefreshFavorite;
  final int autoRefreshInterval;
  final int maxConcurrentRefresh;

  RefreshConfig({
    required this.autoRefreshFavorite,
    required this.autoRefreshInterval,
    required this.maxConcurrentRefresh,
  });
}
