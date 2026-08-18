abstract class EmojiSourceType {
  const EmojiSourceType(this.name);
  final String name;

  bool get shouldCacheInMemory;

  static const EmojiSourceType asset = AssetSourceType();
  static const EmojiSourceType atlas = AtlasSourceType();
  static const EmojiSourceType network = NetworkSourceType();
  static const EmojiSourceType animated = AnimatedSourceType();
}

class AssetSourceType extends EmojiSourceType {
  const AssetSourceType() : super('asset');

  @override
  bool get shouldCacheInMemory => true;
}

class AtlasSourceType extends EmojiSourceType {
  const AtlasSourceType() : super('atlas');

  @override
  bool get shouldCacheInMemory => true;
}

class NetworkSourceType extends EmojiSourceType {
  const NetworkSourceType() : super('network');

  @override
  bool get shouldCacheInMemory => false;
}

class AnimatedSourceType extends EmojiSourceType {
  const AnimatedSourceType() : super('animated');

  @override
  bool get shouldCacheInMemory => true;
}
