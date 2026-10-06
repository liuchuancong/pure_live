# AGP 9 Built-in Kotlin compatibility patches

These packages are source snapshots of the listed upstream releases. Pure Live
vendors them because their Android Gradle scripts still apply the standalone
Kotlin Gradle Plugin, which conflicts with AGP 9 Built-in Kotlin.

| Package | Upstream release | Upstream repository |
| --- | --- | --- |
| `flutter_exit_app` | 2.1.2 | <https://github.com/xang555/flutter_exit_app> |
| `flutter_inappwebview_android` | 1.2.0-beta.3 | <https://github.com/pichillilorenzo/flutter_inappwebview> |
| `flutter_js` | 0.8.7 | <https://github.com/abner/flutter_js> |
| `mobile_scanner` | 7.4.0 | <https://github.com/juliansteenbakker/mobile_scanner> |
| `share_handler_android` | 0.0.11 | <https://github.com/AboutShout/share_handler> |

The baseline patches modernize Android build integration:

- removes `kotlin-android`/`org.jetbrains.kotlin.android` and KGP classpaths;
- lets AGP provide Kotlin compilation and the Kotlin standard library;
- uses Java 17 bytecode targets where the upstream plugin used Java 8;
- raises the declared Flutter compatibility floor to 3.44, matching Flutter's
  Built-in Kotlin migration boundary.

Original licenses, source metadata and changelogs are preserved in each package.
When an upstream release gains AGP 9 Built-in Kotlin support, replace its path
dependency with the hosted release only after reviewing local runtime changes,
then remove the corresponding snapshot.

The Android picture-in-picture backend is not here: `floating` is snapshotted in
the media_core workspace (`packages/floating`), because `media_core_pip` is what
depends on it. Its build and status-observation changes are listed in
`packages/floating/PATCHES.md` there; `docs/PIP_STATUS_OBSERVATION_AUDIT_2026_09_06.md`
records how that behaviour was reached.
