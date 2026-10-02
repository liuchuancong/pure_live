/// What the app paints behind its pages.
///
/// `image`/`video` address a file on the device - picked by the user or
/// downloaded from a wallpaper source; the `network*` variants stream a URL
/// through the shared image cache / the wallpaper player.
enum BackgroundSource { none, color, gradient, image, networkImage, video, networkVideo }

String backgroundSourceToString(BackgroundSource source) => source.name;

BackgroundSource backgroundSourceFromString(String value) =>
    BackgroundSource.values.firstWhere((source) => source.name == value, orElse: () => BackgroundSource.none);

bool isVideoBackground(BackgroundSource source) =>
    source == BackgroundSource.video || source == BackgroundSource.networkVideo;

bool isImageBackground(BackgroundSource source) =>
    source == BackgroundSource.image || source == BackgroundSource.networkImage;
