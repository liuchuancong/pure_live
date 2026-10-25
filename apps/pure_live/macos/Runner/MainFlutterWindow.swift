import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The room windows: every engine desktop_multi_window creates runs its
    // own isolate, and without this hook it comes up without any plugins —
    // no player, no window management, nothing. The same hook arms the
    // runner channel a room window drives its own window through: the
    // window plugins resolve the current window from the application's key
    // window, which in a multi-window process may belong to a different
    // room, so a room window cannot close or retitle itself through them.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)

      let registrar = controller.registrar(forPlugin: "PureLiveRoomWindow")
      let channel = FlutterMethodChannel(
        name: "pure_live/room_window", binaryMessenger: registrar.messenger)
      // Weak on purpose: the handler outlives the window otherwise, and a
      // closed room window's engine would never come down.
      channel.setMethodCallHandler { [weak controller] call, result in
        guard let controller else {
          result(FlutterError(code: "-1", message: "room window is gone", details: nil))
          return
        }
        switch call.method {
        case "hwnd":
          // A macOS window has no HWND; the room window never calls this.
          result(nil)
        case "close":
          // The window's own release chain brings the engine down with it.
          controller.view.window?.close()
          result(true)
        case "title":
          if let title = call.arguments as? String {
            controller.view.window?.title = title
          }
          result(true)
        case "chrome":
          guard let window = controller.view.window else {
            result(FlutterError(code: "-1", message: "window is gone", details: nil))
            return
          }
          let custom = call.arguments as? Bool ?? false
          window.titleVisibility = custom ? .hidden : .visible
          window.titlebarAppearsTransparent = custom
          window.isMovableByWindowBackground = false
          if custom {
            window.styleMask.insert(.fullSizeContentView)
          } else {
            window.styleMask.remove(.fullSizeContentView)
          }
          result(true)
        case "startDragging":
          if let window = controller.view.window, let event = NSApp.currentEvent {
            if #available(macOS 11.0, *) {
              window.performWindowDrag(with: event)
            }
          }
          result(true)
        case "minimize":
          controller.view.window?.miniaturize(nil)
          result(true)
        case "maximize":
          if let window = controller.view.window, !window.isZoomed {
            window.zoom(nil)
          }
          result(true)
        case "restore":
          if let window = controller.view.window {
            if window.isZoomed {
              window.zoom(nil)
            } else {
              window.deminiaturize(nil)
            }
          }
          result(true)
        case "isMaximized":
          result(controller.view.window?.isZoomed ?? false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.awakeFromNib()
  }
}
