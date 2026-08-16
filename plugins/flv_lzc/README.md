# flv_lzc (Video player plugin for Flutter)

[![pub package](https://img.shields.io/pub/v/flv_lzc.svg)](https://pub.dartlang.org/packages/flv_lzc)

A Flutter media player plugin for iOS and Android based on [ijkplayer](https://github.com/befovy/ijkplayer).

**This is a fixed version of fijkplayer 0.11.0 with compatibility improvements for modern Flutter versions.**

## Key Features

- ✅ **Fixed Compatibility**: Resolved `mRegistrar` deprecation issues for Flutter 3.x+
- ✅ **FLV/H.265 Support**: Full support for FLV streams with H.265 codec
- ✅ **Low Latency**: Optimized for live streaming with minimal delay
- ✅ **Cross Platform**: Works on both iOS and Android
- ✅ **Based on ijkplayer**: Powerful media playback capabilities

## What's Fixed

This package fixes the following issues from the original fijkplayer:
- Removed deprecated `mRegistrar` usage in Android plugin
- Updated to use modern Flutter plugin API
- Improved compatibility with Flutter 3.x and above
- Maintained all original features and functionality

## Documentation 文档

* Development Documentation https://fijkplayer.befovy.com/docs/en/ quick start、guide、and concepts about fijkplayer
* 开发文档  https://fijkplayer.befovy.com/docs/zh/ 包含快速开始、使用指南、fijkplayer 中的概念理解
* dart api https://pub.dev/documentation/fijkplayer/ detail API and argument explaination
* Release Notes https://github.com/befovy/fijkplayer/releases and [CHANGELOG.md](./CHANGELOG.md)
* FAQ https://fijkplayer.befovy.com/docs/zh/faq.html

## Installation 安装

Add `flv_lzc` as a [dependency in your pubspec.yaml file](https://flutter.io/using-packages/).

```yaml
dependencies:
  flv_lzc: ^1.0.0
```

Or use the latest version from pub.dev:

```yaml
dependencies:
  flv_lzc: ^1.0.0
```

## Example 示例

```dart
import 'package:flv_lzc/fijkplayer.dart';
import 'package:flutter/material.dart';

class VideoScreen extends StatefulWidget {
  final String url;

  VideoScreen({required this.url});

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final FijkPlayer player = FijkPlayer();

  _VideoScreenState();

  @override
  void initState() {
    super.initState();
    player.setDataSource(widget.url, autoPlay: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("FLV LZC Player Example")),
        body: Container(
          alignment: Alignment.center,
          child: FijkView(
            player: player,
          ),
        ));
  }

  @override
  void dispose() {
    super.dispose();
    player.release();
  }
}

```

## iOS Warning 警告

Warning: The video player plugin is not functional on iOS simulators. An iOS device must be used during development/testing. For more details, please refer to this [issue](https://github.com/flutter/flutter/issues/14647).

## Credits

This package is based on [fijkplayer](https://github.com/befovy/fijkplayer) by befovy. We've made compatibility fixes for modern Flutter versions while maintaining all the original functionality.

## License

MIT License - see LICENSE file for details
