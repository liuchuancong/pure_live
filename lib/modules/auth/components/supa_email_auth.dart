import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:email_validator/email_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';

final supabase = Supabase.instance.client;

class MetaDataField {
  final String label;
  final String key;
  final String? Function(String?)? validator;
  final Icon? prefixIcon;

  MetaDataField({required this.label, required this.key, this.validator, this.prefixIcon});
}

class SupaEmailAuth extends StatefulWidget {
  final String? redirectTo;
  final void Function(AuthResponse response) onSignInComplete;
  final void Function(AuthResponse response) onSignUpComplete;
  final void Function()? onPasswordResetEmailSent;
  final void Function(Object error)? onError;

  final List<MetaDataField>? metadataFields;
  const SupaEmailAuth({
    super.key,
    this.redirectTo,
    required this.onSignInComplete,
    required this.onSignUpComplete,
    this.onPasswordResetEmailSent,
    this.onError,
    this.metadataFields,
  });

  @override
  State<SupaEmailAuth> createState() => _SupaEmailAuthState();
}

class _SupaEmailAuthState extends State<SupaEmailAuth> {
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
                  return i18n('supabase_enter_valid_email');
                }
                return null;
              },
              decoration: _buildInputDecoration(
                theme,
                hintText: i18n('supabase_enter_email'),
                prefixIcon: Remix.mail_line,
              ),
              controller: _emailController,
            ),
            if (!_forgotPassword) ...[
              const SizedBox(height: 16),
              TextFormField(
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return i18n('supabase_enter_valid_password');
                  }
                  return null;
                },
                style: AppTextStyles.t14,
                decoration: _buildInputDecoration(
                  theme,
                  hintText: i18n('supabase_enter_password'),
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
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2),
                      )
                    : Text(
                        _isSigningIn ? i18n('supabase_sign_in') : i18n('supabase_sign_up'),
                        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isSigningIn && Platform.isAndroid)
              TextButton(
                onPressed: () => setState(() => _forgotPassword = true),
                child: Text(i18n('supabase_forgot_password')),
              ),
            TextButton(
              key: const ValueKey('toggleSignInButton'),
              onPressed: () {
                setState(() {
                  _forgotPassword = false;
                  _isSigningIn = !_isSigningIn;
                });
              },
              child: Text(_isSigningIn ? i18n('supabase_no_account') : i18n('supabase_has_account')),
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
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: theme.colorScheme.onSecondary, strokeWidth: 2),
                      )
                    : Text(
                        i18n('supabase_reset_password'),
                        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _forgotPassword = false),
              child: Text(i18n('supabase_back_sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isSigningIn) {
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        widget.onSignInComplete.call(response);
      } else {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          emailRedirectTo: widget.redirectTo,
          data: widget.metadataFields == null
              ? null
              : _metadataControllers.map<String, dynamic>(
                  (metaDataField, controller) => MapEntry(metaDataField.key, controller.text),
                ),
        );
        widget.onSignUpComplete.call(response);
      }
    } on AuthException catch (error) {
      if (widget.onError == null) {
        Get.context!.showErrorSnackBar(error.message);
      } else {
        widget.onError?.call(error);
      }
    } catch (error) {
      if (widget.onError == null) {
        Get.context!.showErrorSnackBar(i18n('supabase_unexpected_err', args: {'error': error.toString()}));
      } else {
        widget.onError?.call(error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await supabase.auth.resetPasswordForEmail(email);
      widget.onPasswordResetEmailSent?.call();
    } on AuthException catch (error) {
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
