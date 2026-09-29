# [package:media_kit](https://github.com/media-kit/media-kit)

#### A cross-platform video player & audio player for Flutter & Dart.

[![](https://img.shields.io/discord/1079685977523617792?color=33cd57&label=Discord&logo=discord&logoColor=discord)](https://discord.gg/h7qf2R9n57) [![Github Actions](https://github.com/media-kit/media-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/media-kit/media-kit/actions/workflows/ci.yml)

<hr>

<strong>Sponsored with 💖 by</strong>

<a href="https://getstream.io/chat/sdk/flutter/?utm_source=alexmercerind_dart&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=alexmercerind_December2022_FlutterSDK_klmh22" target="_blank">
  <img alt="Stream Chat" width="200" height="auto" src="https://user-images.githubusercontent.com/28951144/204903022-bbaa49ca-74c2-4a8f-a05d-af8314bfd2cc.svg">
</a>
<br></br>
<strong>
  <a href="https://getstream.io/chat/sdk/flutter/?utm_source=alexmercerind_dart&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=alexmercerind_December2022_FlutterSDK_klmh22" target="_blank">
  Try the Flutter Chat tutorial
  </a>
</strong>

<br></br>

<a href="https://ottomatic.io/" target="_blank">
  <img alt="Stream Chat" width="200" height="auto" src="https://user-images.githubusercontent.com/28951144/228648844-f2a59ab1-12cd-4fee-bc8d-b2d332033c45.svg">
</a>
<br></br>
<strong>
  <a href="https://ottomatic.io/" target="_blank">
  Clever Apps for Film Professionals
  </a>
</strong>

## Installation

Requires Dart 3.10 / Flutter 3.38 or newer. The core package builds its lifecycle bridge and bundles native playback libraries through Dart build hooks. Add `media_kit_video` for Flutter textures. See [native build configuration](doc/native_assets.md).

#### For apps that need video playback:

```yaml
dependencies:
  media_kit:
    path: ../media-kit/media_kit
  media_kit_video:
    path: ../media-kit/media_kit_video
```

#### For apps that need audio playback:

```yaml
dependencies:
  media_kit:
    path: ../media-kit/media_kit
```

**Notes:**

- Audio and video use the same default native bundle; custom builds can be selected through hook configuration.
- The performance in ["Release" mode](https://docs.flutter.dev/testing/build-modes#release) is substantially higher than in ["Debug" mode](https://docs.flutter.dev/testing/build-modes#debug).
- [Enable --split-per-abi](https://docs.flutter.dev/deployment/android#what-is-a-fat-apk) or [use app bundle (instead of APK)](https://docs.flutter.dev/deployment/android#when-should-i-build-app-bundles-versus-apks) on Android.

## Platforms

| Platform  | Video | Audio | Notes                              | Demo                                                                                                                        |
| --------- | ----- | ----- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Android   | ✅    | ✅    | Android 5.0 or above.              | [Download](https://github.com/media-kit/media-kit/releases/download/media_kit-v1.1.10/media_kit_test_android-arm64-v8a.apk) |
| iOS       | ✅    | ✅    | iOS 13 or above.                    | [Download](https://github.com/media-kit/media-kit/releases/download/media_kit-v1.1.10/media_kit_test_ios_arm64.7z)          |
| macOS     | ✅    | ✅    | macOS 10.15 or above.               | [Download](https://github.com/media-kit/media-kit/releases/download/media_kit-v1.1.10/media_kit_test_macos_universal.7z)    |
| Windows   | ✅    | ✅    | Windows 10 or above.                | [Download](https://github.com/media-kit/media-kit/releases/download/media_kit-v1.1.10/media_kit_test_win32_x64.7z)          |
| GNU/Linux | ✅    | ✅    | Any modern GNU/Linux distribution. | [Download](https://github.com/media-kit/media-kit/releases/download/media_kit-v1.1.10/media_kit_test_linux_x64.7z)          |
| Web       | ✅    | ✅    | Any modern web browser.            | [Visit](https://media-kit.github.io/media-kit/)                                                                             |

<table>
  <tr>
    <td>
      Android
    </td>
    <td>
      iOS
    </td>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/cf93a1fd-e1d8-4d1c-8bd5-cc393cef1ce9" height="400" alt="Android"></img>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/aea1f480-51e2-452a-b53c-c0e27f71f0d8" height="400" alt="Android"></img>
    </td>
    <td>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/e8ce64cb-1ea9-4a3e-bc9c-db620abf88c9" height="400" alt="iOS"></img>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/d7159df2-1df1-46d3-84f8-238e2a66bfbc" height="400" alt="iOS"></img>
    </td>
  </tr>
  <tr>
    <td>
      macOS
    </td>
    <td>
      Windows
    </td>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/fca8dbbf-4262-431f-a04a-f3aa6afb2911" height="200" alt="macOS"></img>
    </td>
    <td>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/742b0016-da58-42de-9880-ecaa0604c2b2" height="200" alt="Windows"></img>
    </td>
  </tr>
  <tr>
    <td>
      GNU/Linux
    </td>
    <td>
      Web
    </td>
  </tr>
  <tr>
    <td>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/8cd63750-6746-4c75-bc4e-cca5e4c61890" height="200" alt="GNU/Linux"></img>
    </td>
    <td>
      <img src="https://github.com/media-kit/media-kit/assets/28951144/feb9fdf2-095f-43db-96af-f7782985238d" height="200" alt="Web"></img>
    </td>
</table>

- ✅ Video playback
- ✅ Audio playback
- ✅ Cross platform
- ✅ Wide format/codec support
- ✅ Hardware/GPU acceleration
- ✅ Playlist support with next/previous/jump/shuffle
- ✅ Volume/Rate/Pitch change
- ✅ Video/Audio/Subtitle track selection
- ✅ External audio/subtitle track selection
- ✅ HTTP headers
- ✅ Video controls
- ✅ Subtitle styling
- ✅ Screenshot

## TL;DR

A quick usage example.

```dart
// Make sure to add following packages to pubspec.yaml:
// * media_kit
// * media_kit_video
import 'package:flutter/material.dart';

import 'package:media_kit/media_kit.dart';                      // Provides [Player], [Media], [Playlist] etc.
import 'package:media_kit_video/media_kit_video.dart';          // Provides [VideoController] & [Video] etc.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Necessary initialization for package:media_kit.
  MediaKit.ensureInitialized();
  runApp(
    const MaterialApp(
      home: MyScreen(),
    ),
  );
}

class MyScreen extends StatefulWidget {
  const MyScreen({Key? key}) : super(key: key);
  @override
  State<MyScreen> createState() => MyScreenState();
}

class MyScreenState extends State<MyScreen> {
  // Create a [Player] to control playback.
  late final player = Player();
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    // Play a [Media] or [Playlist].
    player.open(Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * 9.0 / 16.0,
        // Use [Video] widget to display video output.
        child: Video(controller: controller),
      ),
    );
  }
}
```

**Note:** You may need to add required [permissions](#permissions) to your project.

## Guide

A usage guide for [package:media_kit](https://github.com/media-kit/media-kit).

**Tip:** Use <kbd>Ctrl</kbd> + <kbd>F</kbd> to quickly search for things.

### Contents

- [Initialization](#initialization)
- [Create a `Player`](#create-a-player)
- [Dispose a `Player`](#dispose-a-player)
- [Open a `Media` or `Playlist`](#open-a-media-or-playlist)
- [Play, pause or play/pause](#play-pause-or-playpause)
- [Seek](#seek)
- [Loop or repeat](#loop-or-repeat)
- [Set volume, rate or pitch](#set-volume-rate-or-pitch)
- [Handle playback events](#handle-playback-events)
- [Shuffle the queue](#shuffle-the-queue)
- [Use HTTP headers](#use-http-headers)
- [Use `extras` to store additional data with `Media`](use-extras-store-additional-data-with-media)
- [Go to next, previous or any other position in queue](#go-to-next-previous-or-any-other-position-in-queue)
- [Modify `Player`'s queue](#modify-players-queue)
- [Select video, audio or subtitle track](#select-video-audio-or-subtitle-track)
- [Select audio device](#select-audio-device)
- [Display the video](#display-the-video)
- [Capture screenshot](#capture-screenshot)
- [Customize subtitles](#customize-subtitles)
- [Load external subtitle track](#load-external-subtitle-track)
- [Load external audio track](#load-external-audio-track)
- [Video controls](#video-controls)
- [Next steps](#next-steps)

### Initialization

`MediaKit.ensureInitialized` must be called before using the package:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Make sure to add the required packages to pubspec.yaml:
  // * https://github.com/media-kit/media-kit#installation
  // * https://pub.dev/packages/media_kit#installation
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}
```

The method also has some optional arguments to customize the global behavior. To handle any initialization errors, this may be surrounded by `try`/`catch`.

### Create a `Player`

A `Player` instance is used to start & control the playback of a media source e.g. URL or file.

```dart
final Player player = Player();
```

Additional options may be provided using the `configuration` argument in the constructor. In general situations, you will never require this.

```dart
final Player player = Player(
  configuration: PlayerConfiguration(
    // Supply your options:
    title: 'My awesome package:media_kit application',
    ready: () {
      print('The initialization is complete.');
    },
  ),
);
```

### Dispose a `Player`

It is extremely important to release the allocated resources back to the system:

```dart
await player.dispose();
```

### Open a `Media` or `Playlist`

A `Playable` can either be a `Media` or a `Playlist`.

- `Media`: Single playback source (file or URL).
- `Playlist`: Queue of playback sources (file or URL).

Use the `Player.open` method to load & start playback.

#### `Media`

```dart
final playable = Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4');
await player.open(playable);
```

#### `Playlist`

```dart
final playable = Playlist(
  [
    Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373709-603a7a89-2105-4e1b-a5a5-a6c3567c9a59.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373716-76da0a4e-225a-44e4-9ee7-3e9006dbc3e3.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373718-86ce5e1d-d195-45d5-baa6-ef94041d0b90.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373720-14d69157-1a56-4a78-a2f4-d7a134d7c3e9.mp4'),
  ],
);
await player.open(playable);
```

**Notes:**

1. By default, this will automatically start playing the playable. This may be disabled as follows:

```dart
await player.open(
  playable,
  play: false,
);
```

2. By default, the playlist will start at the index `0`. This may be changed as follows:

```dart
final playable = Playlist(
  [
    Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373709-603a7a89-2105-4e1b-a5a5-a6c3567c9a59.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373716-76da0a4e-225a-44e4-9ee7-3e9006dbc3e3.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373718-86ce5e1d-d195-45d5-baa6-ef94041d0b90.mp4'),
    Media('https://user-images.githubusercontent.com/28951144/229373720-14d69157-1a56-4a78-a2f4-d7a134d7c3e9.mp4'),
  ],
  // Declare the starting position.
  index: 0,
);
await player.open(playable);
```

### Play, pause or play/pause

The 3 methods are:

```dart
await player.play();
```

```dart
await player.pause();
```

```dart
await player.playOrPause();
```

### Stop

The `stop` method may be used to stop the playback of currently opened `Media` or `Playlist`.

```dart
await player.stop();
```

It does not release allocated resources back to the system (unlike [`dispose`](#dispose-a-player)) & `Player` still stays usable.

### Seek

Supply the final position to `Player.seek` method as `Duration`:

```dart
await player.seek(
  const Duration(
    minutes: 6,
    seconds: 9,
  ),
);
```

### Loop or repeat

Three `PlaylistMode`s are available:

- `PlaylistMode.none`: End playback once end of the playlist is reached.
- `PlaylistMode.single`: Indefinitely loop over the currently playing file in the playlist.
- `PlaylistMode.loop`: Loop over the playlist & restart it from beginning once end is reached.

```dart
await player.setPlaylistMode(PlaylistMode.single);
```

### Set volume, rate or pitch

#### Set the volume

This controls the loudness of audio output. The maximum volume is `100.0`.

```dart
await player.setVolume(50.0);
```

#### Set the rate

This controls the playback speed.

```dart
await player.setRate(1.5);
```

#### Set the pitch

This controls the pitch of the audio output.

```dart
await player.setPitch(1.2);
```

**Note:** This requires `pitch` argument to be `true` in `PlayerConfiguration`.

### Handle playback events

You can access or subscribe to `Player`'s state changes.

Event handling is an extremely important part of media playback. It is used to show changes in the UI, handle errors, detect the occurrence of play/pause, end-of-file, position updates etc.

- `Player.stream.*`: Provides access to `Player`'s state as [`Stream`](https://dart.dev/tutorials/language/streams)(s).
- `Player.state.*`: Provides access to `Player`'s state directly (for instantaneous access).

A typical example will be:

```dart
player.stream.playing.listen(
  (bool playing) {
    if (playing) {
      // Playing.
    } else {
      // Paused.
    }
  },
);
player.stream.position.listen(
  (Duration position) {
    setState(() {
      // Update UI.
    });
  },
);
```

The following state(s) are available as events:

| Type                        | Name           | Description                                                                                              |
| --------------------------- | -------------- | -------------------------------------------------------------------------------------------------------- |
| `Stream<Playlist>`          | `playlist`     | Currently opened media sources.                                                                          |
| `Stream<bool>`              | `playing`      | Whether playing or not.                                                                                  |
| `Stream<bool>`              | `completed`    | Whether end of currently playing media source has been reached.                                          |
| `Stream<Duration>`          | `position`     | Current playback position.                                                                               |
| `Stream<Duration>`          | `duration`     | Current playback duration.                                                                               |
| `Stream<double>`            | `volume`       | Current volume.                                                                                          |
| `Stream<double>`            | `rate`         | Current playback rate.                                                                                   |
| `Stream<double>`            | `pitch`        | Current pitch.                                                                                           |
| `Stream<bool>`              | `buffering`    | Whether buffering or not.                                                                                |
| `Stream<Duration>`          | `buffer`       | Current buffer position. This indicates how much of the stream has been decoded & cached by the demuxer. |
| `Stream<PlaylistMode>`      | `playlistMode` | Current playlist mode.                                                                                   |
| `Stream<AudioParams>`       | `audioParams`  | Audio parameters of the currently playing media source e.g. sample rate, channels, etc.                  |
| `Stream<VideoParams>`       | `videoParams`  | Video parameters of the currently playing media source e.g. width, height, rotation etc.                 |
| `Stream<double?>`           | `audioBitrate` | Audio bitrate of the currently playing media source.                                                     |
| `Stream<double?>`           | `videoBitrate` | Video bitrate of the currently playing media source.                                                     |
| `Stream<AudioDevice>`       | `audioDevice`  | Currently selected audio device.                                                                         |
| `Stream<List<AudioDevice>>` | `audioDevices` | Currently available audio devices.                                                                       |
| `Stream<Track>`             | `track`        | Currently selected video, audio and subtitle track.                                                      |
| `Stream<Tracks>`            | `tracks`       | Currently available video, audio and subtitle tracks.                                                    |
| `Stream<int>`               | `width`        | Currently playing video's width.                                                                         |
| `Stream<int>`               | `height`       | Currently playing video's height.                                                                        |
| `Stream<int>`               | `subtitle`     | Currently displayed subtitle.                                                                            |
| `Stream<PlayerLog>`         | `log`          | Internal logs.                                                                                           |
| `Stream<String>`            | `error`        | Error messages. This may be used to handle & display errors to the user.                                 |

### Shuffle the queue

You may find the requirement to shuffle the `Playlist` you `open`'d in `Player`, like some music players do.

```dart
await player.setShuffle(true);
```

**Note:** This option is reset upon the next `Player.open` call.

### Use HTTP headers

Declare the `httpHeaders` argument in `Media` constructor. It takes the HTTP headers as `Map<String, String>`.

```dart
final playable = Media(
  'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4',
  httpHeaders: {
    'Foo': 'Bar',
    'Accept': '*/*',
    'Range': 'bytes=0-',
  },
);
```

### Use `extras` to store additional data with `Media`

The `extras` argument may be utilized to store additional data with a `Media` in form of `Map<String, dynamic>`.

```dart
final playable = Media(
  'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4',
  extras: {
    'track': '9',
    'year': '2012',
    'title': 'Courtesy Call',
    'artist': 'Thousand Foot Krutch',
    'album': 'The End Is Where We Begin',
  },
);
```

### Modify `Player`'s queue

You can add or remove (etc.) a `Media` in an already playing `Playlist`:

#### Add

Add a new `Media` to the back of the queue:

```dart
await player.add(Media('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'));
```

#### Remove

Remove any item from the queue:

```dart
await player.remove(0);
```

#### Move

Move any item in the queue from one position to another:

```dart
await player.move(6, 9);
```

### Go to next, previous or any other position in queue

#### Skip to the next queue item

```dart
await player.next();
```

#### Skip to the previous queue item

```dart
await player.previous();
```

#### Skip to any other queue item

```dart
await player.jump(5);
```

### Select video, audio or subtitle track

A media source may contain multiple video, audio or subtitle tracks e.g. for multiple languages. Available video, audio or subtitle tracks are notified through `Player`'s state. See ["Handle playback events" section](#handle-playback-events) for related information.

By default, video, audio & subtitle track is selected automatically _i.e._ `VideoTrack.auto()`, `AudioTrack.auto()` & `SubtitleTrack.auto()`.

#### Automatic selection

```dart
await player.setVideoTrack(VideoTrack.auto());

await player.setAudioTrack(AudioTrack.auto());

await player.setSubtitleTrack(SubtitleTrack.auto());
```

#### Disable track

This may be used to essentially disable video output, disable audio output or stop rendering of subtitles etc.

```dart
await player.setVideoTrack(VideoTrack.no());

await player.setAudioTrack(AudioTrack.no());

await player.setSubtitleTrack(SubtitleTrack.no());
```

#### Select custom track

- Retrieve currently available tracks:

```dart
List<VideoTrack> videos = player.state.tracks.video;
List<AudioTrack> audios = player.state.tracks.audio;
List<SubtitleTrack> subtitles = player.state.tracks.subtitle;

// Get notified as [Stream]:
player.stream.tracks.listen((event) {
  List<VideoTrack> videos = event.video;
  List<AudioTrack> audios = event.audio;
  List<SubtitleTrack> subtitles = event.subtitle;
});
```

- Select the track:

```dart
await player.setVideoTrack(videos[0]);
await player.setAudioTrack(audios[1]);
await player.setSubtitleTrack(subtitles[2]);
```

- Get notified about currently selected track:

```dart
VideoTrack video = player.state.track.video;
AudioTrack audio = player.state.track.audio;
SubtitleTrack subtitle = player.state.track.subtitle;

// Get notified as [Stream]:
player.stream.track.listen((event) {
  VideoTrack video = event.video;
  AudioTrack audio = event.audio;
  SubtitleTrack subtitle = event.subtitle;
});
```

### Select audio device

Available audio devices are notified through `Player`'s state. See ["Handle playback events" section](#handle-playback-events) for related information.

By default, audio device is selected automatically _i.e._ `AudioDevice.auto()`.

#### Default selection

```dart
await player.setAudioDevice(AudioDevice.auto());
```

#### Disable audio output

```dart
await player.setAudioDevice(AudioDevice.no());
```

#### Select custom audio device

- Retrieve currently available audio devices:

```dart
List<AudioDevice> devices = player.state.audioDevices;

// Get notified as [Stream]:
player.stream.audioDevices.listen((event) {
  List<AudioDevice> devices = event;
});
```

- Select the audio device:

```dart
await player.setAudioDevice(devices[1]);
```

- Get notified about currently selected audio device:

```dart
AudioDevice device = player.state.audioDevice;

// Get notified as [Stream]:
player.stream.audioDevice.listen((event) {
  AudioDevice device = event;
});
```

### Display the video

The **existing ["TL;DR example"](#tldr) should provide you better idea**.

For displaying the video inside Flutter UI, you must:

- Create `VideoController`
  - Pass the `Player` you already have.
- Create `Video` widget
  - Pass the `VideoController` you already have.

The code is easier to understand:

```dart
class _MyScreenState extends State<MyScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Video(
        controller: controller,
      ),
    );
  }
}
```

The video playback uses [hardware acceleration](https://en.wikipedia.org/wiki/Hardware_acceleration) _i.e._ GPU by default.

Additional options may be provided using the `configuration` argument in the constructor. In general situations, you will never require this.

```dart
final VideoController player = VideoController(
  player,
  configuration: const VideoControllerConfiguration(
    // Supply your options:
    enableHardwareAcceleration: true,      // default: true
    enableAndroidSurfaceProducer: true,    // Android only, default: true
    width: 640,                            // default: null
    height: 480,                           // default: null
    // The in-code comments is best place to know more about these options:
    // https://github.com/media-kit/media-kit/blob/main/media_kit_video/lib/src/video_controller/video_controller.dart
  ),
);
```

### Capture screenshot

The `screenshot` method takes the snapshot of the current video frame & returns encoded image bytes as `Uint8List`.

```dart
final Uint8List? screenshot = await player.screenshot();
```

Additionally `format` argument may be specified to change the encoding format. Following formats are supported:

- `image/jpeg`: Returns a JPEG encoded image.
- `image/png`: Returns a PNG encoded image.
- `null`: Returns BGRA pixel buffer.

### Customize subtitles

`SubtitleViewConfiguration` can be passed to the `Video` widget for customizing the subtitles. The code is easier to understand:

Notably, `TextStyle`, `TextAlign` & `EdgeInsetsGeometry` can be provided.

```dart
Video(
  controller: controller,
  subtitleViewConfiguration: const SubtitleViewConfiguration(
    style: TextStyle(
      height: 1.4,
      fontSize: 24.0,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
      color: Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: Color(0xaa000000),
    ),
    textAlign: TextAlign.center,
    padding: EdgeInsets.all(24.0),
  ),
);
```

https://user-images.githubusercontent.com/28951144/253067794-73b5ca5d-e90d-4892-bc09-2a80f05c9f0b.mp4

### Load external subtitle track

The `SubtitleTrack.uri` constructor can be used to load external subtitle track **with URI** e.g. SRT, WebVTT etc. The code is easier to understand:

```dart
await player.setSubtitleTrack(
  SubtitleTrack.uri(
    'https://www.iandevlin.com/html5test/webvtt/upc-video-subtitles-en.vtt',
    title: 'English',
    language: 'en',
  ),
);
```

The `SubtitleTrack.data` constructor can be used to load external subtitle track **with data** e.g. SRT, WebVTT etc. The code is easier to understand:

```dart
player.setSubtitleTrack(
  SubtitleTrack.data(
    '''WEBVTT FILE

1
00:00:03.500 --> 00:00:05.000 D:vertical A:start
Everyone wants the most from life

2
00:00:06.000 --> 00:00:09.000 A:start
Like internet experiences that are rich <b>and</b> entertaining

3
00:00:11.000 --> 00:00:14.000 A:end
Phone conversations where people truly <c.highlight>connect</c>

4
00:00:14.500 --> 00:00:18.000
Your favourite TV programmes ready to watch at the touch of a button

5
00:00:19.000 --> 00:00:24.000
Which is why we are bringing TV, internet and phone together in <c.highlight>one</c> super package

6
00:00:24.500 --> 00:00:26.000
<c.highlight>One</c> simple way to get everything

7
00:00:26.500 --> 00:00:27.500 L:12%
UPC

8
00:00:28.000 --> 00:00:30.000 L:75%
Simply for <u>everyone</u>
''',
    title: 'English',
    language: 'en',
  ),
);
```

### Load external audio track

The `AudioTrack.uri` constructor can be used to load external audio track **with URI**. The code is easier to understand:

```dart
await player.setAudioTrack(
  AudioTrack.uri(
    'https://www.iandevlin.com/html5test/webvtt/v/upc-tobymanley.mp4',
    title: 'English',
    language: 'en',
  ),
);
```

### Video controls

[`package:media_kit`](https://github.com/media-kit/media-kit) provides highly-customizable pre-built video controls for usage.

Apart from theming, layout can be customized, position of buttons can be modified, custom buttons can be created etc. Necessary features like fullscreen, keyboard shortcuts & swipe-based controls are also supported by default.

<table>
  <tr>
    <td>
      <a href="#materialdesktopvideocontrols"><tt>MaterialDesktopVideoControls</tt></a>
    </td>
    <td>
      <a href="#materialvideocontrols"><tt>MaterialVideoControls</tt></a>
    </td>
  </tr>
  <tr>
    <td>
      <img height="312" src="https://user-images.githubusercontent.com/28951144/246606748-72557578-8be4-43c6-a3df-cb0aea99c879.jpg">
    </td>
    <td>
      <img height="312" src="https://user-images.githubusercontent.com/28951144/246650427-a5bbabad-6f7b-4098-9325-ebe2a3068720.jpg">
    </td>
  </tr>
</table>

- `Video` widget provides `controls` argument to display & customize video controls.
- By default, [`AdaptiveVideoControls`](#adaptivevideocontrols) are used.

#### Types

| Type                                                            | Description                                                                                                                            |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| [`AdaptiveVideoControls`](#adaptivevideocontrols)               | Selects [`MaterialVideoControls`](#materialvideocontrols), [`CupertinoVideoControls`](#cupertinovideocontrols) etc. based on platform. |
| [`MaterialVideoControls`](#materialvideocontrols)               | [Material Design](https://material.io/) video controls.                                                                                |
| [`MaterialDesktopVideoControls`](#materialdesktopvideocontrols) | [Material Design](https://material.io/) video controls for desktop.                                                                    |
| [`CupertinoVideoControls`](#cupertinovideocontrols)             | [iOS-style](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) video controls.                           |
| [`NoVideoControls`](#novideocontrols)                           | Disable video controls _i.e._ only render video output.                                                                                |
| Custom                                                          | Provide custom `builder` for video controls.                                                                                           |

#### Select existing video controls

Modify the `controls` argument. For advanced theming of existing video controls, see [theming & modifying video controls](#theming-&-modifying-video-controls) section.

```dart
Scaffold(
  body: Video(
    controller: controller,
    // Select [MaterialVideoControls].
    controls: MaterialVideoControls,
  ),
);
```

```dart
Scaffold(
  body: Video(
    controller: controller,
    // Select [CupertinoVideoControls].
    controls: CupertinoVideoControls,
  ),
);
```

#### Build custom video controls

Pass custom builder `Widget Function(BuildContext, VideoController)` as `controls` argument.

```dart
Scaffold(
  body: Video(
    controller: controller,
    // Provide custom builder for controls.
    controls: (state) {
      return Center(
        child: IconButton(
          onPressed: () {
            state.widget.controller.player.playOrPause();
          },
          icon: StreamBuilder(
            stream: state.widget.controller.player.stream.playing,
            builder: (context, playing) => Icon(
              playing.data == true ? Icons.pause : Icons.play_arrow,
            ),
          ),
          // It's not necessary to use [StreamBuilder] or to use [Player] & [VideoController] from [state].
          // [StreamSubscription]s can be made inside [initState] of this widget.
        ),
      );
    },
  ),
);
```

#### Use & modify video controls

##### `AdaptiveVideoControls`

- Selects [`MaterialVideoControls`](#materialvideocontrols), [`CupertinoVideoControls`](#cupertinovideocontrols) etc. based on platform.
- Theming:
  - Theme the specific controls according to sections below.

##### `MaterialVideoControls`

- [Material Design](https://material.io/) video controls.
- Theming:
  - Use `MaterialVideoControlsTheme` widget.
  - `Video` widget(s) in the `child` tree will follow the specified theme:

```dart
// Wrap [Video] widget with [MaterialVideoControlsTheme].
MaterialVideoControlsTheme(
  normal: MaterialVideoControlsThemeData(
    // Modify theme options:
    buttonBarButtonSize: 24.0,
    buttonBarButtonColor: Colors.white,
    // Modify top button bar:
    topButtonBar: [
      const Spacer(),
      MaterialDesktopCustomButton(
        onPressed: () {
          debugPrint('Custom "Settings" button pressed.');
        },
        icon: const Icon(Icons.settings),
      ),
    ],
  ),
  fullscreen: const MaterialVideoControlsThemeData(
    // Modify theme options:
    displaySeekBar: false,
    automaticallyImplySkipNextButton: false,
    automaticallyImplySkipPreviousButton: false,
  ),
  child: Scaffold(
    body: Video(
      controller: controller,
    ),
  ),
);
```

- Related widgets (may be used in `primaryButtonBar`, `topButtonBar` & `bottomButtonBar`):
  - `MaterialPlayOrPauseButton`
  - `MaterialSkipNextButton`
  - `MaterialSkipPreviousButton`
  - `MaterialFullscreenButton`
  - `MaterialCustomButton`
  - `MaterialPositionIndicator`

##### `MaterialDesktopVideoControls`

- [Material Design](https://material.io/) video controls for desktop.
- Theming:
  - Use `MaterialDesktopVideoControlsTheme` widget.
  - `Video` widget(s) in the `child` tree will follow the specified theme:

```dart
// Wrap [Video] widget with [MaterialDesktopVideoControlsTheme].
MaterialDesktopVideoControlsTheme(
  normal: MaterialDesktopVideoControlsThemeData(
    // Modify theme options:
    seekBarThumbColor: Colors.blue,
    seekBarPositionColor: Colors.blue,
    toggleFullscreenOnDoublePress: false,
    // Modify top button bar:
    topButtonBar: [
      const Spacer(),
      MaterialDesktopCustomButton(
        onPressed: () {
          debugPrint('Custom "Settings" button pressed.');
        },
        icon: const Icon(Icons.settings),
      ),
    ],
    // Modify bottom button bar:
    bottomButtonBar: const [
      Spacer(),
      MaterialDesktopPlayOrPauseButton(),
      Spacer(),
    ],
  ),
  fullscreen: const MaterialDesktopVideoControlsThemeData(),
  child: Scaffold(
    body: Video(
      controller: controller,
    ),
  ),
);
```

- Related widgets (may be used in `primaryButtonBar`, `topButtonBar` & `bottomButtonBar`):
  - `MaterialDesktopPlayOrPauseButton`
  - `MaterialDesktopSkipNextButton`
  - `MaterialDesktopSkipPreviousButton`
  - `MaterialDesktopFullscreenButton`
  - `MaterialDesktopCustomButton`
  - `MaterialDesktopVolumeButton`
  - `MaterialDesktopPositionIndicator`
- Keyboard shortcuts may be modified using `keyboardShortcuts` argument. Default ones are listed below:

| Shortcut                    | Action                |
| --------------------------- | --------------------- |
| Media Play Button           | Play                  |
| Media Pause Button          | Pause                 |
| Media Play/Pause Button     | Play/Pause            |
| Media Next Track Button     | Skip Next             |
| Media Previous Track Button | Skip Previous         |
| Space                       | Play/Pause            |
| J                           | Seek 10s Behind       |
| I                           | Seek 10s Ahead        |
| Arrow Left                  | Seek 2s Behind        |
| Arrow Right                 | Seek 2s Ahead         |
| Arrow Up                    | Increase Volume 5%    |
| Arrow Down                  | Decrease Volume 5%    |
| F                           | Enter/Exit Fullscreen |
| Escape                      | Exit Fullscreen       |

##### `CupertinoVideoControls`

- [iOS-style](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) video controls.
- Theming:
  - Use `CupertinoVideoControlsTheme` widget.
  - `Video` widget(s) in the `child` tree will follow the specified theme:

```dart
// Wrap [Video] widget with [CupertinoVideoControlsTheme].
CupertinoVideoControlsTheme(
  normal: const CupertinoVideoControlsThemeData(
    // W.I.P.
  ),
  fullscreen: const CupertinoVideoControlsThemeData(
    // W.I.P.
  ),
  child: Scaffold(
    body: Video(
      controller: controller,
    ),
  ),
);
```

##### `NoVideoControls`

- Disable video controls _i.e._ only render video output.
- Theming:
  - No theming applicable.

### Next steps

This guide follows a tutorial-like structure & covers nearly all features that [package:media_kit](https://github.com/media-kit/media-kit) offers. However, it is _not complete_ by any means. You are free to improve this page & add more documentation, which newcomers may find helpful. The following places can help you learn more:

- [API reference](https://pub.dev/documentation/media_kit/latest/media_kit/media_kit-library.html) can be helpful for diving into deeper specifics.
- [source-code of the demo application](https://github.com/media-kit/media-kit/tree/main/media_kit_test/lib/tests) offers some complete code samples.
- In-code comments & docstrings happen to be the most updated source of knowledge.

## Goals

[package:media_kit](https://github.com/media-kit/media-kit) is a library for Flutter & Dart which **provides video & audio playback**.

- **Strong:** Supports _most_ video & audio codecs.
- **Performant:**
  - Handles multiple FHD videos flawlessly.
  - Rendering is GPU-powered (hardware accelerated).
  - 4K / 8K 60 FPS is supported.
- **Stable:** Implementation is well-tested & used across number of intensive media playback related apps.
- **Feature Proof:** A simple usage API while offering a large number of features to target multitude of apps.
- **Modular:** Project is split into a number of packages for reducing bundle size.
- **Cross Platform**: Implementation works on all platforms supported by Flutter & Dart:
  - Android
  - iOS
  - macOS
  - Windows
  - GNU/Linux
  - Web
- **Flexible Architecture:**
  - Major part of implementation (80%+) is in 100% Dart ([FFI](https://dart.dev/guides/libraries/c-interop)) & shared across platforms.
    - Makes the behavior of library same & more predictable across platforms.
    - Makes development & implementation of new features easier & faster.
    - Avoids separate maintenance of native implementation for each platform.
  - Only video embedding code is platform-specific & part of separate package.

You may see project's [architecture](https://github.com/media-kit/media-kit#architecture) & [implementation](https://github.com/media-kit/media-kit#implementation) details for further information.

The project aims to meet demands of the community, this includes:

1. Holding accountability.
2. Ensuring timely maintenance.

## Supported Formats

A wide variety of formats & codecs are supported. Complete list may be found below:

<details>

```
3dostr          3DO STR
4xm             4X Technologies
aa              Audible AA format files
aac             raw ADTS AAC (Advanced Audio Coding)
aax             CRI AAX
ac3             raw AC-3
ace             tri-Ace Audio Container
acm             Interplay ACM
act             ACT Voice file format
adf             Artworx Data Format
adp             ADP
ads             Sony PS2 ADS
adx             CRI ADX
aea             MD STUDIO audio
afc             AFC
aiff            Audio IFF
aix             CRI AIX
alaw            PCM A-law
alias_pix       Alias/Wavefront PIX image
alp             LEGO Racers ALP
amr             3GPP AMR
amrnb           raw AMR-NB
amrwb           raw AMR-WB
anm             Deluxe Paint Animation
apac            raw APAC
apc             CRYO APC
ape             Monkey's Audio
apm             Ubisoft Rayman 2 APM
apng            Animated Portable Network Graphics
aptx            raw aptX
aptx_hd         raw aptX HD
aqtitle         AQTitle subtitles
argo_asf        Argonaut Games ASF
argo_brp        Argonaut Games BRP
argo_cvg        Argonaut Games CVG
asf             ASF (Advanced / Active Streaming Format)
asf_o           ASF (Advanced / Active Streaming Format)
ass             SSA (SubStation Alpha) subtitle
ast             AST (Audio Stream)
au              Sun AU
av1             AV1 Annex B
avi             AVI (Audio Video Interleaved)
avr             AVR (Audio Visual Research)
avs             Argonaut Games Creature Shock
avs2            raw AVS2-P2/IEEE1857.4
avs3            raw AVS3-P2/IEEE1857.10
bethsoftvid     Bethesda Softworks VID
bfi             Brute Force & Ignorance
bfstm           BFSTM (Binary Cafe Stream)
bin             Binary text
bink            Bink
binka           Bink Audio
bit             G.729 BIT file format
bitpacked       Bitpacked
bmp_pipe        piped bmp sequence
bmv             Discworld II BMV
boa             Black Ops Audio
bonk            raw Bonk
brender_pix     BRender PIX image
brstm           BRSTM (Binary Revolution Stream)
c93             Interplay C93
caf             Apple CAF (Core Audio Format)
cavsvideo       raw Chinese AVS (Audio Video Standard)
cdg             CD Graphics
cdxl            Commodore CDXL video
cine            Phantom Cine
codec2          codec2 .c2 demuxer
codec2raw       raw codec2 demuxer
concat          Virtual concatenation script
cri_pipe        piped cri sequence
dash            Dynamic Adaptive Streaming over HTTP
data            raw data
daud            D-Cinema audio
dcstr           Sega DC STR
dds_pipe        piped dds sequence
derf            Xilam DERF
dfa             Chronomaster DFA
dfpwm           raw DFPWM1a
dhav            Video DAV
dirac           raw Dirac
dnxhd           raw DNxHD (SMPTE VC-3)
dpx_pipe        piped dpx sequence
dsf             DSD Stream File (DSF)
dshow           DirectShow capture
dsicin          Delphine Software International CIN
dss             Digital Speech Standard (DSS)
dts             raw DTS
dtshd           raw DTS-HD
dv              DV (Digital Video)
dvbsub          raw dvbsub
dvbtxt          dvbtxt
dxa             DXA
ea              Electronic Arts Multimedia
ea_cdata        Electronic Arts cdata
eac3            raw E-AC-3
epaf            Ensoniq Paris Audio File
exr_pipe        piped exr sequence
f32be           PCM 32-bit floating-point big-endian
f32le           PCM 32-bit floating-point little-endian
f64be           PCM 64-bit floating-point big-endian
f64le           PCM 64-bit floating-point little-endian
ffmetadata      FFmpeg metadata in text
film_cpk        Sega FILM / CPK
filmstrip       Adobe Filmstrip
fits            Flexible Image Transport System
flac            raw FLAC
flic            FLI/FLC/FLX animation
flv             FLV (Flash Video)
frm             Megalux Frame
fsb             FMOD Sample Bank
fwse            Capcom's MT Framework sound
g722            raw G.722
g723_1          G.723.1
g726            raw big-endian G.726 ("left aligned")
g726le          raw little-endian G.726 ("right aligned")
g729            G.729 raw format demuxer
gdigrab         GDI API Windows frame grabber
gdv             Gremlin Digital Video
gem_pipe        piped gem sequence
genh            GENeric Header
gif             CompuServe Graphics Interchange Format (GIF)
gif_pipe        piped gif sequence
gsm             raw GSM
gxf             GXF (General eXchange Format)
h261            raw H.261
h263            raw H.263
h264            raw H.264 video
hca             CRI HCA
hcom            Macintosh HCOM
hdr_pipe        piped hdr sequence
hevc            raw HEVC video
hls             Apple HTTP Live Streaming
hnm             Cryo HNM v4
ico             Microsoft Windows ICO
idcin           id Cinematic
idf             iCE Draw File
iff             IFF (Interchange File Format)
ifv             IFV CCTV DVR
ilbc            iLBC storage
image2          image2 sequence
image2pipe      piped image2 sequence
imf             IMF (Interoperable Master Format)
ingenient       raw Ingenient MJPEG
ipmovie         Interplay MVE
ipu             raw IPU Video
ircam           Berkeley/IRCAM/CARL Sound Format
iss             Funcom ISS
iv8             IndigoVision 8000 video
ivf             On2 IVF
ivr             IVR (Internet Video Recording)
j2k_pipe        piped j2k sequence
jacosub         JACOsub subtitle format
jpeg_pipe       piped jpeg sequence
jpegls_pipe     piped jpegls sequence
jpegxl_pipe     piped jpegxl sequence
jv              Bitmap Brothers JV
kux             KUX (YouKu)
kvag            Simon & Schuster Interactive VAG
laf             LAF (Limitless Audio Format)
lavfi           Libavfilter virtual input device
live_flv        live RTMP FLV (Flash Video)
lmlm4           raw lmlm4
loas            LOAS AudioSyncStream
lrc             LRC lyrics
luodat          Video CCTV DAT
lvf             LVF
lxf             VR native stream (LXF)
m4v             raw MPEG-4 video
matroska,webm   Matroska / WebM
mca             MCA Audio Format
mcc             MacCaption
mgsts           Metal Gear Solid: The Twin Snakes
microdvd        MicroDVD subtitle format
mjpeg           raw MJPEG video
mjpeg_2000      raw MJPEG 2000 video
mlp             raw MLP
mlv             Magic Lantern Video (MLV)
mm              American Laser Games MM
mmf             Yamaha SMAF
mods            MobiClip MODS
moflex          MobiClip MOFLEX
mov,mp4,m4a,3gp,3g2,mj2 QuickTime / MOV
mp3             MP2/3 (MPEG audio layer 2/3)
mpc             Musepack
mpc8            Musepack SV8
mpeg            MPEG-PS (MPEG-2 Program Stream)
mpegts          MPEG-TS (MPEG-2 Transport Stream)
mpegtsraw       raw MPEG-TS (MPEG-2 Transport Stream)
mpegvideo       raw MPEG video
mpjpeg          MIME multipart JPEG
mpl2            MPL2 subtitles
mpsub           MPlayer subtitles
msf             Sony PS3 MSF
msnwctcp        MSN TCP Webcam stream
msp             Microsoft Paint (MSP))
mtaf            Konami PS2 MTAF
mtv             MTV
mulaw           PCM mu-law
musx            Eurocom MUSX
mv              Silicon Graphics Movie
mvi             Motion Pixels MVI
mxf             MXF (Material eXchange Format)
mxg             MxPEG clip
nc              NC camera feed
nistsphere      NIST SPeech HEader REsources
nsp             Computerized Speech Lab NSP
nsv             Nullsoft Streaming Video
nut             NUT
nuv             NuppelVideo
obu             AV1 low overhead OBU
ogg             Ogg
oma             Sony OpenMG audio
paf             Amazing Studio Packed Animation File
pam_pipe        piped pam sequence
pbm_pipe        piped pbm sequence
pcx_pipe        piped pcx sequence
pfm_pipe        piped pfm sequence
pgm_pipe        piped pgm sequence
pgmyuv_pipe     piped pgmyuv sequence
pgx_pipe        piped pgx sequence
phm_pipe        piped phm sequence
photocd_pipe    piped photocd sequence
pictor_pipe     piped pictor sequence
pjs             PJS (Phoenix Japanimation Society) subtitles
pmp             Playstation Portable PMP
png_pipe        piped png sequence
pp_bnk          Pro Pinball Series Soundbank
ppm_pipe        piped ppm sequence
psd_pipe        piped psd sequence
psxstr          Sony Playstation STR
pva             TechnoTrend PVA
pvf             PVF (Portable Voice Format)
qcp             QCP
qdraw_pipe      piped qdraw sequence
qoi_pipe        piped qoi sequence
r3d             REDCODE R3D
rawvideo        raw video
realtext        RealText subtitle format
redspark        RedSpark
rka             RKA (RK Audio)
rl2             RL2
rm              RealMedia
roq             id RoQ
rpl             RPL / ARMovie
rsd             GameCube RSD
rso             Lego Mindstorms RSO
rtp             RTP input
rtsp            RTSP input
s16be           PCM signed 16-bit big-endian
s16le           PCM signed 16-bit little-endian
s24be           PCM signed 24-bit big-endian
s24le           PCM signed 24-bit little-endian
s32be           PCM signed 32-bit big-endian
s32le           PCM signed 32-bit little-endian
s337m           SMPTE 337M
s8              PCM signed 8-bit
sami            SAMI subtitle format
sap             SAP input
sbc             raw SBC (low-complexity subband codec)
sbg             SBaGen binaural beats script
scc             Scenarist Closed Captions
scd             Square Enix SCD
sdns            Xbox SDNS
sdp             SDP
sdr2            SDR2
sds             MIDI Sample Dump Standard
sdx             Sample Dump eXchange
ser             SER (Simple uncompressed video format for astronomical capturing)
sga             Digital Pictures SGA
sgi_pipe        piped sgi sequence
shn             raw Shorten
siff            Beam Software SIFF
simbiosis_imx   Simbiosis Interactive IMX
sln             Asterisk raw pcm
smjpeg          Loki SDL MJPEG
smk             Smacker
smush           LucasArts Smush
sol             Sierra SOL
sox             SoX native
spdif           IEC 61937 (compressed data in S/PDIF)
srt             SubRip subtitle
stl             Spruce subtitle format
subviewer       SubViewer subtitle format
subviewer1      SubViewer v1 subtitle format
sunrast_pipe    piped sunrast sequence
sup             raw HDMV Presentation Graphic Stream subtitles
svag            Konami PS2 SVAG
svg_pipe        piped svg sequence
svs             Square SVS
swf             SWF (ShockWave Flash)
tak             raw TAK
tedcaptions     TED Talks captions
thp             THP
tiertexseq      Tiertex Limited SEQ
tiff_pipe       piped tiff sequence
tmv             8088flex TMV
truehd          raw TrueHD
tta             TTA (True Audio)
tty             Tele-typewriter
txd             Renderware TeXture Dictionary
ty              TiVo TY Stream
u16be           PCM unsigned 16-bit big-endian
u16le           PCM unsigned 16-bit little-endian
u24be           PCM unsigned 24-bit big-endian
u24le           PCM unsigned 24-bit little-endian
u32be           PCM unsigned 32-bit big-endian
u32le           PCM unsigned 32-bit little-endian
u8              PCM unsigned 8-bit
v210            Uncompressed 4:2:2 10-bit
v210x           Uncompressed 4:2:2 10-bit
vag             Sony PS2 VAG
vbn_pipe        piped vbn sequence
vc1             raw VC-1
vc1test         VC-1 test bitstream
vfwcap          VfW video capture
vidc            PCM Archimedes VIDC
vividas         Vividas VIV
vivo            Vivo
vmd             Sierra VMD
vobsub          VobSub subtitle format
voc             Creative Voice
vpk             Sony PS2 VPK
vplayer         VPlayer subtitles
vqf             Nippon Telegraph and Telephone Corporation (NTT) TwinVQ
w64             Sony Wave64
wady            Marble WADY
wav             WAV / WAVE (Waveform Audio)
wavarc          Waveform Archiver
wc3movie        Wing Commander III movie
webm_dash_manifest WebM DASH Manifest
webp_pipe       piped webp sequence
webvtt          WebVTT subtitle
wsaud           Westwood Studios audio
wsd             Wideband Single-bit Data (WSD)
wsvqa           Westwood Studios VQA
wtv             Windows Television (WTV)
wv              WavPack
wve             Psion 3 audio
xa              Maxis XA
xbin            eXtended BINary text (XBIN)
xbm_pipe        piped xbm sequence
xmd             Konami XMD
xmv             Microsoft XMV
xpm_pipe        piped xpm sequence
xvag            Sony PS3 XVAG
xwd_pipe        piped xwd sequence
xwma            Microsoft xWMA
yop             Psygnosis YOP
yuv4mpegpipe    YUV4MPEG pipe
```

</details>

**Notes:**

- The list contains the supported formats (& not containers).
  - A video/audio format may be present in a number of containers.
  - e.g. an MP4 file generally contains H264 video stream.
- On the web, format support depends upon the web browser.
  - It happens to be extremely limited as compared to native platforms.

## Permissions

You may need to declare & request internet access or file-system permissions depending upon platform.

### Android

Edit `android/app/src/main/AndroidManifest.xml` to add the following permissions inside `<manifest>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example.app">
    <application
      ...
      />
    </application>
    <!--
      Internet access permissions.
      -->
    <uses-permission android:name="android.permission.INTERNET" />
    <!--
      Media access permissions.
      Android 13 or higher.
      https://developer.android.com/about/versions/13/behavior-changes-13#granular-media-permissions
      -->
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <!--
      Storage access permissions.
      Android 12 or lower.
      -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
</manifest>
```

Use [`package:permission_handler`](https://pub.dev/packages/permission_handler) to request access at runtime:

```dart
if (/* Android 13 or higher. */) {
  // Video permissions.
  if (await Permission.videos.isDenied || await Permission.videos.isPermanentlyDenied) {
    final state = await Permission.videos.request();
    if (!state.isGranted) {
      await SystemNavigator.pop();
    }
  }
  // Audio permissions.
  if (await Permission.audio.isDenied || await Permission.audio.isPermanentlyDenied) {
    final state = await Permission.audio.request();
    if (!state.isGranted) {
      await SystemNavigator.pop();
    }
  }
} else {
  if (await Permission.storage.isDenied || await Permission.storage.isPermanentlyDenied) {
    final state = await Permission.storage.request();
    if (!state.isGranted) {
      await SystemNavigator.pop();
    }
  }
}
```

### iOS

Edit `ios/Runner/Info-Release.plist`, `ios/Runner/Info-Profile.plist`, `ios/Runner/Info-Debug.plist`:

**Enable internet access**

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Windows

N/A

### macOS

Edit `macos/Runner/Release.entitlements` & `macos/Runner/DebugProfile.entitlements`:

**Enable internet access**

```xml
<key>com.apple.security.network.client</key>
<true/>
```

**Disable sand-box to access files**

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

### GNU/Linux

N/A

### Web

N/A

## Notes

### Android

N/A

### iOS

N/A

### Windows

N/A

### macOS

During the build phase, the following warnings are not critical and cannot be silenced:

```log
#import "Headers/media_kit_video-Swift.h"
        ^
/path/to/media_kit/media_kit_test/build/macos/Build/Products/Debug/media_kit_video/media_kit_video.framework/Headers/media_kit_video-Swift.h:270:31: warning: 'objc_ownership' only applies to Objective-C object or block pointer types; type here is 'CVPixelBufferRef' (aka 'struct __CVBuffer *')
- (CVPixelBufferRef _Nullable __unsafe_unretained)copyPixelBuffer SWIFT_WARN_UNUSED_RESULT;
```

```log
# 1 "<command line>" 1
 ^
<command line>:20:9: warning: 'POD_CONFIGURATION_DEBUG' macro redefined
#define POD_CONFIGURATION_DEBUG 1 DEBUG=1
        ^
#define POD_CONFIGURATION_DEBUG 1
        ^
```

### GNU/Linux

#### Install libmpv

System shared libraries from distribution specific user-installed packages are used by-default. **This is how GNU/Linux works.** You can install these as follows:

##### Ubuntu/Debian

```bash
sudo apt install libmpv-dev mpv
```

##### Packaging

There are other ways to bundle these within your app package e.g. within Snap or Flatpak. Few examples:

- [Celluloid](https://github.com/celluloid-player/celluloid/blob/master/flatpak/io.github.celluloid_player.Celluloid.json)
- [VidCutter](https://github.com/ozmartian/vidcutter/tree/master/_packaging)

#### Utilize [mimalloc](https://github.com/microsoft/mimalloc)

You should consider replacing the default memory allocator with [mimalloc](https://github.com/microsoft/mimalloc) for [avoiding memory leaks](https://github.com/media-kit/media-kit/issues/68).

This is as simple as [adding one line to `linux/CMakeLists.txt`](https://github.com/media-kit/media-kit/blob/d02a97ce70b316207db024401fb99e3f4509a250/media_kit_test/linux/CMakeLists.txt#L92-L94):

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE ${MIMALLOC_LIB})
```

### Web

On the web, **libmpv is not used**. Video & audio playback is handled by embedding [HTML `<video>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/video). The format support depends upon the web browser. It happens to be extremely limited as compared to native platforms.

## License

Copyright © 2021 & onwards, Hitesh Kumar Saini <<saini123hitesh@gmail.com>>

This project & the work under this repository is governed by MIT license that can be found in the [LICENSE](./LICENSE) file.
