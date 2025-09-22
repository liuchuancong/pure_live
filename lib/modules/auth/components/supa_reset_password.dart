import 'package:pure_live/common/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';
// ignore_for_file: use_build_context_synchronously


/// UI component to create password reset form
class SupaResetPassword extends StatefulWidget {
  /// accessToken of the user
  final String? accessToken;

  /// Method to be called when the auth action is success
  final void Function(UserResponse response) onSuccess;

  /// Method to be called when the auth action threw an excepction
  final void Function(Object error)? onError;

  const SupaResetPassword({
    super.key,
    this.accessToken,
    required this.onSuccess,
    this.onError,
  });

  @override
  State<SupaResetPassword> createState() => _SupaResetPasswordState();
}

class _SupaResetPasswordState extends State<SupaResetPassword> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) {
                return S.current.supabase_enter_valid_password;
              }
              return null;
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock),
              label: Text(S.current.supabase_enter_password),
            ),
            controller: _password,
          ),
          spacer(16),
          ElevatedButton(
            child: Text(
              S.current.supabase_update_password,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) {
                return;
              }
              try {
                final response = await supabase.auth.updateUser(
                  UserAttributes(
                    password: _password.text,
                  ),
                );
                widget.onSuccess.call(response);
              } on AuthException catch (error) {
                if (widget.onError == null) {
                  context.showErrorSnackBar(error.message);
                } else {
                  widget.onError?.call(error);
                }
              } catch (error) {
                if (widget.onError == null) {
                  context.showErrorSnackBar(S.current.supabase_unexpected_err(error));
                } else {
                  widget.onError?.call(error);
                }
              }
            },
          ),
          spacer(10),
        ],
      ),
    );
  }
}
