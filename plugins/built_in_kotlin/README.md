# AGP 9 Built-in Kotlin compatibility patches

These packages are source snapshots of the listed upstream releases. Pure Live
vendors them because their Android Gradle scripts still apply the standalone
Kotlin Gradle Plugin, which conflicts with AGP 9 Built-in Kotlin.

| Package | Upstream release | Upstream repository |
| --- | --- | --- |
| `better_player_plus` | 1.3.5 | <https://github.com/SunnatilloShavkatov/betterplayer> |
| `floating` | 6.0.0 | <https://github.com/wrbl606/floating> |
| `flutter_exit_app` | 2.1.2 | <https://github.com/xang555/flutter_exit_app> |
| `flutter_js` | 0.8.7 | <https://github.com/abner/flutter_js> |
| `mobile_scanner` | 7.4.0 | <https://github.com/juliansteenbakker/mobile_scanner> |
| `share_handler_android` | 0.0.11 | <https://github.com/AboutShout/share_handler> |

The patch only modernizes Android build integration:

- removes `kotlin-android`/`org.jetbrains.kotlin.android` and KGP classpaths;
- lets AGP provide Kotlin compilation and the Kotlin standard library;
- uses Java 17 bytecode targets where the upstream plugin used Java 8;
- raises the declared Flutter compatibility floor to 3.44, matching Flutter's
  Built-in Kotlin migration boundary.

Original licenses, source metadata and changelogs are preserved in each package.
When an upstream release gains AGP 9 Built-in Kotlin support, replace its path
dependency with the hosted release and remove the corresponding snapshot.
