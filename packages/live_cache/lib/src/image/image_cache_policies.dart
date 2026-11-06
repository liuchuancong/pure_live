import 'package:live_cache/src/image/image_cache_policy.dart';
import 'package:live_cache/src/models/cache_priority.dart';

/// The stable category names the product uses.
abstract final class ImageCacheCategories {
  /// A streamer's portrait.
  static const String avatar = 'avatar';

  /// A signed-in viewer's portrait.
  static const String userAvatar = 'user_avatar';

  /// A live room's cover.
  static const String liveRoomCover = 'live_room_cover';

  /// A live room's detail-page artwork.
  static const String liveRoomDetail = 'live_room_detail';

  /// A video, episode or post cover.
  static const String videoCover = 'video_cover';

  /// A platform area/category cover.
  static const String categoryCover = 'category_cover';

  /// A collection or topic cover.
  static const String topicCover = 'topic_cover';

  /// A platform's own icon.
  static const String platformIcon = 'platform_icon';

  /// A search result's thumbnail.
  static const String searchThumbnail = 'search_thumbnail';

  /// A transient preview image.
  static const String preview = 'preview';

  /// The viewer's chosen background.
  static const String customBackground = 'custom_background';

  /// A chat emoticon, badge or gift picture.
  static const String chatEmote = 'chat_emote';

  /// An album or playlist cover.
  static const String albumCover = 'album_cover';

  /// An IPTV channel logo.
  static const String channelLogo = 'channel_logo';

  /// A network wallpaper.
  static const String wallpaper = 'wallpaper';

  /// The fallback for an image whose caller names no category.
  static const String general = 'general';
}

/// The preset policies from the cache specification plus the categories the
/// product's actual call sites needed.
abstract final class ImageCachePolicies {
  /// A streamer's portrait: changes rarely, kept for a month.
  static const ImageCachePolicy avatar = ImageCachePolicy(
    category: ImageCacheCategories.avatar,
    ttl: Duration(days: 30),
    priority: CachePriority.high,
    maxStale: Duration(days: 30),
  );

  /// A viewer's portrait: one day, then a background refresh.
  static const ImageCachePolicy userAvatar = ImageCachePolicy(
    category: ImageCacheCategories.userAvatar,
    ttl: Duration(days: 1),
  );

  /// A live room's cover: refreshed often enough to follow a new poster.
  static const ImageCachePolicy liveRoomCover = ImageCachePolicy(
    category: ImageCacheCategories.liveRoomCover,
    ttl: Duration(hours: 6),
  );

  /// A room's detail artwork: slower than the list cover.
  static const ImageCachePolicy liveRoomDetail = ImageCachePolicy(
    category: ImageCacheCategories.liveRoomDetail,
    ttl: Duration(hours: 12),
  );

  /// A video, episode or post cover.
  static const ImageCachePolicy videoCover = ImageCachePolicy(
    category: ImageCacheCategories.videoCover,
    ttl: Duration(days: 7),
  );

  /// A platform area cover.
  static const ImageCachePolicy categoryCover = ImageCachePolicy(
    category: ImageCacheCategories.categoryCover,
    ttl: Duration(days: 7),
  );

  /// A collection or topic cover.
  static const ImageCachePolicy topicCover = ImageCachePolicy(
    category: ImageCacheCategories.topicCover,
    ttl: Duration(days: 7),
  );

  /// A platform icon: tiny, shared and rarely new.
  static const ImageCachePolicy platformIcon = ImageCachePolicy(
    category: ImageCacheCategories.platformIcon,
    ttl: Duration(days: 30),
    priority: CachePriority.high,
    maxStale: Duration(days: 30),
  );

  /// A search result thumbnail: cheap to fetch again.
  static const ImageCachePolicy searchThumbnail = ImageCachePolicy(
    category: ImageCacheCategories.searchThumbnail,
    ttl: Duration(minutes: 30),
    priority: CachePriority.low,
  );

  /// A transient preview: fetch first, do not keep a dead copy long.
  static const ImageCachePolicy preview = ImageCachePolicy(
    category: ImageCacheCategories.preview,
    ttl: Duration(minutes: 30),
    priority: CachePriority.low,
    mode: ImageExpiryMode.refreshBeforeDisplay,
    maxStale: Duration(hours: 2),
  );

  /// The viewer's background: their explicit choice, never aged out.
  static const ImageCachePolicy customBackground = ImageCachePolicy(
    category: ImageCacheCategories.customBackground,
    ttl: null,
    priority: CachePriority.permanent,
    maxStale: null,
  );

  /// A chat emoticon, badge or gift picture.
  static const ImageCachePolicy chatEmote = ImageCachePolicy(
    category: ImageCacheCategories.chatEmote,
    ttl: Duration(days: 7),
  );

  /// An album or playlist cover.
  static const ImageCachePolicy albumCover = ImageCachePolicy(
    category: ImageCacheCategories.albumCover,
    ttl: Duration(days: 30),
  );

  /// An IPTV channel logo.
  static const ImageCachePolicy channelLogo = ImageCachePolicy(
    category: ImageCacheCategories.channelLogo,
    ttl: Duration(days: 7),
    priority: CachePriority.high,
  );

  /// A network wallpaper, browsed rather than chosen.
  static const ImageCachePolicy wallpaper = ImageCachePolicy(
    category: ImageCacheCategories.wallpaper,
    ttl: Duration(days: 1),
    priority: CachePriority.low,
  );

  /// The default for a caller that names no category.
  static const ImageCachePolicy general = ImageCachePolicy(
    category: ImageCacheCategories.general,
    ttl: Duration(days: 7),
  );

  /// Every preset, keyed by category.
  static const Map<String, ImageCachePolicy> presets = {
    ImageCacheCategories.avatar: avatar,
    ImageCacheCategories.userAvatar: userAvatar,
    ImageCacheCategories.liveRoomCover: liveRoomCover,
    ImageCacheCategories.liveRoomDetail: liveRoomDetail,
    ImageCacheCategories.videoCover: videoCover,
    ImageCacheCategories.categoryCover: categoryCover,
    ImageCacheCategories.topicCover: topicCover,
    ImageCacheCategories.platformIcon: platformIcon,
    ImageCacheCategories.searchThumbnail: searchThumbnail,
    ImageCacheCategories.preview: preview,
    ImageCacheCategories.customBackground: customBackground,
    ImageCacheCategories.chatEmote: chatEmote,
    ImageCacheCategories.albumCover: albumCover,
    ImageCacheCategories.channelLogo: channelLogo,
    ImageCacheCategories.wallpaper: wallpaper,
    ImageCacheCategories.general: general,
  };

  /// The preset for [category], or [general] when the name is not preset.
  static ImageCachePolicy byCategory(String category) => presets[category] ?? general;
}
