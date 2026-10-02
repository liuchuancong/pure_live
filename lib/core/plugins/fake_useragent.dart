import 'dart:math';

class FakeUserAgent {
  static Map get userAgent => getRandomUserAgent();
  static Map getRandomUserAgent() {
    // 获取随机的设备信息
    final macOSDevicesVersion = macOSDevicesVersions[Random().nextInt(macOSDevicesVersions.length)];
    // 获取随机的浏览器版本
    final chromeVersion = chromeVersions[Random().nextInt(chromeVersions.length)];
    final sarariVersion = sarariVersions[Random().nextInt(sarariVersions.length)];
    final edgeVersion = edgeVersions[Random().nextInt(edgeVersions.length)];
    String generateMacChromeUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X ${macOSDevicesVersion.replaceAll(RegExp(r'.'), '-')}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36';
    String generateMacSafariUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X ${macOSDevicesVersion.replaceAll(RegExp(r'.'), '-')}) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$sarariVersion Safari/605.1.15';
    String generateWindowsChromeUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36';
    String generateWindowsEdgeUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36 Edg/$edgeVersion';
    String generateLinuxChromeUa =
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36';
    List<Map> userAgents = [];
    userAgents.add({
      "userAgent": generateMacChromeUa,
      "device": "macOS",
      "browser": "Chrome",
      "version": chromeVersion,
      "v": chromeVersion.split('.')[0]
    });
    userAgents.add({
      "userAgent": generateMacSafariUa,
      "device": "macOS",
      "browser": "Safari",
      "version": sarariVersion,
      "v": sarariVersion.split('.')[0]
    });
    userAgents.add({
      "userAgent": generateWindowsChromeUa,
      "device": "Windows",
      "browser": "Chrome",
      "version": chromeVersion,
      "v": chromeVersion.split('.')[0]
    });
    userAgents.add({
      "userAgent": generateWindowsEdgeUa,
      "device": "Windows",
      "browser": "Edge",
      "version": edgeVersion,
      "v": edgeVersion.split('.')[0]
    });
    userAgents.add({
      "userAgent": generateLinuxChromeUa,
      "device": "Linux",
      "browser": "Chrome",
      "version": chromeVersion,
      "v": chromeVersion.split('.')[0]
    });

    return userAgents[Random().nextInt(userAgents.length)];
  }

  static List<String> chromeVersions = [
    "88.0.4324",
    "89.0.4389",
    "90.0.4430",
    "91.0.4472",
    "92.0.4515",
    "93.0.4577",
    "94.0.4606",
    "95.0.4638",
    "96.0.4664",
    "97.0.4692",
    "98.0.4758",
    "99.0.4844",
    "100.0.4896",
    "101.0.4951",
    "102.0.5005",
    "103.0.5060",
    "104.0.5112",
    "105.0.5195",
    "106.0.5249",
    "107.0.5304",
    "108.0.5359",
    "109.0.5414",
    "110.0.5481"
  ];

  static List<String> sarariVersions = [
    "88.0.4324",
    "89.0.4389",
    "90.0.4430",
    "91.0.4472",
    "92.0.4515",
    "93.0.4577",
    "94.0.4606",
    "95.0.4638",
    "96.0.4664",
    "97.0.4692",
    "98.0.4758",
    "99.0.4844",
    "100.0.4896",
    "101.0.4951",
    "102.0.5005",
    "103.0.5060",
    "104.0.5112",
    "105.0.5195",
    "106.0.5249",
    "107.0.5304",
    "108.0.5359",
    "109.0.5414",
    "110.0.5481"
  ];

  static List<String> edgeVersions = [
    "106.0.1370.52",
    "106.0.1370.47",
    "105.0.1343.50",
    "105.0.1343.48",
    "105.0.1343.34",
    "105.0.1343.27",
    "104.0.1293.70",
    "104.0.1293.63",
    "104.0.1293.60",
    "104.0.1293.55",
    "104.0.1293.47",
    "103.0.1264.77",
    "103.0.1264.71",
    "103.0.1264.62",
    "103.0.1264.51",
    "102.0.1245.44",
    "102.0.1245.39",
    "101.0.1210.53",
    "101.0.1210.47",
    "101.0.1210.39",
    "100.0.1185.50",
    "100.0.1185.43",
    "100.0.1185.36",
    "99.0.1150.55",
    "99.0.1150.46",
    "99.0.1150.39",
    "99.0.1150.30",
    "98.0.1108.62",
    "98.0.1108.55",
    "97.0.1072.78",
    "97.0.1072.69",
    "97.0.1072.55",
    "96.0.1054.62",
    "96.0.1054.36",
    "95.0.1020.32"
  ];

  static List<String> macOSDevicesVersions = ["13.1", "12.6.2", "11.7.2", "10.15.7", "10.14.6", "10.13.6"];
}
