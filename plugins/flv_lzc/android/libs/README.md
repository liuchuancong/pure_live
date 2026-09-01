# fplayer-core 1.0.4 — Pure Live arm64 16KB build

Pure Live keeps this AAR locally because the published Maven Central artifact
`io.github.flutterplayer:fplayer-core:1.0.4` contains three arm64 ELF files whose
LOAD segments are aligned to `0x1000`. Android devices using a 16KB page size
require at least `0x4000` alignment.

## Provenance

- Upstream source: <https://github.com/FlutterPlayer/ijkplayer>
- Exact tag: `1.0.4`
- Exact commit: `a085295480fdbad13187c9ad953f6144ded2b21e`
- Original Maven AAR SHA-256: `9E19876D4CA26CA701848EB48B802A80AEC0F285C76A63C2B3EC5A14D9C6B6DD`
- Repacked AAR SHA-256: `3643B36BC906F1FED56B313AC98669EEAA9DA0D2262409808429C5B614C676DA`
- License/notice: `COPYING.LGPLv2.1` and `NOTICE` in this directory

The Java bytecode, Android manifest, ProGuard rules, metadata and every
non-arm64 entry are byte-for-byte identical to the published AAR. Only these
files were replaced:

| Entry | SHA-256 | Minimum LOAD alignment |
|---|---|---:|
| `jni/arm64-v8a/libijkffmpeg.so` | `0EBBE8AE0C0DCF4909A5279C17DEC3C9CA1CAB76F698EFBB77E8D61272415575` | `0x4000` |
| `jni/arm64-v8a/libijkplayer.so` | `1604B15E1D72907E3CF3E6B885D2028CEB609A3C2E0FE0C0D4CD5113D7BE89DA` | `0x4000` |
| `jni/arm64-v8a/libijksdl.so` | `AFE6E22C130D6E4FC254617B293B03A73724A740B8394C3E3CEBA8F2303E4C62` | `0x4000` |

## Build contract

- FFmpeg uses the tag's `config/module.sh` preset, including
  `--disable-gpl` and `--disable-nonfree`; AArch64 assembly remains enabled.
- FFmpeg was compiled with Android NDK `26.2.11394342` and linked with
  `-Wl,-Bsymbolic -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384`.
- `libijkplayer.so` and `libijksdl.so` were compiled with Android NDK
  `29.0.14206865` and the same 16KB linker page-size contract.
- `fplayer-core-1.0.4-purelive-16kb.patch` records the two build-system-only
  changes used on the exact source tag: portable CMake file copying and keeping
  SDL's legacy `-Werror` flag private instead of leaking it into dependants.
- Dynamic symbol comparison against the Maven arm64 binaries reports zero
  missing public `Java_*`, `ijk*`, `av*`, `sws_*`, `swr_*`, `avio_*`, `url_*`
  or `ff_*` exports. The only absent names are linker boundary/runtime internals.

## Verification

From the repository root:

```powershell
.\tool\verify_android_elf_alignment.ps1 `
  -InputPath .\plugins\flv_lzc\android\libs\io/github/flutterplayer/fplayer-core/1.0.4-purelive16k/fplayer-core-1.0.4-purelive16k.aar
.\tool\validate_build_policy.ps1
```

The Android APK release gate separately checks ZIP alignment with
`zipalign -c -P 16 4` and checks every packaged arm64 ELF LOAD segment.
