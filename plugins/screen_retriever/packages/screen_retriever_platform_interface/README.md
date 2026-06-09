# screen_retriever_platform_interface

[![pub version][pub-image]][pub-url]

[pub-image]: https://img.shields.io/pub/v/screen_retriever_platform_interface.svg
[pub-url]: https://pub.dev/packages/screen_retriever_platform_interface

A common platform interface for the [screen_retriever](https://pub.dev/packages/screen_retriever) plugin.

## Usage

To implement a new platform-specific implementation of screen_retriever, extend `ScreenRetrieverPlatform` with an implementation that performs the platform-specific behavior, and when you register your plugin, set the default `ScreenRetrieverPlatform` by calling `ScreenRetrieverPlatform.instance = MyPlatformScreenRetriever()`.

## License

[MIT](./LICENSE)
