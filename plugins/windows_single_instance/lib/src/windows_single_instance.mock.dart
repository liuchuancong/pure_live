class WindowsSingleInstance {
  WindowsSingleInstance._();

  static Future ensureSingleInstance(
    List<String> arguments,
    String pipeName, {
    Function(List<String>)? onSecondWindow,
    bool bringWindowToFront = true,
    Future<void> Function()? exitFunction,
  }) async {
    throw UnimplementedError("windows_single_instance not supported on this platform");
  }
}
