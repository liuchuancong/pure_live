import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';


class FirebaseEmailAuthBackend {
  const FirebaseEmailAuthBackend();

  bool get supportsPasswordReset => true;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmail(String email, String password) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> saveUserProfile(String userId, Map<String, dynamic> data) {
    return FirebaseFirestore.instance.collection('users').doc(userId).set(data);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential> signInWithPopup(AuthProvider provider) {
    return FirebaseAuth.instance.signInWithPopup(provider);
  }

  Future<UserCredential> signInWithProvider(AuthProvider provider) {
    return FirebaseAuth.instance.signInWithProvider(provider);
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return FirebaseAuth.instance.signInWithCredential(credential);
  }
}

Map<String, dynamic> buildFirebaseSignUpProfileData({
  required String email,
  required Map<String, String> metadata,
  required Object createdAt,
}) {
  const reservedFields = {'email', 'created_at', 'createdAt', 'config', 'update_at', 'version', 'canUpload'};
  final data = <String, dynamic>{'email': email.trim(), 'created_at': createdAt};
  for (final entry in metadata.entries) {
    final key = entry.key.trim();
    if (key.isEmpty || reservedFields.contains(key)) continue;
    data[key] = entry.value.trim();
  }
  return data;
}

class MetaDataField {
  final String label;
  final String key;
  final String? Function(String?)? validator;
  final Icon? prefixIcon;

  MetaDataField({required this.label, required this.key, this.validator, this.prefixIcon});
}

class FirebaseEmailAuth extends StatefulWidget {
  final String? redirectTo;
  final FutureOr<void> Function(UserCredential credential) onSignInComplete;
  final FutureOr<void> Function(UserCredential credential) onSignUpComplete;
  final FutureOr<void> Function()? onPasswordResetEmailSent;
  final void Function(Object error)? onError;
  final FirebaseEmailAuthBackend backend;

  final List<MetaDataField>? metadataFields;
  const FirebaseEmailAuth({
    super.key,
    this.redirectTo,
    required this.onSignInComplete,
    required this.onSignUpComplete,
    this.onPasswordResetEmailSent,
    this.onError,
    this.metadataFields,
    this.backend = const FirebaseEmailAuthBackend(),
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
  int _actionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _metadataControllers = Map.fromEntries(
      (widget.metadataFields ?? []).map((metadataField) => MapEntry(metadataField, TextEditingController())),
    );
  }

  @override
  void dispose() {
    _actionGeneration++;
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
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: AppTextStyles.t14,
              validator: (value) {
                if (!GetUtils.isEmail(value!.trim())) {
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
                enabled: !_isLoading,
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
                    tooltip: i18n(_obscurePassword ? 'firebase_show_password' : 'firebase_hide_password'),
                    icon: Icon(
                      _obscurePassword ? Remix.eye_off_line : Remix.eye_line,
                      size: 18,
                      color: theme.hintColor.withValues(alpha: 0.6),
                    ),
                    onPressed: _isLoading ? null : () => setState(() => _obscurePassword = !_obscurePassword),
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
                      enabled: !_isLoading,
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
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
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
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
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
            if (_isSigningIn && widget.backend.supportsPasswordReset)
              TextButton(
                onPressed: _isLoading ? null : () => setState(() => _forgotPassword = true),
                child: Text(i18n('firebase_forgot_password')),
              ),
            TextButton(
              key: const ValueKey('toggleSignInButton'),
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _forgotPassword = false;
                        _isSigningIn = !_isSigningIn;
                      });
                    },
              child: Text(_isSigningIn ? i18n('firebase_no_account') : i18n('firebase_has_account')),
            ),
          ],
          if (_isSigningIn && _forgotPassword && widget.backend.supportsPasswordReset) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
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
              onPressed: _isLoading ? null : () => setState(() => _forgotPassword = false),
              child: Text(i18n('firebase_back_sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleGitHubSignIn() async {
    final generation = _beginAction();
    if (generation == null) return;
    try {
      late final UserCredential credential;
      final githubProvider = GithubAuthProvider()..addScope('user:email');

      if (kIsWeb) {
        credential = await widget.backend.signInWithPopup(githubProvider);
      } else if (Platform.isWindows) {
        final authUrl = Uri.parse(
          '${FirebaseManager.middlePageUrl}?platform=windows&scheme=${FirebaseManager.customScheme}',
        );
        if (await canLaunchUrl(authUrl)) {
          await launchUrl(authUrl, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch authentication URL';
        }

        final pasteText = await Utils.showEditTextDialog(
          "",
          title: i18n("github_login"),
          hintText: i18n("paste_auth_link"),
        );

        if (pasteText == null || pasteText.trim().isEmpty) {
          return;
        }

        const prefix = 'purelive://auth?credential=';
        final text = pasteText.trim();
        if (!text.startsWith(prefix)) {
          throw 'invalid link';
        }

        final encoded = text.substring(prefix.length);
        final decoded = Uri.decodeComponent(encoded);
        final jsonMap = jsonDecode(decoded);
        final accessToken = jsonMap['accessToken'];
        if (accessToken == null || accessToken.isEmpty) {
          throw 'invalid token';
        }

        final githubCredential = GithubAuthProvider.credential(accessToken);
        credential = await widget.backend.signInWithCredential(githubCredential);

        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setAlwaysOnTop(true);
        await Future.delayed(const Duration(milliseconds: 100));
        await windowManager.setAlwaysOnTop(false);
      } else if (Platform.isMacOS || Platform.isLinux) {
        throw 'Unsupported desktop platform';
      } else {
        credential = await widget.backend.signInWithProvider(githubProvider);
      }

      if (!_isCurrentAction(generation)) return;
      await Future.sync(() => widget.onSignInComplete(credential));
    } catch (error) {
      if (_isCurrentAction(generation)) {
        _reportActionError(error, 'firebase_github_sign_in_failed');
      }
    } finally {
      _finishAction(generation);
    }
  }

  void _reportActionError(Object error, String fallbackKey) {
    if (widget.onError != null) {
      widget.onError!(error);
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(i18n(fallbackKey)), backgroundColor: Theme.of(context).colorScheme.error));
  }

  Future<void> _handleSubmit() async {
    if (_isLoading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    final generation = _beginAction();
    if (generation == null) return;
    try {
      if (_isSigningIn) {
        final credential = await widget.backend.signInWithEmail(_emailController.text.trim(), _passwordController.text);
        if (!_isCurrentAction(generation)) return;
        await Future.sync(() => widget.onSignInComplete(credential));
      } else {
        final email = _emailController.text.trim();
        final credential = await widget.backend.createUserWithEmail(email, _passwordController.text);
        if (credential.user != null) {
          final userData = buildFirebaseSignUpProfileData(
            email: email,
            metadata: {for (final entry in _metadataControllers.entries) entry.key.key: entry.value.text},
            createdAt: FieldValue.serverTimestamp(),
          );
          await widget.backend.saveUserProfile(credential.user!.uid, userData);
        }
        if (!_isCurrentAction(generation)) return;
        await Future.sync(() => widget.onSignUpComplete(credential));
      }
    } catch (error) {
      if (_isCurrentAction(generation)) {
        _reportActionError(error, _isSigningIn ? 'firebase_email_sign_in_failed' : 'firebase_email_sign_up_failed');
      }
    } finally {
      _finishAction(generation);
    }
  }

  Future<void> _handleResetPassword() async {
    if (_isLoading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    final generation = _beginAction();
    if (generation == null) return;
    try {
      final email = _emailController.text.trim();
      await widget.backend.sendPasswordResetEmail(email);
      if (!_isCurrentAction(generation)) return;
      await Future.sync(() => widget.onPasswordResetEmailSent?.call());
    } catch (error) {
      if (_isCurrentAction(generation)) {
        _reportActionError(error, 'firebase_password_reset_failed');
      }
    } finally {
      _finishAction(generation);
    }
  }

  int? _beginAction() {
    if (!mounted || _isLoading) return null;
    final generation = ++_actionGeneration;
    setState(() => _isLoading = true);
    return generation;
  }

  bool _isCurrentAction(int generation) => mounted && generation == _actionGeneration;

  void _finishAction(int generation) {
    if (!_isCurrentAction(generation)) return;
    setState(() => _isLoading = false);
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
