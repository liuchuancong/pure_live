import 'dart:async';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/cookie_sanitizer.dart';
import 'package:pure_live/domains/account/data/bilibili_account_service.dart';

enum QRStatus { loading, unscanned, scanned, verifying, verified, expired, failed }

class BilibiliQrCode {
  const BilibiliQrCode({required this.key, required this.url});

  final String key;
  final String url;

  bool get isValid {
    final parsed = Uri.tryParse(url);
    return key.trim().isNotEmpty && parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty;
  }
}

class BilibiliQrPollResult {
  const BilibiliQrPollResult({required this.apiCode, required this.statusCode, this.cookies = const []});

  final int apiCode;
  final int statusCode;
  final List<String> cookies;
}

typedef BilibiliQrCodeLoader = Future<BilibiliQrCode?> Function();
typedef BilibiliQrPoller = Future<BilibiliQrPollResult> Function(String key);
typedef BilibiliQrCookieVerifier = Future<bool> Function(String cookie);
typedef BilibiliLoginCompletion = void Function();

class BiliBiliQRLoginController extends GetxController {
  BiliBiliQRLoginController({
    BilibiliQrCodeLoader? qrCodeLoader,
    BilibiliQrPoller? qrPoller,
    BilibiliQrCookieVerifier? cookieVerifier,
    BilibiliLoginCompletion? completeLogin,
    AccountNotice? notice,
    this.pollInterval = const Duration(seconds: 3),
    this.maxConsecutivePollFailures = 3,
  }) : assert(maxConsecutivePollFailures > 0),
       _qrCodeLoader = qrCodeLoader ?? _loadQrCode,
       _qrPoller = qrPoller ?? _pollQrCode,
       _cookieVerifier = cookieVerifier ?? _verifyCookie,
       _completeLogin = completeLogin ?? _finishLogin,
       _notice = notice ?? _showNotice;

  final BilibiliQrCodeLoader _qrCodeLoader;
  final BilibiliQrPoller _qrPoller;
  final BilibiliQrCookieVerifier _cookieVerifier;
  final BilibiliLoginCompletion _completeLogin;
  final AccountNotice _notice;
  final Duration pollInterval;
  final int maxConsecutivePollFailures;

  final qrcodeUrl = ''.obs;
  final errorMessageKey = ''.obs;
  final Rx<QRStatus> qrStatus = QRStatus.loading.obs;
  String qrcodeKey = '';

  Timer? _pollTimer;
  Future<bool>? _activeGeneration;
  Future<void>? _activePoll;
  String? _activePollKey;
  int? _activePollGeneration;
  int _generation = 0;
  int _consecutivePollFailures = 0;
  bool _closed = false;

  @override
  void onInit() {
    super.onInit();
    _closed = false;
    unawaited(loadQRCode());
  }

  Future<bool> loadQRCode() {
    if (_closed) return Future.value(false);
    final activeGeneration = _activeGeneration;
    if (activeGeneration != null) return activeGeneration;

    final generation = ++_generation;
    _cancelPollTimer();
    _consecutivePollFailures = 0;
    qrcodeKey = '';
    qrcodeUrl.value = '';
    errorMessageKey.value = '';
    qrStatus.value = QRStatus.loading;

    late final Future<bool> task;
    task = _loadAndCommitQrCode(generation).whenComplete(() {
      if (identical(_activeGeneration, task)) _activeGeneration = null;
    });
    _activeGeneration = task;
    return task;
  }

  Future<bool> _loadAndCommitQrCode(int generation) async {
    try {
      final code = await _qrCodeLoader();
      if (!_isGenerationCurrent(generation)) return false;
      if (code == null || !code.isValid) {
        _setTerminalFailure('qr_load_failed');
        return false;
      }
      qrcodeKey = code.key.trim();
      qrcodeUrl.value = code.url.trim();
      qrStatus.value = QRStatus.unscanned;
      _scheduleNextPoll(generation);
      return true;
    } catch (_) {
      if (_isGenerationCurrent(generation)) _setTerminalFailure('qr_load_failed');
      return false;
    }
  }

  void startPoll() {
    if (_closed || qrcodeKey.isEmpty) return;
    _scheduleNextPoll(_generation);
  }

  Future<void> pollQRStatus() {
    if (!_canPollCurrentGeneration) return Future.value();
    final generation = _generation;
    final key = qrcodeKey;
    final activePoll = _activePoll;
    if (_activePollGeneration == generation && _activePollKey == key && activePoll != null) {
      return activePoll;
    }

    _cancelPollTimer();
    late final Future<void> task;
    task = _pollAndCommit(key, generation).whenComplete(() {
      if (identical(_activePoll, task)) {
        _activePoll = null;
        _activePollKey = null;
        _activePollGeneration = null;
      }
      if (_isPollCurrent(key, generation) && _canPollCurrentGeneration) {
        _scheduleNextPoll(generation);
      }
    });
    _activePoll = task;
    _activePollKey = key;
    _activePollGeneration = generation;
    return task;
  }

  Future<void> _pollAndCommit(String key, int generation) async {
    try {
      final result = await _qrPoller(key);
      if (!_isPollCurrent(key, generation)) return;
      if (result.apiCode != 0) {
        _handlePollTransportFailure();
        return;
      }
      _consecutivePollFailures = 0;
      switch (result.statusCode) {
        case 0:
          await _verifySuccessfulPoll(result.cookies, key, generation);
          return;
        case 86038:
          qrcodeKey = '';
          qrStatus.value = QRStatus.expired;
          return;
        case 86090:
          qrStatus.value = QRStatus.scanned;
          return;
        case 86101:
          qrStatus.value = QRStatus.unscanned;
          return;
        default:
          _setTerminalFailure('qr_poll_failed');
          return;
      }
    } catch (_) {
      if (_isPollCurrent(key, generation)) _handlePollTransportFailure();
    }
  }

  Future<void> _verifySuccessfulPoll(List<String> cookies, String key, int generation) async {
    final cookie = cookies.map(normalizeAccountCookie).where((value) => value.isNotEmpty).join(';');
    if (cookie.isEmpty) {
      _setTerminalFailure('qr_cookie_missing');
      return;
    }

    _cancelPollTimer();
    qrStatus.value = QRStatus.verifying;
    bool loggedIn;
    try {
      loggedIn = await _cookieVerifier(cookie);
    } catch (_) {
      loggedIn = false;
    }
    if (!_isPollCurrent(key, generation)) return;
    if (!loggedIn) {
      qrcodeKey = '';
      errorMessageKey.value = 'bilibili_login_verification_failed';
      qrStatus.value = QRStatus.failed;
      return;
    }
    qrcodeKey = '';
    errorMessageKey.value = '';
    qrStatus.value = QRStatus.verified;
    _completeLogin();
  }

  void _handlePollTransportFailure() {
    _consecutivePollFailures++;
    if (_consecutivePollFailures == 1) _notice('qr_poll_failed');
    if (_consecutivePollFailures >= maxConsecutivePollFailures) {
      qrcodeKey = '';
      errorMessageKey.value = 'qr_poll_failed';
      qrStatus.value = QRStatus.failed;
    }
  }

  void _setTerminalFailure(String messageKey) {
    _cancelPollTimer();
    qrcodeKey = '';
    errorMessageKey.value = messageKey;
    qrStatus.value = QRStatus.failed;
    _notice(messageKey);
  }

  bool get _canPollCurrentGeneration {
    return !_closed &&
        qrcodeKey.isNotEmpty &&
        (qrStatus.value == QRStatus.unscanned || qrStatus.value == QRStatus.scanned);
  }

  bool _isGenerationCurrent(int generation) => !_closed && generation == _generation;

  bool _isPollCurrent(String key, int generation) {
    return _isGenerationCurrent(generation) && qrcodeKey == key;
  }

  void _scheduleNextPoll(int generation) {
    if (!_isGenerationCurrent(generation) || !_canPollCurrentGeneration) return;
    _cancelPollTimer();
    final failures = _consecutivePollFailures;
    final factor = failures <= 0
        ? 1
        : failures >= 3
        ? 4
        : failures + 1;
    final delay = Duration(microseconds: pollInterval.inMicroseconds * factor);
    _pollTimer = Timer(delay, () {
      _pollTimer = null;
      if (_isGenerationCurrent(generation)) unawaited(pollQRStatus());
    });
  }

  void _cancelPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void onClose() {
    _closed = true;
    _generation++;
    _cancelPollTimer();
    qrcodeKey = '';
    super.onClose();
  }

  static Future<BilibiliQrCode?> _loadQrCode() async {
    final result = await HttpClient.instance.getJson(
      'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
    );
    if (result is! Map || _readInt(result['code']) != 0) return null;
    final data = result['data'];
    if (data is! Map) return null;
    final key = data['qrcode_key'];
    final url = data['url'];
    if (key is! String || url is! String) return null;
    return BilibiliQrCode(key: key, url: url);
  }

  static Future<BilibiliQrPollResult> _pollQrCode(String key) async {
    final response = await HttpClient.instance.get(
      'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
      queryParameters: {'qrcode_key': key},
    );
    final payload = response.data;
    if (payload is! Map) {
      return const BilibiliQrPollResult(apiCode: -1, statusCode: -1);
    }
    final data = payload['data'];
    final statusCode = data is Map ? _readInt(data['code']) ?? -1 : -1;
    final cookies = <String>[];
    response.headers['set-cookie']?.forEach((header) {
      final cookie = header.split(';').first.trim();
      if (cookie.isNotEmpty) cookies.add(cookie);
    });
    return BilibiliQrPollResult(apiCode: _readInt(payload['code']) ?? -1, statusCode: statusCode, cookies: cookies);
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static Future<bool> _verifyCookie(String cookie) {
    final service = BiliBiliAccountService.instance;
    service.setCookie(cookie);
    return service.loadUserInfo();
  }

  static void _finishLogin() {
    Navigator.of(Get.context!).pop(true);
  }

  static void _showNotice(String localizationKey) {
    ToastUtil.show(i18n(localizationKey));
  }
}
