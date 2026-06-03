import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final _auth = FirebaseAuth.instance;
final _db = FirebaseFirestore.instance;

class MetaDataField {
  final String label;
  final String key;
  final String? Function(String?)? validator;
  final Icon? prefixIcon;

  MetaDataField({required this.label, required this.key, this.validator, this.prefixIcon});
}

class FirebaseEmailAuth extends StatefulWidget {
  final String? redirectTo;
  final void Function(UserCredential credential) onSignInComplete;
  final void Function(UserCredential credential) onSignUpComplete;
  final void Function()? onPasswordResetEmailSent;
  final void Function(Object error)? onError;

  final List<MetaDataField>? metadataFields;
  const FirebaseEmailAuth({
    super.key,
    this.redirectTo,
    required this.onSignInComplete,
    required this.onSignUpComplete,
    this.onPasswordResetEmailSent,
    this.onError,
    this.metadataFields,
  });

  @override
  State<FirebaseEmailAuth> createState() => _FirebaseEmailAuthState();
}

class _FirebaseEmailAuthState extends State<FirebaseEmailAuth> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final Map<MetaDataField, TextEditingController> _metadataControllers;

  bool _isLoading = false;
  bool _forgotPassword = false;
  bool _isSigningIn = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _metadataControllers = Map.fromEntries(
      (widget.metadataFields ?? []).map((metadataField) => MapEntry(metadataField, TextEditingController())),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    for (final controller in _metadataControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormCard(theme, [
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: AppTextStyles.t14,
              validator: (value) {
                if (value == null || value.isEmpty || !EmailValidator.validate(_emailController.text)) {
                  return i18n('firebase_enter_valid_email');
                }
                return null;
              },
              decoration: _buildInputDecoration(
                theme,
                hintText: i18n('firebase_enter_email'),
                prefixIcon: Remix.mail_line,
              ),
              controller: _emailController,
            ),
            if (!_forgotPassword) ...[
              const SizedBox(height: 16),
              TextFormField(
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return i18n('firebase_enter_valid_password');
                  }
                  return null;
                },
                style: AppTextStyles.t14,
                decoration: _buildInputDecoration(
                  theme,
                  hintText: i18n('firebase_enter_password'),
                  prefixIcon: Remix.lock_line,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Remix.eye_off_line : Remix.eye_line,
                      size: 18,
                      color: theme.hintColor.withValues(alpha: 0.6),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                controller: _passwordController,
              ),
              if (widget.metadataFields != null && !_isSigningIn) ...[
                const SizedBox(height: 16),
                ...widget.metadataFields!.map((metadataField) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _metadataControllers[metadataField],
                      style: AppTextStyles.t14,
                      decoration: InputDecoration(
                        hintText: metadataField.label,
                        prefixIcon: metadataField.prefixIcon,
                        contentPadding: const EdgeInsets.all(14.0),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                      ),
                      validator: metadataField.validator,
                    ),
                  );
                }),
              ],
            ],
          ]),
          const SizedBox(height: 24),
          if (!_forgotPassword) ...[
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", isMini: true)
                    : Text(
                        _isSigningIn ? i18n('firebase_sign_in') : i18n('firebase_sign_up'),
                        style: AppTextStyles.t15.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSigningIn) ...[
              Row(
                children: [
                  Expanded(child: Divider(color: theme.dividerColor.withValues(alpha: 0.1))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(i18n('or'), style: AppTextStyles.t12.copyWith(color: theme.hintColor)),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor.withValues(alpha: 0.1))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                  onPressed: _isLoading ? null : _handleGitHubSignIn,
                  icon: const Icon(Remix.github_fill, size: 20),
                  label: Text(i18n('github_sign_in'), style: AppTextStyles.t14.copyWith(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_isSigningIn && Platform.isAndroid)
              TextButton(
                onPressed: () => setState(() => _forgotPassword = true),
                child: Text(i18n('firebase_forgot_password')),
              ),
            TextButton(
              key: const ValueKey('toggleSignInButton'),
              onPressed: () {
                setState(() {
                  _forgotPassword = false;
                  _isSigningIn = !_isSigningIn;
                });
              },
              child: Text(_isSigningIn ? i18n('firebase_no_account') : i18n('firebase_has_account')),
            ),
          ],
          if (_isSigningIn && _forgotPassword && Platform.isAndroid) ...[
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                onPressed: _isLoading ? null : _handleResetPassword,
                child: _isLoading
                    ? AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", isMini: true)
                    : Text(
                        i18n('firebase_reset_password'),
                        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _forgotPassword = false),
              child: Text(i18n('firebase_back_sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleGitHubSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    HttpServer? server;

    try {
      UserCredential? credential;

      final githubProvider = GithubAuthProvider()..addScope('user:email');

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(githubProvider);
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final authCodeCompleter = Completer<String>();

        const port = 45678;

        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

        debugPrint(
          'GitHub OAuth callback server started: '
          'http://127.0.0.1:$port/callback',
        );

        server.listen((HttpRequest request) async {
          try {
            debugPrint('OAuth callback: ${request.uri}');

            final code = request.uri.queryParameters['code'];

            final error = request.uri.queryParameters['error'];

            request.response.headers.contentType = ContentType.html;

            if (error != null) {
              request.response.write('''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GitHub 登录失败</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
  body { background: #0d1117; display: flex; align-items: center; justify-content: center; min-height: 100vh; color: #c9d1d9; overflow: hidden; }
  .background-glow { position: absolute; width: 400px; height: 400px; background: radial-gradient(circle, rgba(248,81,73,0.12) 0%, rgba(0,0,0,0) 70%); top: 50%; left: 50%; transform: translate(-50%, -50%); z-index: 1; }
  .card { background: rgba(22, 27, 34, 0.8); border: 1px solid rgba(248, 81, 73, 0.25); border-radius: 16px; padding: 40px; width: 90%; max-width: 420px; text-align: center; box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5); backdrop-filter: blur(8px); position: relative; z-index: 2; animation: fadeIn 0.4s ease-out; }
  .icon-wrapper { width: 72px; height: 72px; background: rgba(248, 81, 73, 0.1); border: 2px solid #f85149; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; animation: shake 0.5s ease-in-out; }
  .icon-wrapper svg { width: 36px; height: 36px; fill: #f85149; }
  h2 { color: #f85149; font-size: 24px; font-weight: 600; margin-bottom: 12px; }
  p { color: #8b949e; font-size: 14px; line-height: 1.6; word-break: break-all; background: rgba(0,0,0,0.2); padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.05); }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
  @keyframes shake { 0%, 100% { transform: translateX(0); } 20%, 60% { transform: translateX(-6px); } 40%, 80% { transform: translateX(6px); } }
</style>
</head>
<body>
<div class="background-glow"></div>
<div class="card">
  <div class="icon-wrapper">
    <svg viewBox="0 0 24 24"><path d="M12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
  </div>
  <h2>认证失败</h2>
  <p>$error</p>
</div>
</body>
</html>
''');
              await request.response.close();
              if (!authCodeCompleter.isCompleted) {
                authCodeCompleter.completeError(Exception(error));
              }
              return;
            }

            request.response.write('''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GitHub 登录成功</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
  body { background: #0d1117; display: flex; align-items: center; justify-content: center; min-height: 100vh; color: #c9d1d9; overflow: hidden; }
  .background-glow { position: absolute; width: 500px; height: 500px; background: radial-gradient(circle, rgba(56,139,253,0.1) 0%, rgba(0,0,0,0) 70%); top: 50%; left: 50%; transform: translate(-50%, -50%); z-index: 1; }
  .card { background: rgba(22, 27, 34, 0.75); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 20px; padding: 44px 40px; width: 90%; max-width: 420px; text-align: center; box-shadow: 0 16px 40px rgba(0, 0, 0, 0.6); backdrop-filter: blur(12px); position: relative; z-index: 2; animation: scaleUp 0.4s cubic-bezier(0.16, 1, 0.3, 1); }
  .icon-wrapper { width: 80px; height: 80px; background: rgba(46, 160, 67, 0.1); border: 2px solid #3fb950; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 28px; position: relative; }
  .icon-wrapper svg { width: 40px; height: 40px; fill: #3fb950; animation: popCheck 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275) 0.2s both; }
  .pulse { position: absolute; width: 100%; height: 100%; border: 2px solid rgba(63, 185, 80, 0.4); border-radius: 50%; animation: pulseRing 1.5s infinite ease-out; }
  h2 { color: #f0f6fc; font-size: 24px; font-weight: 600; margin-bottom: 10px; letter-spacing: 0.5px; }
  .tip { color: #8b949e; font-size: 15px; margin-bottom: 24px; }
  .countdown-bar { width: 100%; height: 4px; background: rgba(255,255,255,0.05); border-radius: 2px; overflow: hidden; position: relative; }
  .countdown-progress { height: 100%; width: 100%; background: linear-gradient(90deg, #58a6ff, #388bfd); transform-origin: left; animation: shrinkWidth 1s linear forwards; }
  @keyframes scaleUp { from { opacity: 0; transform: scale(0.92); } to { opacity: 1; transform: scale(1); } }
  @keyframes popCheck { from { opacity: 0; transform: scale(0.5); } to { opacity: 1; transform: scale(1); } }
  @keyframes pulseRing { 0% { transform: scale(0.95); opacity: 1; } 100% { transform: scale(1.3); opacity: 0; } }
  @keyframes shrinkWidth { from { transform: scaleX(1); } to { transform: scaleX(0); } }
</style>
</head>
<body>
<div class="background-glow"></div>
<div class="card">
  <div class="icon-wrapper">
    <div class="pulse"></div>
    <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
  </div>
  <h2>授权登录成功</h2>
  <p class="tip">正在安全返回 PureLive 应用...</p>
  <div class="countdown-bar">
    <div class="countdown-progress"></div>
  </div>
</div>

<script>
setTimeout(() => {
  window.close();
}, 1000);
</script>
</body>
</html>
''');
            await request.response.close();

            if (code != null && code.isNotEmpty && !authCodeCompleter.isCompleted) {
              authCodeCompleter.complete(code);
            }
          } catch (e) {
            if (!authCodeCompleter.isCompleted) {
              authCodeCompleter.completeError(e);
            }
          }
        });
        const clientId = 'Ov23lifAi0dZoD6GDIzC';

        const clientSecret = 'd5baed3720c409b10a48d018e59ab95c66183263';

        const redirectUrl = 'http://127.0.0.1:45678/callback';

        final githubAuthUrl = Uri.parse(
          'https://github.com/login/oauth/authorize'
          '?client_id=$clientId'
          '&redirect_uri=${Uri.encodeComponent(redirectUrl)}'
          '&scope=user:email',
        );

        debugPrint('Open GitHub URL: $githubAuthUrl');

        if (await canLaunchUrl(githubAuthUrl)) {
          await launchUrl(githubAuthUrl, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('无法打开系统默认浏览器');
        }

        final code = await authCodeCompleter.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            throw TimeoutException('登录超时，请重试');
          },
        );

        debugPrint('GitHub Authorization Code: $code');

        final tokenResponse = await http.post(
          Uri.parse('https://github.com/login/oauth/access_token'),
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': clientId,
            'client_secret': clientSecret,
            'code': code,
            'redirect_uri': redirectUrl,
          }),
        );

        debugPrint(
          'Token Response: '
          '${tokenResponse.statusCode}',
        );

        debugPrint(tokenResponse.body);

        if (tokenResponse.statusCode != 200) {
          throw Exception('与 GitHub Token 服务通信失败');
        }

        final responseBody = jsonDecode(tokenResponse.body) as Map<String, dynamic>;

        final accessToken = responseBody['access_token'] as String?;

        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('GitHub 未返回 Access Token');
        }

        final authCredential = GithubAuthProvider.credential(accessToken);

        await Future.microtask(() async {
          credential = await _auth.signInWithCredential(authCredential);
        });
      } else {
        credential = await _auth.signInWithProvider(githubProvider);
      }
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
      await Future.delayed(const Duration(milliseconds: 100));
      await windowManager.setAlwaysOnTop(false);
      widget.onSignInComplete(credential!);
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? 'GitHub authentication failed', isError: true);
    } on TimeoutException {
      _showErrorSnackbar('登录超时，请重试', isError: true);
    } catch (e) {
      _showErrorSnackbar(e.toString(), isError: true);
    } finally {
      try {
        await server?.close(force: true);
      } catch (_) {}

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackbar(String message, {bool isError = false}) {
    if (widget.onError != null) {
      widget.onError!(message);
      return;
    }

    Get.showSnackbar(
      GetSnackBar(
        message: message,
        duration: const Duration(seconds: 3),
        backgroundColor: isError ? Get.theme.colorScheme.error : Get.theme.colorScheme.primary,
      ),
    );
  }

  Future _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isSigningIn) {
        final credential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        widget.onSignInComplete.call(credential);
      } else {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (credential.user != null) {
          final Map<String, dynamic> userData = {
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          };
          _metadataControllers.forEach((field, controller) {
            userData[field.key] = controller.text;
          });
          await _db.collection('users').doc(credential.user!.uid).set(userData);
        }
        widget.onSignUpComplete.call(credential);
      }
    } on FirebaseAuthException catch (error) {
      if (widget.onError == null) {
        Get.showSnackbar(
          GetSnackBar(message: error.message ?? 'Authentication failed', backgroundColor: Get.theme.colorScheme.error),
        );
      } else {
        widget.onError?.call(error);
      }
    } catch (error) {
      if (widget.onError == null) {
        Get.showSnackbar(
          GetSnackBar(
            message: i18n('firebase_unexpected_err', args: {'error': error.toString()}),
            backgroundColor: Get.theme.colorScheme.primary,
          ),
        );
      } else {
        widget.onError?.call(error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await _auth.sendPasswordResetEmail(email: email);
      widget.onPasswordResetEmailSent?.call();
    } on FirebaseAuthException catch (error) {
      widget.onError?.call(error);
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(
    ThemeData theme, {
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
      prefixIcon: Icon(prefixIcon, size: 20, color: theme.hintColor.withValues(alpha: 0.7)),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
