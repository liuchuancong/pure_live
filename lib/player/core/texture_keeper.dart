class TextureKeeper {
  static bool shouldRebuildTexture({required bool engineChanged, required bool textureInvalid}) {
    return engineChanged || textureInvalid;
  }
}
