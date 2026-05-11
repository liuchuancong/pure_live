import 'dart:io';

class FFmpegWorker {
  static Future<Process> run(List<String> command) async {
    return await Process.start(command.first, command.sublist(1), mode: ProcessStartMode.normal);
  }
}
