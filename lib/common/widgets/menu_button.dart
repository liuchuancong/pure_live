import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:remixicon/remixicon.dart';

class MenuButton extends GetView<AuthController> {
  const MenuButton({super.key});

  final menuRoutes = const [
    RoutePath.kSignIn,
    RoutePath.kSettingsAccount,
    RoutePath.kLog,
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      tooltip: S.current.menu,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      offset: const Offset(12, 0),
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.menu_rounded),
      onSelected: (int index) {
        if (index == 0) {
          if (controller.isLogin) {
            Get.toNamed(RoutePath.kMine);
          } else {
            Get.toNamed(RoutePath.kSignIn);
          }
        } else {
          Get.toNamed(menuRoutes[index]);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: const Icon(Icons.account_circle_outlined),
            text: controller.isLogin ? S.current.supabase_mine : S.current.supabase_sign_in,
          ),
        ),
        PopupMenuItem(
          value: 5,
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: Icon(Icons.assignment_ind_outlined),
            text: S.current.three_party_authentication,
          ),
        ),
        PopupMenuItem(
          value: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: const Icon(Icons.settings_outlined),
            text: S.current.settings_title,
          ),
        ),
        PopupMenuItem(
          value: 3,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: const Icon(Icons.info_outlined),
            text: S.current.about,
          ),
        ),
        PopupMenuItem(
          value: 2,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: const Icon(Icons.contact_support_outlined),
            text: S.current.contact,
          ),
        ),
        PopupMenuItem(
          value: 3,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: const Icon(Icons.history_outlined),
            text: S.current.history,
          ),
        ),
        PopupMenuItem(
          value: 6,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: MenuListTile(
            leading: const Icon(Remix.bug_line),
            text: S.current.settings_log,
          ),
        ),
      ],
    );
  }
}

class MenuListTile extends StatelessWidget {
  final Widget? leading;
  final String text;
  final Widget? trailing;

  const MenuListTile({
    super.key,
    required this.leading,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (trailing != null) ...[
          const SizedBox(width: 24),
          trailing!,
        ],
      ],
    );
  }
}
