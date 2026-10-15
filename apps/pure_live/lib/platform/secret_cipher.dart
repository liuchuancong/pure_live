import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:live_storage/live_storage.dart';

/// The device's [SecretCipher]: the Android Keystore or Windows DPAPI.
SecretCipher platformSecretCipher() {
  if (Platform.isAndroid) return AndroidKeystoreCipher();
  if (Platform.isWindows) return WindowsDpapiCipher();
  throw UnsupportedError('No secret store on ${Platform.operatingSystem}');
}

/// AES-256-GCM under a non-exportable Android Keystore key
/// (`MainActivity.kt`, channel `pure_live/secret_cipher`); the secret's
/// name is the associated data.
final class AndroidKeystoreCipher implements SecretCipher {
  /// Creates the cipher over [channel].
  new({this.channel = const MethodChannel('pure_live/secret_cipher')});

  /// The native channel.
  final MethodChannel channel;

  @override
  Future<Uint8List> seal(String ref, String plain) async {
    final sealed = await channel.invokeMethod<Uint8List>('seal', {'ref': ref, 'plain': plain});
    if (sealed == null) throw StateError('Keystore returned nothing');
    return sealed;
  }

  @override
  Future<String> open(String ref, Uint8List sealed) async {
    final plain = await channel.invokeMethod<String>('open', {'ref': ref, 'sealed': sealed});
    if (plain == null) throw StateError('Keystore returned nothing');
    return plain;
  }
}

/// Windows DPAPI (`CryptProtectData`, current user): only this Windows
/// account can open the values; the secret's name is the entropy, so a
/// value cannot be moved to another name.
final class WindowsDpapiCipher implements SecretCipher {
  @override
  Future<Uint8List> seal(String ref, String plain) async =>
      _dpapi(Uint8List.fromList(utf8.encode(plain)), ref, protect: true);

  @override
  Future<String> open(String ref, Uint8List sealed) async => utf8.decode(_dpapi(sealed, ref, protect: false));
}

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _CryptNative =
    Int32 Function(
      Pointer<_DataBlob> dataIn,
      Pointer<Utf16> description,
      Pointer<_DataBlob> entropy,
      Pointer<Void> reserved,
      Pointer<Void> prompt,
      Uint32 flags,
      Pointer<_DataBlob> dataOut,
    );
typedef _CryptDart =
    int Function(
      Pointer<_DataBlob> dataIn,
      Pointer<Utf16> description,
      Pointer<_DataBlob> entropy,
      Pointer<Void> reserved,
      Pointer<Void> prompt,
      int flags,
      Pointer<_DataBlob> dataOut,
    );

// CRYPTPROTECT_UI_FORBIDDEN: never show a prompt.
const int _uiForbidden = 0x1;

Uint8List _dpapi(Uint8List input, String ref, {required bool protect}) {
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final call = crypt32.lookupFunction<_CryptNative, _CryptDart>(protect ? 'CryptProtectData' : 'CryptUnprotectData');
  final localFree = kernel32
      .lookupFunction<Pointer<Void> Function(Pointer<Void>), Pointer<Void> Function(Pointer<Void>)>('LocalFree');
  final entropyBytes = utf8.encode(ref);
  return using((arena) {
    Pointer<_DataBlob> blob(List<int> bytes) {
      final data = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
      data.asTypedList(bytes.length).setAll(0, bytes);
      return arena<_DataBlob>()
        ..ref.cbData = bytes.length
        ..ref.pbData = data;
    }

    final output = arena<_DataBlob>();
    final ok = call(blob(input), nullptr, blob(entropyBytes), nullptr, nullptr, _uiForbidden, output);
    if (ok == 0) throw StateError('DPAPI ${protect ? 'protect' : 'unprotect'} failed');
    try {
      return Uint8List.fromList(output.ref.pbData.asTypedList(output.ref.cbData));
    } finally {
      localFree(output.ref.pbData.cast());
    }
  });
}
