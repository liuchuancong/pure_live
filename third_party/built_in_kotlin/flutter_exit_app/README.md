# flutter_exit_app

A Flutter plugin that provides a platform-specific way to exit your application without calling `exit(0)` in Dart code.

## Features

- **Android**: Cleanly finishes the activity and removes it from the task list
- **iOS**: Suspends the application (Apple guideline compliant) with optional force-exit
- **Modern implementation**: Written in Kotlin (Android) and Swift (iOS)
- **Type-safe**: Full null-safety support
- **Well-tested**: Comprehensive unit tests

## Platform Support

| Platform | Minimum Version |
|----------|----------------|
| Android  | API 21 (Android 5.0) |
| iOS      | 12.0 |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_exit_app: ^2.1.1
```

Then run:

```bash
flutter pub get
```

## Usage

### Import the package

```dart
import 'package:flutter_exit_app/flutter_exit_app.dart';
```

### Basic exit (recommended)

```dart
// Exit the app using platform-specific methods
// iOS: Suspends the app (Apple guideline compliant)
// Android: Finishes activity and exits
await FlutterExitApp.exitApp();
```

### Force exit on iOS (not recommended)

```dart
// Force-kill the iOS app process (against Apple guidelines)
// Only use when absolutely necessary
await FlutterExitApp.exitApp(iosForceExit: true);
```

### Complete example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';

class ExitButton extends StatelessWidget {
  const ExitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Show confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          await FlutterExitApp.exitApp();
        }
      },
      child: const Text('Exit App'),
    );
  }
}
```

## Important Notes

### iOS Guidelines

Apple's Human Interface Guidelines discourage apps from programmatically exiting. The plugin provides two modes:

**Default mode** (`iosForceExit: false`):
- Animates the app to background with a smooth fade-out effect
- Suspends the app gracefully
- App remains in memory until iOS decides to terminate it
- **Recommended**: This is the Apple-approved approach

**Force exit mode** (`iosForceExit: true`):
- Animates the app with fade-out and scale-down effect
- Forcibly terminates the process after animation
- **Warning**: The app will appear to "crash" to users
- May be rejected during App Store review
- Only use if you have a specific requirement (e.g., enterprise apps)

### Android Behavior

On Android, the plugin finishes the current activity and removes it from the recent tasks list, then exits the process after a 1-second delay to ensure clean shutdown. The app is completely removed from the task manager.


## License

See the [LICENSE](LICENSE) file for details.
