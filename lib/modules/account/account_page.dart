import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/account_controller.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cookie = controller.cookie;

    return Scaffold(
      appBar: AppBar(title: Text(i18n('third_party_auth'))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('third_party_auth')),
          context.buildModernCard([
            Obx(() {
              final isLogined = BiliBiliAccountService.instance.logined.v;
              final accountName = BiliBiliAccountService.instance.name.v;
              return _buildAccountTile(
                context,
                logo: 'assets/images/bilibili_2.png',
                title: i18n("site_bilibili"),
                subtitle: isLogined
                    ? accountName.trim().isEmpty
                          ? i18n('account_verifying')
                          : accountName
                    : i18n("not_logged_in"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_bilibili'),
                        onConfirm: BiliBiliAccountService.instance.logout,
                      )
                    : controller.bilibiliTap(),
              );
            }),

            Obx(() {
              final isLogined = cookie.huyaCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/huya.png',
                title: i18n("site_huya"),
                subtitle: isLogined ? i18n("logined") : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_huya'),
                        onConfirm: () => cookie.huyaCookie.v = "",
                      )
                    : Get.toNamed(RoutePath.kHuyaCookie),
              );
            }),
            Obx(() {
              final isLogined = cookie.yyCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/yy.png',
                title: i18n("site_yy"),
                subtitle: isLogined ? i18n("logined") : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(context, accountName: i18n('site_yy'), onConfirm: () => cookie.yyCookie.v = "")
                    : Get.toNamed(RoutePath.kYyCookie),
              );
            }),
            Obx(() {
              final isLogined = cookie.taobaoCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/logo.png',
                title: i18n('site_taobaolive'),
                subtitle: isLogined ? i18n('logined') : i18n('set_cookie'),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_taobaolive'),
                        onConfirm: () => cookie.taobaoCookie.v = '',
                      )
                    : Get.toNamed(RoutePath.kTaobaoCookie),
              );
            }),
            Obx(() {
              final isLogined = cookie.douyinCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/douyin.png',
                title: i18n("site_douyin"),
                subtitle: isLogined
                    ? controller.douyinNickName.value.isNotEmpty
                          ? controller.douyinNickName.value
                          : i18n("logined")
                    : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_douyin'),
                        onConfirm: () => cookie.douyinCookie.v = "",
                      )
                    : Get.toNamed(RoutePath.kDouyinCookie),
              );
            }),

            Obx(() {
              final isLogined = cookie.kuaishouCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/kuaishou.png',
                title: i18n("site_kuaishou"),
                subtitle: isLogined ? i18n("logined") : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_kuaishou'),
                        onConfirm: () => cookie.kuaishouCookie.v = "",
                      )
                    : Get.toNamed(RoutePath.kKuaishouCookie),
              );
            }),
            Obx(() {
              final isLogined = cookie.twitchCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/twitch.png',
                title: i18n("site_twitch"),
                subtitle: isLogined ? i18n("logined") : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_twitch'),
                        onConfirm: () => cookie.twitchCookie.v = "",
                      )
                    : Get.toNamed(RoutePath.kTwitchCookie),
              );
            }),
            Obx(() {
              final isLogined = cookie.soopCookie.v.isNotEmpty;
              return _buildAccountTile(
                context,
                logo: 'assets/images/soop.png',
                title: i18n("site_soop"),
                subtitle: isLogined ? i18n("logined") : i18n("set_cookie"),
                isLogined: isLogined,
                onTap: () => isLogined
                    ? _showLogoutDialog(
                        context,
                        accountName: i18n('site_soop'),
                        onConfirm: () => cookie.soopCookie.v = "",
                      )
                    : Get.toNamed(RoutePath.kSoop),
              );
            }),
            _buildAccountTile(
              context,
              logo: 'assets/images/douyu.png',
              title: i18n("site_douyu"),
              subtitle: i18n("disabled"),
              isLogined: false,
              isEnabled: false,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required String logo,
    required String title,
    required String subtitle,
    required bool isLogined,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedText = constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
        return ListTile(
          enabled: isEnabled,
          leading: Image.asset(logo, width: 24, height: 24),
          title: Text(
            title,
            style: AppTextStyles.t15.copyWith(
              fontWeight: FontWeight.w600,
              color: isEnabled ? null : theme.disabledColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: AppTextStyles.t12.copyWith(
                color: isLogined ? theme.colorScheme.primary : theme.hintColor.withValues(alpha: 0.75),
                fontWeight: isLogined ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: expandedText ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: !isEnabled
              ? null
              : isLogined
              ? IconButton(
                  tooltip: i18n('logout'),
                  visualDensity: VisualDensity.standard,
                  constraints: const BoxConstraints(
                    minWidth: kMinInteractiveDimension,
                    minHeight: kMinInteractiveDimension,
                  ),
                  onPressed: onTap,
                  icon: Icon(Remix.logout_box_r_line, color: theme.colorScheme.error.withValues(alpha: 0.8), size: 18),
                )
              : Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
          onTap: isEnabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        );
      },
    );
  }

  void _showLogoutDialog(
    BuildContext context, {
    required String accountName,
    required FutureOr<void> Function() onConfirm,
  }) {
    unawaited(
      controller.runLogoutTransaction(() async {
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            title: Text(i18n('logout')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(i18n('confirm_logout_named', args: {'name': accountName})),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
                child: Text(i18n('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
                child: Text(i18n('logout')),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        await onConfirm();
      }),
    );
  }
}
