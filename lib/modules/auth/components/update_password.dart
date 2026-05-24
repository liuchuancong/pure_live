import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pure_live/modules/auth/components/supa_reset_password.dart';

class UpdatePassword extends StatelessWidget {
  const UpdatePassword({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('supabase_update_password'), style: const TextStyle(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 24),
          SupaResetPassword(
            accessToken: Supabase.instance.client.auth.currentSession!.accessToken,
            onSuccess: (response) {
              Supabase.instance.client.auth.refreshSession();
              ToastUtil.show(i18n('supabase_sign_success'));
              Get.offAllNamed(RoutePath.kInitial);
            },
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Get.offAllNamed(RoutePath.kSignIn),
            icon: const Icon(Remix.arrow_left_line, size: 16),
            label: Text(i18n('supabase_back_sign_in'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n('supabase_update_password_tip'),
              style: AppTextStyles.t13.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
