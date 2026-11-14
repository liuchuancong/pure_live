import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_vod/live_vod.dart' show BilibiliTvLogin;
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_app_login.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// Opens the TV sign-in dialog; the app interface's token is stored when the
/// phone confirms the scan.
Future<void> showVodAppLogin(BuildContext context) =>
    showAppDialog<void>(context: context, builder: (context) => const _VodAppLoginDialog());

/// The Bilibili app's own scan-to-sign-in: a QR from the TV login endpoint,
/// polled until the phone confirms.
final class _VodAppLoginDialog extends ConsumerStatefulWidget {
  const _VodAppLoginDialog();

  @override
  ConsumerState<_VodAppLoginDialog> createState() => _VodAppLoginDialogState();
}

final class _VodAppLoginDialogState extends ConsumerState<_VodAppLoginDialog> {
  static const Duration _pollInterval = Duration(seconds: 2);

  late final BilibiliTvLogin _login;
  late final String _deviceId;
  Timer? _timer;
  String? _url;
  String? _authCode;
  String? _failure;
  bool _expired = false;
  bool _scanned = false;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _deviceId = ref.read(vodAppSessionProvider)?.deviceId ?? BilibiliTvLogin.newDeviceId();
    _login = BilibiliTvLogin(ref.read(networkFactoryProvider).create(profile: ClientProfile.api));
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _url = null;
      _authCode = null;
      _failure = null;
      _expired = false;
      _scanned = false;
      _completing = false;
    });
    unawaited(_issue());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  Future<void> _issue() async {
    try {
      final qr = await _login.requestQr(deviceId: _deviceId);
      if (!mounted || _completing) return;
      setState(() {
        _url = qr.url;
        _authCode = qr.authCode;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failure = _login.failureText(error));
    }
  }

  Future<void> _poll() async {
    final authCode = _authCode;
    if (authCode == null || _completing || !mounted) return;
    try {
      final poll = await _login.poll(authCode: authCode, deviceId: _deviceId);
      if (!mounted || _completing) return;
      if (poll.state == 0 && poll.result != null) {
        _completing = true;
        _timer?.cancel();
        await ref.read(vodAppSessionProvider.notifier).save(poll.result!, deviceId: _deviceId);
        if (!mounted) return;
        showDsToast(context: context, title: context.t.vod.appLoginDone, status: DsStatus.success);
        Navigator.of(context).pop();
        return;
      }
      if (poll.state == 86038) {
        _timer?.cancel();
        setState(() => _expired = true);
        return;
      }
      setState(() => _scanned = poll.state == 86090);
    } on Object {
      // A slow poll is retried by the timer; only the QR issue failure is
      // reported.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return AppDialog(
      title: Text(t.vod.appLoginTitle),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Center(
            child: SizedBox(
              width: 184,
              height: 184,
              child: DecoratedBox(
                decoration: DsBoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: theme.radii.controlCorners(null, 16)),
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.s8),
                  child: Center(child: _qrBody(t)),
                ),
              ),
            ),
          ),
          Text(
            _expired ? t.vod.appLoginExpired : (_scanned ? t.vod.appLoginScanned : t.vod.appLoginHint),
            textAlign: TextAlign.center,
            style: theme.typography.body.copyWith(color: colors.textMuted),
          ),
          if (_failure case final failure?)
            Text(
              t.vod.appLoginFailed(message: failure),
              textAlign: TextAlign.center,
              style: theme.typography.small.copyWith(color: colors.danger.text),
            ),
          if (_expired || _failure != null)
            Center(
              child: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: _start,
                child: Text(t.common.retry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qrBody(Translations t) {
    final url = _url;
    if (url == null) {
      return _expired
          ? Center(child: DsEmptyState(icon: const DsIcon(DsIcons.qrCode), title: Text(t.vod.appLoginExpired)))
          : const SizedBox(width: 28, height: 28, child: DsSpinner());
    }
    return PrettyQrView.data(data: url);
  }
}
