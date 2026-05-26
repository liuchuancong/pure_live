import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';

class SupaResetPassword extends StatefulWidget {
  final String? accessToken;
  final void Function(UserResponse response) onSuccess;
  final void Function(Object error)? onError;

  const SupaResetPassword({super.key, this.accessToken, required this.onSuccess, this.onError});

  @override
  State<SupaResetPassword> createState() => _SupaResetPasswordState();
}

class _SupaResetPasswordState extends State<SupaResetPassword> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _password.dispose();
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
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
            ),
            child: TextFormField(
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 6) {
                  return i18n('supabase_enter_valid_password');
                }
                return null;
              },
              style: AppTextStyles.t14,
              decoration: InputDecoration(
                hintText: i18n('supabase_enter_password'),
                hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
                prefixIcon: Icon(Remix.lock_line, size: 20, color: theme.hintColor.withValues(alpha: 0.7)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Remix.eye_off_line : Remix.eye_line,
                    size: 18,
                    color: theme.hintColor.withValues(alpha: 0.6),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
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
              ),
              obscureText: _obscurePassword,
              controller: _password,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _isLoading ? null : _handleUpdatePassword,
              child: _isLoading
                  ? AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", isMini: true)
                  : Text(
                      i18n('supabase_update_password'),
                      style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.updateUser(UserAttributes(password: _password.text));
      widget.onSuccess.call(response);
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
}
