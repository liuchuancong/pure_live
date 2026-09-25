# Native player lifetime

mpv must not retain an executable callback owned by a Dart isolate. An engine
may destroy that isolate without running `Player.dispose`, leaving a callable
address unmapped while the mpv core and FFmpeg logging threads are still alive.

`NativeEventLoop` owns one handle, receive port, event consumer and native owner.
The wakeup function is ordinary C code in `libmedia_kit_event_loop`; it posts a
scalar notification with `NativeApi.postCObject`. No `NativeCallable` or Dart
function pointer is registered with mpv. Instances are independent of handle
address reuse, and have no static callback registry.

## Explicit disposal

1. Mark the event loop closing and unregister the native wakeup function.
   `mpv_set_wakeup_callback(NULL)` synchronizes with mpv's wakeup lock, so any
   callback already executing has returned before this step completes.
2. Wait for the current asynchronous event consumer. mpv's event buffer cannot
   be reused or freed while this consumer still borrows it.
3. Signal the native cleanup worker to call `mpv_terminate_destroy`.
4. Wait for its completion message, detach the native finalizer, release the
   owner and close the port. Repeated disposal returns the same future.

The player releases its video render context before this native teardown.
Outstanding command requests are rejected and allocations are freed on error.
Failed initialization also releases acquired resources.

## Isolate shutdown

`NativeFinalizer` calls a C function that first disables all VM posts, then
unregisters wakeups and signals the same cleanup worker. It invokes no Dart API.
The worker is allocated when the handle is created, so finalization does not
need to allocate a thread. Reference counting covers both the finalizer owner
and the worker, including shutdown halfway through explicit disposal.

The post mutex is never held while taking mpv's wakeup lock. This prevents lock
inversion with mpv invoking the wakeup function while holding its own lock.

Native cleanup does not require a live Dart isolate, a future, a timer, a method
channel, or a particular Activity/AudioService destruction order. Abrupt process
termination is different: the OS reclaims the process and no subsequent engine
in that process can call its old callbacks.

The receive port preserves the creator's Zone. A handler must not await disposal
of its own event loop; that would wait for itself. Explicit disposal waits for
an asynchronous handler instead of freeing its borrowed memory on a timeout.

## Screenshot ownership

A screenshot worker no longer receives a raw mpv handle. The owning isolate
requests a frame asynchronously and copies its pixels while handling the mpv
command reply, before the event buffer is reused. Only Dart-owned
pixels go to the encoding isolate. Both raw screenshot APIs now return owned
bytes. Capture does not block the Dart event consumer, and JPEG/PNG encoding
remains off the caller isolate. This avoids a worker starting FFI after its owner
was destroyed.

## Building and validation

The bridge uses Dart build hooks / code assets and requires Dart >= 3.10 plus a
native compiler. This is an intentional change to the package's SDK requirement.
The hook takes Dart C headers from the executing SDK and passes libmpv function
pointers at runtime, so libmpv and FFmpeg do not need to be rebuilt.

Validated here: Windows Flutter tests and Android arm64 release packaging, plus
a standalone native stress test on Android. iOS/macOS/Linux builds have not been
run. The upstream `code_assets` toolchain does not define an OHOS target; this
build-hook integration **requires an OHOS toolchain adaptation before an OHOS
release**. Do not treat the Android validation as full-platform release approval.

The build hook now supplies libmpv automatically. Run from `media_kit`:

```sh
flutter test test/src/player/native/core/native_event_loop_test.dart test/src/player/native/core/native_player_lifecycle_test.dart
```

The independent test package builds an ABI fixture; its video-binding test also
uses the automatically bundled real libmpv:

```sh
cd tool/lifecycle_test
flutter pub get
flutter test
```

It builds a controllable mpv ABI fixture, tests borrowed event-buffer lifetime,
initialization failure, delayed native teardown, and kills/recreates 150 isolates
with callbacks active, disposal pending, or an event handler suspended. It checks
native destruction counts and callback unregistration rather than merely checking
that Dart futures complete.

`tool/lifecycle_test/src/native_lifecycle_test.c` additionally links the production
bridge and fixture into a standalone POSIX/Android executable. Compile it with
`src/native_event_loop.c`, `tool/lifecycle_test/src/fake_mpv.c`, the SDK's `include`
directory, `-pthread`, and `-ldl`. It checks 600 normal/finalizer/interrupted-dispose
lifetimes without installing an APK.

The contract follows the [Dart NativeFinalizer documentation](https://api.dart.dev/dart-ffi/NativeFinalizer-class.html)
and [native callback restrictions](https://api.dart.dev/dart-ffi/NativeFinalizer/NativeFinalizer.html).
