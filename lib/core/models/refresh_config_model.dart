class RefreshConfig {
  final bool autoRefreshFavorite;
  final bool refreshFavoriteOnResume;
  final int autoRefreshInterval;
  final int maxConcurrentRefresh;
  final bool autoRefreshThumbnails;
  final int thumbnailRefreshInterval;

  RefreshConfig({
    required this.autoRefreshFavorite,
    required this.refreshFavoriteOnResume,
    required this.autoRefreshInterval,
    required this.maxConcurrentRefresh,
    required this.autoRefreshThumbnails,
    required this.thumbnailRefreshInterval,
  });
}
