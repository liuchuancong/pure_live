package:media_kit bundles package:ffi v1.2.1 for internal native interop.

This has been done to improve stability & performance on Microsoft Windows.
PR: https://github.com/dart-lang/ffi/pull/144 seems to make some changes to how memory is allocated by FFI on Microsoft Windows.
Even though it works fine in most cases, there are certain situations where notable differences in stability or performance are observed (crash or slow processing).

I don't have much knowledge of Microsoft Windows's internals. However, it seems that memory allocated by new implementation has some sort of incompatibility with MinGW compiled libmpv.

