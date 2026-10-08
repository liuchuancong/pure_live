// Module: lib/src/models/extension/extension_type.dart
// Purpose: The extension-kind vocabulary shared by extension and runtime models.
// Author: liuchuancong
// Created: 2026-10-08
//
// It lives in its own file because RuntimeDescriptor classifies which kinds it can host, so the enum
// must not sit behind the extension model that depends on the runtime model.

/// How the platform acquired the thing it is loading.
enum ExtensionType { builtin, plugin, external }
