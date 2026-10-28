import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart'
    show hongguoAccountProvider, hongguoLoginSessionProvider;

/// The account's second way in: a phone number and the code the website
/// passport sends it. The session behind it is the same one the QR code
/// uses, so a settled code signs the account in exactly as a scanned code
/// does.
final class HongguoPhoneSignIn extends ConsumerStatefulWidget {
  /// Creates the form.
  const HongguoPhoneSignIn({super.key});

  @override
  ConsumerState<HongguoPhoneSignIn> createState() => _HongguoPhoneSignInState();
}

final class _HongguoPhoneSignInState extends ConsumerState<HongguoPhoneSignIn> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  Timer? _ticker;
  int _wait = 0;
  bool _sending = false;
  bool _verifying = false;
  String? _error;
  String _sentTo = '';

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_wait <= 1) {
        timer.cancel();
        setState(() => _wait = 0);
        return;
      }
      setState(() => _wait--);
    });
  }

  Future<void> _send() async {
    final number = _phone.text.trim();
    if (number.isEmpty || _sending || _wait > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await ref.read(hongguoLoginSessionProvider.notifier).sendCode(number);
      if (!mounted) return;
      setState(() {
        _sentTo = sent.maskedMobile;
        _wait = sent.retrySeconds.clamp(0, 600);
      });
      _startTicker();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.isEmpty || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(hongguoLoginSessionProvider.notifier).verifyCode(code);
      // The session change rebuilds the account view into the signed-in one.
      if (mounted && ref.read(hongguoAccountProvider).signedIn) _code.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: DsTextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                placeholder: t.hongguo.phonePlaceholder,
                semanticLabel: t.hongguo.phonePlaceholder,
              ),
            ),
            DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: _sending || _wait > 0 ? null : () => unawaited(_send()),
              child: Text(_wait > 0 ? '${_wait}s' : t.hongguo.phoneSend),
            ),
          ],
        ),
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: DsTextField(
                controller: _code,
                keyboardType: TextInputType.number,
                placeholder: t.hongguo.phoneCodePlaceholder,
                semanticLabel: t.hongguo.phoneCodePlaceholder,
                onSubmitted: (_) => unawaited(_verify()),
              ),
            ),
            DsButton(
              variant: DsButtonVariant.primary,
              onPressed: _verifying ? null : () => unawaited(_verify()),
              child: Text(t.hongguo.phoneVerify),
            ),
          ],
        ),
        if (_sentTo.isNotEmpty)
          Text('${t.hongguo.phoneSent} $_sentTo', style: theme.typography.caption.copyWith(color: colors.textMuted)),
        if (_error != null) Text(_error!, style: theme.typography.caption.copyWith(color: colors.danger.text)),
      ],
    );
  }
}
