import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

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

    try {
      UserCredential? credential;

      final githubProvider = GithubAuthProvider()..addScope('user:email');

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(githubProvider);
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final freshUrl = '${FirebaseManager.middlePageUrl}?v=$timestamp';
        final callbackUrl = await FlutterWebAuth2.authenticate(
          url: freshUrl,
          callbackUrlScheme: FirebaseManager.customScheme,
          options: const FlutterWebAuth2Options(preferEphemeral: true),
        );

        final uri = Uri.parse(callbackUrl);

        if (uri.scheme != FirebaseManager.customScheme) {
          throw Exception('Invalid callback scheme: ${uri.scheme}');
        }

        final credentialJson = uri.queryParameters['credential'];

        if (credentialJson == null || credentialJson.isEmpty) {
          throw Exception('Credential data missing from callback URL');
        }

        Map<String, dynamic> credentialMap;

        try {
          credentialMap = jsonDecode(Uri.decodeComponent(credentialJson)) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Failed to parse credential data');
        }

        final accessToken = credentialMap['accessToken'] as String?;

        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('GitHub access token not found');
        }

        final authCredential = GithubAuthProvider.credential(accessToken);

        credential = await _auth.signInWithCredential(authCredential);
      } else {
        credential = await _auth.signInWithProvider(githubProvider);
      }
      widget.onSignInComplete(credential);
    } on PlatformException catch (e) {
      // 用户主动取消登录
      if (e.code.toUpperCase() == 'CANCELED' || e.code.toUpperCase() == 'CANCELLED') {
        return;
      }

      _showErrorSnackbar(e.message ?? 'Authentication cancelled', isError: true);
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? 'GitHub authentication failed', isError: true);
    } catch (e) {
      _showErrorSnackbar(i18n('firebase_unexpected_err', args: {'error': e.toString()}), isError: true);
    } finally {
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
