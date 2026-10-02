import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pure_live/core/widgets/pure_live_scroll_physics.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

typedef WebDavExternalLauncher = Future<bool> Function(Uri uri);

class WebDavHelpPage extends StatelessWidget {
  const WebDavHelpPage({super.key, this.openExternalUrl});

  final WebDavExternalLauncher? openExternalUrl;

  static final Uri _officialHelpUri = Uri.parse('https://help.jianguoyun.com/?p=2064');
  static const String _davUrl = 'https://dav.jianguoyun.com/dav/';

  static const List<String> imgUrls = [
    'assets/webdav/00_home.png',
    'assets/webdav/02_register.png',
    'assets/webdav/03_login.png',
    'assets/webdav/01_avatar_menu.png',
    'assets/webdav/04_security.png',
    'assets/webdav/05_add_app.png',
    'assets/webdav/06_get_pwd.png',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final toolbarHeight = textScale <= 1.5 ? kToolbarHeight : math.min(152.0, 44 + 36 * textScale);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarHeight,
        titleSpacing: 0,
        title: Text(context.tr('webdav_help_title'), maxLines: 2, overflow: TextOverflow.ellipsis),
        elevation: 0,
      ),
      body: ListView(
        key: const ValueKey('webdav-help-scroll'),
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionTitle(context, 'webdav_help_intro_section'),
          _buildTextCard(context, 'webdav_help_intro_body'),
          const SizedBox(height: 22),
          _buildSectionTitle(context, 'webdav_help_params_section'),
          _buildParamCard(context, theme),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_register_section'),
          _buildStepCard(context, stepKey: 'webdav_help_register_steps', imgUrl: imgUrls[0], imageIndex: 1),
          const SizedBox(height: 16),
          _buildStepCard(context, stepKey: 'webdav_help_register_form', imgUrl: imgUrls[1], imageIndex: 2),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_login_section'),
          _buildStepCard(context, stepKey: 'webdav_help_login_steps', imgUrl: imgUrls[2], imageIndex: 3),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_password_section'),
          _buildStepCard(context, stepKey: 'webdav_help_account_steps', imgUrl: imgUrls[3], imageIndex: 4),
          const SizedBox(height: 16),
          _buildStepCard(context, stepKey: 'webdav_help_security_steps', imgUrl: imgUrls[4], imageIndex: 5),
          const SizedBox(height: 16),
          _buildStepCard(context, stepKey: 'webdav_help_generate_steps', imgUrl: imgUrls[5], imageIndex: 6),
          const SizedBox(height: 16),
          _buildStepCard(context, stepKey: 'webdav_help_password_once', imgUrl: imgUrls[6], imageIndex: 7),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_generic_section'),
          _buildTextCard(context, 'webdav_help_generic_body'),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_issues_section'),
          _buildTroubleshootCard(context, theme),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_limits_section'),
          _buildTextCard(context, 'webdav_help_limits_body'),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'webdav_help_summary_section'),
          _buildTextCard(context, 'webdav_help_summary_body'),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const ValueKey('webdav-help-official-link'),
            onPressed: () => _openOfficialHelp(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(context.tr('webdav_help_open_official'), textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String key) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(context.tr(key), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2)),
    );
  }

  Widget _buildTextCard(BuildContext context, String key) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(Theme.of(context)),
      child: Text(context.tr(key), style: const TextStyle(fontSize: 13.5, height: 1.6)),
    );
  }

  Widget _buildParamCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          _buildParameterRow(
            context,
            icon: Remix.links_line,
            titleKey: 'webdav_help_server_title',
            subtitle: SelectableText(
              _davUrl,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, decoration: TextDecoration.underline),
            ),
            action: IconButton(
              tooltip: context.tr('webdav_help_copy_server'),
              icon: Icon(Remix.file_copy_line, color: theme.hintColor, size: 18),
              onPressed: () => _copyServerAddress(context),
            ),
          ),
          _divider(),
          _buildParameterRow(
            context,
            icon: Remix.mail_line,
            titleKey: 'webdav_help_username_title',
            subtitle: Text(context.tr('webdav_help_username_hint'), style: const TextStyle(fontSize: 12)),
          ),
          _divider(),
          _buildParameterRow(
            context,
            icon: Remix.lock_password_line,
            titleKey: 'webdav_help_app_password_title',
            subtitle: Text(context.tr('webdav_help_app_password_hint'), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterRow(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required Widget subtitle,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
        if (!stacked) {
          return ListTile(
            leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
            title: Text(context.tr(titleKey), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: subtitle,
            trailing: action,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(titleKey),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: 8),
              subtitle,
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepCard(
    BuildContext context, {
    required String stepKey,
    required String imgUrl,
    required int imageIndex,
  }) {
    final theme = Theme.of(context);
    final steps = context.tr(stepKey).split('\n').where((line) => line.trim().isNotEmpty);
    final imageLabel = context.tr('webdav_help_screenshot_label', namedArgs: {'number': '$imageIndex'});
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(step, style: const TextStyle(fontSize: 13.5, height: 1.55)),
            ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: imageLabel,
            child: InkWell(
              key: ValueKey('webdav-help-image-$imageIndex'),
              onTap: () => _openImage(context, imgUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (context, constraints) => Image.asset(
                    imgUrl,
                    width: constraints.maxWidth,
                    height: math.min(240, math.max(140, constraints.maxWidth * 0.62)),
                    fit: BoxFit.contain,
                    semanticLabel: imageLabel,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 48,
                      alignment: Alignment.center,
                      color: theme.dividerColor.withValues(alpha: 0.02),
                      child: Text(
                        context.tr('webdav_help_image_failed'),
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootCard(BuildContext context, ThemeData theme) {
    const issues = [
      ('webdav_help_issue_credentials_q', 'webdav_help_issue_credentials_a'),
      ('webdav_help_issue_browser_q', 'webdav_help_issue_browser_a'),
      ('webdav_help_issue_upload_q', 'webdav_help_issue_upload_a'),
      ('webdav_help_issue_timeout_q', 'webdav_help_issue_timeout_a'),
      ('webdav_help_issue_revoke_q', 'webdav_help_issue_revoke_a'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(issue.$1),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr(issue.$2),
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _copyServerAddress(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _davUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('copied_to_clipboard'))));
  }

  Future<void> _openOfficialHelp(BuildContext context) async {
    var opened = false;
    try {
      opened =
          await (openExternalUrl?.call(_officialHelpUri) ??
              launchUrl(_officialHelpUri, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('external_browser_not_opened'))));
  }

  void _openImage(BuildContext context, String imgUrl) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (previewContext) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PhotoView(
                imageProvider: AssetImage(imgUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                      child: IconButton(
                        tooltip: previewContext.tr('webdav_help_close_image'),
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(previewContext),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 0.6, thickness: 0.6, indent: 16, endIndent: 16);

  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08), width: 0.5),
    );
  }
}
