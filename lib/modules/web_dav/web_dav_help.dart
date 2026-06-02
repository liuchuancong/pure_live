import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

class WebDavHelpPage extends StatelessWidget {
  const WebDavHelpPage({super.key});

  // 全部7张原图链接
  static const List<String> imgUrls = [
    "assets/webdav/00_home.png",
    "assets/webdav/02_register.png",
    "assets/webdav/03_login.png",
    "assets/webdav/01_avatar_menu.png",
    "assets/webdav/04_security.png",
    "assets/webdav/05_add_app.png",
    "assets/webdav/06_get_pwd.png",
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("坚果云 WebDAV 绑定教程"), centerTitle: true, elevation: 0),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 一、前言部分
          _buildSectionTitle(context, "📖 一、前言（必看）"),
          _buildIntroCard(theme),
          const SizedBox(height: 22),

          // 参数速查卡片
          _buildSectionTitle(context, "📌 WebDAV三项核心参数（长按复制）"),
          _buildParamCard(context, theme),
          const SizedBox(height: 24),

          // 二、注册教程
          _buildSectionTitle(context, "📝 二、坚果云账号注册教程（新手从零开始）"),
          _buildStepCard(
            context,
            stepContent: const [
              "1. 进入官网：浏览器打开 https://www.jianguoyun.com",
              "2. 点击右上角【注册】，推荐邮箱注册（WebDAV必须依赖邮箱账号）",
              "3. 填写常用邮箱、设置登录密码、绑定手机号收验证码",
              "⚠️ 注册完成后，前往邮箱点击验证链接激活账号",
            ],
            imgUrl: imgUrls[0],
          ),
          const SizedBox(height: 16),
          _buildStepCard(context, stepContent: const ["补充：注册页填写邮箱与个人信息"], imgUrl: imgUrls[1]),
          const SizedBox(height: 24),

          // 三、网页登录
          _buildSectionTitle(context, "🔐 三、网页端登录教程"),
          _buildStepCard(
            context,
            stepContent: const ["1. WebDAV密码仅能在网页端生成，必须浏览器网页登录", "2. 账号填注册邮箱 + 网页登录密码完成登录"],
            imgUrl: imgUrls[2],
          ),
          const SizedBox(height: 24),

          // 四、生成应用密码
          _buildSectionTitle(context, "🔑 四、关键步骤：生成WebDAV第三方应用密码"),
          _buildStepCard(context, stepContent: const ["1. 网页右上角头像 → 点击【账户信息】"], imgUrl: imgUrls[3]),
          const SizedBox(height: 16),
          _buildStepCard(context, stepContent: const ["2. 左侧菜单栏打开【安全选项】"], imgUrl: imgUrls[4]),
          const SizedBox(height: 16),
          _buildStepCard(
            context,
            stepContent: const ["3. 下拉找到【第三方应用与设备管理】", "4. 点击【添加应用密码】，自定义名称如PureLive，权限默认读写"],
            imgUrl: imgUrls[5],
          ),
          const SizedBox(height: 16),
          _buildStepCard(context, stepContent: const ["5. 生成16位随机密码，立刻复制保存，密码仅展示一次，丢失需重开"], imgUrl: imgUrls[6]),
          const SizedBox(height: 24),

          // 五、通用绑定
          _buildSectionTitle(context, "⚙️ 五、任意软件WebDAV通用绑定教程"),
          _buildBindCard(theme),
          const SizedBox(height: 24),

          // 六、常见报错
          _buildSectionTitle(context, "❓ 六、常见报错与解决"),
          _buildTroubleShootCard(context, theme),
          const SizedBox(height: 24),

          // 七、懒人总结
          _buildSectionTitle(context, "✅ 七、快速总结（懒人复制版）"),
          _buildSummaryCard(theme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 标题组件
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2)),
    );
  }

  // 前言卡片
  Widget _buildIntroCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: const Text(
        "坚果云是目前国内最稳定、支持WebDAV免费同步的云盘。\n免费用户权益：\n• 永久存储空间：3GB\n• 每月上传流量：1GB（次月刷新）\nWebDAV用途：给各类播放器、笔记、APP、配置文件做云同步、云备份。",
        style: TextStyle(fontSize: 13.5, height: 1.6),
      ),
    );
  }

  // 参数卡片
  Widget _buildParamCard(BuildContext context, ThemeData theme) {
    const String davUrl = "https://dav.jianguoyun.com/dav/";
    return Container(
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Remix.links_line, color: theme.colorScheme.primary, size: 22),
            title: const Text("WebDAV 服务器地址", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: InkWell(
              onTap: () async {
                await launchUrl(Uri.parse(davUrl));
              },
              child: Text(
                davUrl,
                style: const TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            trailing: IconButton(
              icon: Icon(Remix.file_copy_line, color: theme.hintColor, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: davUrl));
                Get.snackbar("复制成功", "服务器地址已存入剪贴板", snackPosition: SnackPosition.bottom);
              },
            ),
          ),
          _divider(),
          ListTile(
            leading: Icon(Remix.mail_line, color: theme.colorScheme.primary, size: 22),
            title: const Text("用户名", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("坚果云注册邮箱（禁止填写手机号）", style: TextStyle(fontSize: 12)),
          ),
          _divider(),
          ListTile(
            leading: Icon(Remix.lock_password_line, color: theme.colorScheme.primary, size: 22),
            title: const Text("WebDAV应用密码", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("16位第三方应用密码≠账号登录密码", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // 步骤卡片：文字居左、图片居中
  Widget _buildStepCard(BuildContext context, {required List<String> stepContent, required String imgUrl}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 文字全部左对齐
        children: [
          ...stepContent.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(e, style: const TextStyle(fontSize: 13.5, height: 1.55)),
            ),
          ),
          const SizedBox(height: 14),
          // 图片外层居中容器
          Center(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      body: Stack(
                        children: [
                          PhotoView(
                            imageProvider: AssetImage(imgUrl),
                            minScale: PhotoViewComputedScale.contained,
                            maxScale: PhotoViewComputedScale.covered * 3.0,
                          ),
                          Positioned(
                            top: 40,
                            right: 20,
                            child: ClipOval(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.4),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imgUrl,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 40,
                      alignment: Alignment.center,
                      color: theme.dividerColor.withValues(alpha: 0.02),
                      child: Text("示例图加载失败", style: TextStyle(fontSize: 11, color: theme.hintColor)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 通用绑定卡片
  Widget _buildBindCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: const Text(
        "所有APP统一填写规则：\n• 服务器：https://dav.jianguoyun.com/dav/\n• 账号：坚果云注册邮箱\n• 密码：生成的第三方应用密码\n\n可选子目录分类（推荐）：\n示例播放器专用：https://dav.jianguoyun.com/dav/purelive/\n填写后云端自动创建文件夹，文件分类不乱",
        style: TextStyle(fontSize: 13.5, height: 1.6),
      ),
    );
  }

  // 问题卡片
  Widget _buildTroubleShootCard(BuildContext context, ThemeData theme) {
    final List<Map<String, String>> qaList = [
      {"q": "1.提示账号密码错误？", "a": "用户名必须填注册邮箱，禁止手机号；密码为16位应用密码，不能填登录密码"},
      {"q": "2.浏览器打开WebDAV地址解析失败？", "a": "正常拦截！WebDAV为接口协议，仅软件调用、不支持浏览器访问，不影响APP绑定；检查末尾斜杠/、关闭代理"},
      {"q": "3.无法上传、同步失败？", "a": "免费每月1G上传流量用完次月刷新；关闭全局代理/VPN；确认应用权限为读写"},
      {"q": "4.连接超时频繁断开？", "a": "更换DNS：114.114.114.114 / 223.5.5.5；核对地址末尾必须带/"},
      {"q": "5.关闭授权/重置密码？", "a": "网页端第三方应用管理删除对应应用，授权立刻失效，需重新生成密码绑定"},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: qaList
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["q"]!,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 5),
                    Text(item["a"]!, style: TextStyle(fontSize: 12.5, height: 1.5, color: theme.hintColor)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // 总结卡片
  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: const Text(
        "WebDAV 地址：https://dav.jianguoyun.com/dav/\n账号：坚果云注册邮箱\n密码：网页端生成的第三方应用密码",
        style: TextStyle(fontSize: 13.5, height: 1.6),
      ),
    );
  }

  // 分割线
  Widget _divider() => Divider(height: 0.6, thickness: 0.6, indent: 16, endIndent: 16);

  // 统一卡片样式
  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08), width: 0.5),
    );
  }
}
