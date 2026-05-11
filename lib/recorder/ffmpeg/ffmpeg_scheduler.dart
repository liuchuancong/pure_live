import 'dart:collection';

class FFmpegScheduler {
  static final FFmpegScheduler instance = FFmpegScheduler._();

  FFmpegScheduler._();

  final Queue<_Task> _queue = Queue();
  final Set<String> _running = {};

  int maxConcurrent = 2;

  void add(String taskId, Future<void> Function() runner) {
    _queue.add(_Task(taskId, runner));
    _next();
  }

  void remove(String taskId) {
    _running.remove(taskId);
  }

  void _next() async {
    if (_queue.isEmpty) return;
    if (_running.length >= maxConcurrent) return;

    final task = _queue.removeFirst();
    _running.add(task.taskId);

    await task.runner();

    _running.remove(task.taskId);
    _next();
  }
}

class _Task {
  final String taskId;
  final Future<void> Function() runner;

  _Task(this.taskId, this.runner);
}
