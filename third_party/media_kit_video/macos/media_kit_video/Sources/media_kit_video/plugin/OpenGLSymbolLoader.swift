import Darwin

enum OpenGLSymbolLoader {
  private static let frameworkPath =
    "/System/Library/Frameworks/OpenGL.framework/OpenGL"

  // Keep the framework loaded for the lifetime of the process. mpv may invoke
  // the callback from its render worker at any point while the context exists.
  private static let frameworkHandle = dlopen(
    frameworkPath,
    RTLD_LAZY | RTLD_LOCAL
  )

  static func load(
    _ name: UnsafePointer<CChar>?
  ) -> UnsafeMutableRawPointer? {
    guard let frameworkHandle, let name else {
      return nil
    }

    return dlsym(frameworkHandle, name)
  }
}
