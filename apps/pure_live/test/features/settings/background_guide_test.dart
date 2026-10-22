import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/settings/video/background_guide.dart';

/// The guide's vendor knowledge, without a phone: what the build says, and
/// which switches that leaves to check.

void main() {
  group('romFamilyOf', () {
    test('names the vendor behind the manufacturer and the brand', () {
      expect(romFamilyOf('Xiaomi'), RomFamily.xiaomi);
      expect(romFamilyOf('', 'Redmi'), RomFamily.xiaomi);
      expect(romFamilyOf('OnePlus'), RomFamily.oppo);
      expect(romFamilyOf('realme'), RomFamily.oppo);
      expect(romFamilyOf('vivo'), RomFamily.vivo);
      expect(romFamilyOf('HONOR'), RomFamily.honor);
      expect(romFamilyOf('Google'), RomFamily.other);
    });
  });

  group('detectRom', () {
    test('HyperOS and MIUI versions read the way the systems name them', () {
      final hyper = detectRom(
        manufacturer: 'Xiaomi',
        model: '23127PN0CC',
        sdk: 34,
        props: const {'ro.mi.os.version.name': 'OS2.0.1.0.UMBCNXM'},
      );
      expect(hyper.romName, 'HyperOS');
      expect(hyper.romVersion, '2.0.1.0.UMBCNXM');
      expect(hyper.romLabel, 'HyperOS 2.0.1.0.UMBCNXM');
      expect(hyper.androidVersion, '14');

      final miui = detectRom(manufacturer: 'Redmi', props: const {'ro.miui.ui.version.name': 'V140'});
      expect(miui.romName, 'MIUI');
      expect(miui.romVersion, '14');
    });

    test('realme UI and OxygenOS are told apart from ColorOS', () {
      final realme = detectRom(manufacturer: 'realme', props: const {'ro.build.version.realmeui': 'V5.0'});
      expect(realme.romName, 'realme UI');
      expect(realme.romVersion, '5.0');

      final oneplus = detectRom(
        manufacturer: 'OnePlus',
        props: const {'ro.oxygen.version': '14.0.0', 'ro.build.version.oplusrom': 'V14.0.0'},
      );
      expect(oneplus.romName, 'OxygenOS');
      expect(oneplus.romVersion, '14.0.0');

      final oppo = detectRom(manufacturer: 'OPPO', props: const {'ro.build.version.opporom': 'V13.1'});
      expect(oppo.romName, 'ColorOS');
      expect(oppo.romVersion, '13.1');
    });

    test('OriginOS and Funtouch OS take their name from the property', () {
      final origin = detectRom(
        manufacturer: 'vivo',
        props: const {'ro.vivo.os.name': 'OriginOS', 'ro.vivo.os.version': '4.0'},
      );
      expect(origin.romName, 'OriginOS');
      expect(origin.romVersion, '4.0');

      final funtouch = detectRom(manufacturer: 'vivo', props: const {'ro.vivo.os.name': 'Funtouch OS'});
      expect(funtouch.romName, 'Funtouch OS');
    });

    test('HarmonyOS, MagicOS and One UI read their own properties', () {
      final harmony = detectRom(manufacturer: 'HUAWEI', props: const {'hw_sc.build.platform.version': '4.2.0'});
      expect(harmony.romName, 'HarmonyOS');
      expect(harmony.romVersion, '4.2.0');

      final magic = detectRom(manufacturer: 'HONOR', props: const {'ro.build.version.magic': 'MagicOS_8.0'});
      expect(magic.romName, 'MagicOS');
      expect(magic.romVersion, '8.0');

      final samsung = detectRom(manufacturer: 'samsung', props: const {'ro.build.version.oneui': '60100'});
      expect(samsung.romName, 'One UI');
      expect(samsung.romVersion, '6.1');
    });

    test('a phone with no vendor property still says its family', () {
      final pixel = detectRom(manufacturer: 'Google', model: 'Pixel 9');
      expect(pixel.family, RomFamily.other);
      expect(pixel.romName, '');
      expect(pixel.romLabel, 'Google');
      expect(pixel.androidVersion, '');
    });
  });

  group('BackgroundStatus.fromMap', () {
    test('missing values read as fine', () {
      final status = BackgroundStatus.fromMap(const {});
      expect(status.notifications, isTrue);
      expect(status.batteryUnrestricted, isTrue);
      expect(status.backgroundRestricted, isFalse);
      expect(status.dataSaver, DataSaver.off);
      expect(status.powerSave, isFalse);
      expect(status.rom.family, RomFamily.other);
    });

    test('reads the states the native side reports', () {
      final status = BackgroundStatus.fromMap(const {
        'manufacturer': 'Xiaomi',
        'model': '23127PN0CC',
        'sdk': 34,
        'props': {'ro.mi.os.version.name': 'OS2.0'},
        'notifications': false,
        'batteryUnrestricted': false,
        'backgroundRestricted': true,
        'dataSaver': 'restricted',
        'powerSave': true,
      });
      expect(status.rom.romLabel, 'HyperOS 2.0');
      expect(status.notifications, isFalse);
      expect(status.batteryUnrestricted, isFalse);
      expect(status.backgroundRestricted, isTrue);
      expect(status.dataSaver, DataSaver.restricted);
      expect(status.powerSave, isTrue);
    });
  });

  group('guideSteps', () {
    const rom = RomInfo(family: RomFamily.other, manufacturer: 'Google');

    test('a healthy phone has no readable step in the way', () {
      final steps = guideSteps(const BackgroundStatus(rom: rom));
      expect([for (final step in steps) step.id], [GuideStepId.notifications, GuideStepId.battery]);
      expect(pendingSteps(steps), 0);
    });

    test('notifications and the battery exemption are the readable todos', () {
      final steps = guideSteps(
        const BackgroundStatus(
          rom: rom,
          notifications: false,
          batteryUnrestricted: false,
          dataSaver: DataSaver.restricted,
        ),
      );
      expect(pendingSteps(steps), 3);
      expect(steps.map((step) => step.id), contains(GuideStepId.dataSaver));
    });

    test('the background restriction and data saver appear only when set', () {
      final restricted = guideSteps(
        const BackgroundStatus(rom: rom, backgroundRestricted: true, dataSaver: DataSaver.restricted),
      );
      expect(restricted.map((step) => step.id), containsAll([GuideStepId.restricted, GuideStepId.dataSaver]));
    });

    test('a vendor adds the switches only it can read', () {
      final xi = guideSteps(
        const BackgroundStatus(
          rom: RomInfo(family: RomFamily.xiaomi, manufacturer: 'Xiaomi'),
        ),
      );
      expect(
        xi.map((step) => step.id),
        containsAll([GuideStepId.xiaomiAutostart, GuideStepId.xiaomiBattery, GuideStepId.lockRecents]),
      );
      expect(xi.where((step) => step.check == GuideCheck.manual), hasLength(3));
    });

    test('every vendored step ends at the app details page', () {
      for (final family in RomFamily.values) {
        for (final step in vendorSteps(family)) {
          if (step.pages.isNotEmpty) {
            expect(step.pages.last.action, SystemPage.appDetails.action, reason: '${family.name}/${step.id.name}');
          }
        }
      }
    });

    test('locking in recents opens nothing: the step only says how', () {
      final lock = vendorSteps(RomFamily.xiaomi).firstWhere((step) => step.id == GuideStepId.lockRecents);
      expect(lock.action, GuideAction.none);
      expect(lock.pages, isEmpty);
    });
  });
}
