import 'dart:developer' as developer;
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';

class FFmpegEvent {
  final String taskId;
  final FFmpegEventType type;
  final Map<String, dynamic> data;

  FFmpegEvent({required this.taskId, required this.type, this.data = const {}});

  Map<String, dynamic> toMap() => {"taskId": taskId, "type": type.index, "data": data};

  static FFmpegEvent fromMap(Map map) {
    developer.log(map.toString(), name: 'FFmpegEvent');
    return FFmpegEvent(
      taskId: map["taskId"],
      type: FFmpegEventType.values[map["type"]],
      data: Map<String, dynamic>.from(map["data"] ?? {}),
    );
  }
}
