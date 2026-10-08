import 'dart:ffi';

import 'jsc_ffi.dart';

final void Function(Pointer ctx, bool inspectable)
    jSGlobalContextSetInspectable = JscFfi.lib
        .lookup<NativeFunction<Void Function(Pointer, Bool)>>(
            'JSGlobalContextSetInspectable')
        .asFunction();
