bool isDummyVideoSize({required int width, required int height}) {
  if (width <= 0 || height <= 0) return false;
  final shortSide = width < height ? width : height;
  return shortSide <= dummyVideoShortSideLimit;
}

const int dummyVideoShortSideLimit = 32;

const Set<String> audioOnlyPlatforms = {'kilakila', 'missevan'};

bool isAudioOnlyPlatform(String? platform) =>
    platform != null && audioOnlyPlatforms.contains(platform);
