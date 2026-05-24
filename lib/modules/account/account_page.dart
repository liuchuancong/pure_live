import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/account_controller.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n('third_party_auth'))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildGroupTitle(theme, i18n('third_party_auth')),
          _buildModernCard(theme, [
            Obx(() {
              final isLogined = BiliBiliAccountService.instance.logined.value;
              final accountName = BiliBiliAccountService.instance.name.value;
              return _buildAccountTile(
                context,
                logo: 'assets/images/bilibili_2.png',
                title: i18n("site_bilibili"),
                subtitle: isLogined ? accountName : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: controller.bilibiliTap,
              );
            }),

            _buildAccountTile(
              context,
              logo: 'assets/images/huya.png',
              title: i18n("site_huya"),
              subtitle: i18n("set_cookie"),
              isLogined: false,
              onTap: () => Get.toNamed(RoutePath.kHuyaCookie),
            ),

            _buildAccountTile(
              context,
              logo: 'assets/images/douyin.png',
              title: i18n("site_douyin"),
              subtitle: i18n("set_cookie"),
              isLogined: false,
              onTap: () => Get.toNamed(RoutePath.kDouyuCookie),
            ),

            _buildAccountTile(
              context,
              logo: 'assets/images/kuaishou.png',
              title: i18n("site_kuaishou"),
              subtitle: i18n("set_cookie"),
              isLogined: false,
              onTap: () => Get.toNamed(RoutePath.kKuaishouCookie),
            ),
            _buildAccountTile(
              context,
              logo: 'assets/images/douyu.png',
              title: i18n("site_douyu"),
              subtitle: i18n("set_cookie"),
              isLogined: false,
              isEnabled: false,
              onTap: () => Get.toNamed(RoutePath.kDouyuCookie),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModernCard(ThemeData theme, List<Widget> children) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required String logo,
    required String title,
    required String subtitle,
    required bool isLogined,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: isEnabled,
      leading: Image.asset(logo, width: 24, height: 24),
      title: Text(
        title,
        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: isEnabled ? null : theme.disabledColor),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: AppTextStyles.t12.copyWith(
            color: isLogined ? theme.colorScheme.primary : theme.hintColor.withValues(alpha: 0.75),
            fontWeight: isLogined ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: isLogined
          ? Icon(Remix.logout_box_r_line, color: theme.colorScheme.error.withValues(alpha: 0.8), size: 18)
          : Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.t12.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
