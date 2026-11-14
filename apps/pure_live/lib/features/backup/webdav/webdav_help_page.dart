import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The WebDAV help page: how to get a server address, a username and a
/// dedicated app password out of Jianguoyun (the provider the reference
/// app documents), what to type into Pure Live, the usual failures and the
/// provider's limits. Seven screenshots walk the account steps; each opens
/// full size for pinching.
///
/// A wide window puts a step's text beside its screenshot; a narrow one
/// stacks them. Every row is focusable, so a TV walks the page section by
/// section.
final class WebDavHelpPage extends StatelessWidget {
  /// The page.
  const WebDavHelpPage({super.key});

  /// The official help, in Chinese, as the reference links it.
  static final Uri officialHelp = Uri.parse('https://help.jianguoyun.com/?p=2064');

  /// The DAV root every Jianguoyun account exposes.
  static const String davUrl = 'https://dav.jianguoyun.com/dav/';

  /// Above this width a step's text and screenshot sit side by side.
  static const double _wide = 720;

  static const List<String> _shots = [
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
    final t = context.t.backup.webdavHelp;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wide;
        // The reference folds into chapters a reader opens one at a time:
        // the overview and the three parameters stay open — the parameters
        // are the part a reader acts on — and the walkthrough, the failures
        // and the limits wait behind their rows.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            GuideChapter(
              icon: DsIcons.bookOpenText,
              title: t.introSection,
              initiallyOpen: true,
              children: [_Prose(t.introBody)],
            ),
            GuideChapter(
              icon: DsIcons.keyRound,
              title: t.paramsSection,
              initiallyOpen: true,
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.link),
                  title: Text(t.serverTitle),
                  description: const Text(davUrl),
                  trailing: DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.copyServer,
                    onPressed: () {
                      unawaited(Clipboard.setData(const ClipboardData(text: davUrl)));
                      showDsToast(context: context, title: t.serverCopied);
                    },
                    icon: const DsIcon(DsIcons.copy, size: 16),
                  ),
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.user),
                  title: Text(t.usernameTitle),
                  description: Text(t.usernameHint),
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.keyRound),
                  title: Text(t.appPasswordTitle),
                  description: Text(t.appPasswordHint),
                ),
              ],
            ),
            GuideChapter(
              icon: DsIcons.userRoundPlus,
              title: t.registerSection,
              children: [
                _Step(text: t.registerSteps, asset: _shots[0], index: 1, wide: wide),
                _Step(text: t.registerForm, asset: _shots[1], index: 2, wide: wide),
              ],
            ),
            GuideChapter(
              icon: DsIcons.logIn,
              title: t.loginSection,
              children: [_Step(text: t.loginSteps, asset: _shots[2], index: 3, wide: wide)],
            ),
            GuideChapter(
              icon: DsIcons.keyRound,
              title: t.passwordSection,
              children: [
                _Step(text: t.accountSteps, asset: _shots[3], index: 4, wide: wide),
                _Step(text: t.securitySteps, asset: _shots[4], index: 5, wide: wide),
                _Step(text: t.generateSteps, asset: _shots[5], index: 6, wide: wide),
                _Step(text: t.passwordOnce, asset: _shots[6], index: 7, wide: wide),
              ],
            ),
            GuideChapter(icon: DsIcons.textQuote, title: t.genericSection, children: [_Prose(t.genericBody)]),
            GuideChapter(
              icon: DsIcons.circleQuestionMark,
              title: t.issuesSection,
              children: [
                for (final (question, answer) in [
                  (t.issueCredentialsQ, t.issueCredentialsA),
                  (t.issueBrowserQ, t.issueBrowserA),
                  (t.issueUploadQ, t.issueUploadA),
                  (t.issueTimeoutQ, t.issueTimeoutA),
                  (t.issueRevokeQ, t.issueRevokeA),
                ])
                  DsListRow(
                    leading: const DsIcon(DsIcons.circleQuestionMark),
                    title: Text(question),
                    description: Text(answer),
                  ),
              ],
            ),
            GuideChapter(icon: DsIcons.shieldCheck, title: t.limitsSection, children: [_Prose(t.limitsBody)]),
            GuideChapter(
              icon: DsIcons.externalLink,
              title: t.summarySection,
              children: [
                _Prose(t.summaryBody),
                DsListRow(
                  leading: const DsIcon(DsIcons.externalLink),
                  title: Text(t.openOfficial),
                  description: Text(officialHelp.toString()),
                  showChevron: true,
                  onPressed: () => unawaited(launchUrl(officialHelp, mode: LaunchMode.externalApplication)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A paragraph (or several, newline-separated) in the body type; the chapter
/// column owns the inset, so the prose carries none of its own.
final class _Prose extends StatelessWidget {
  const _Prose(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Text(text, style: theme.typography.body.copyWith(height: 1.6));
  }
}

/// One step: its text and the screenshot that shows it. Wide: text left,
/// image right at a fixed width; narrow: text above, image below, full
/// width. The image opens full size on tap.
final class _Step extends StatelessWidget {
  const _Step({required this.text, required this.asset, required this.index, required this.wide});

  final String text;
  final String asset;
  final int index;
  final bool wide;

  static const double _thumbWidth = 280;

  @override
  Widget build(BuildContext context) {
    final t = context.t.backup.webdavHelp;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final prose = Text(text, style: theme.typography.body.copyWith(height: 1.6));
    final image = DsPressable(
      semanticLabel: t.screenshotLabel(number: index),
      onPressed: () => unawaited(_openFull(context)),
      builder: (context, states, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(
            color: states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                ? colors.accent
                : colors.border,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Padding(
              padding: const EdgeInsets.all(DsSpace.s16),
              child: Text(t.imageFailed, style: theme.typography.caption.copyWith(color: colors.textMuted)),
            ),
          ),
        ),
      ),
    );
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s16,
            children: [
              Expanded(child: prose),
              SizedBox(width: _thumbWidth, child: image),
            ],
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s12, children: [prose, image]);
  }

  Future<void> _openFull(BuildContext context) => showAppDialog<void>(
    context: context,
    builder: (context) {
      final t = context.t.backup.webdavHelp;
      return AppDialog(
        title: Text(t.screenshotLabel(number: index)),
        description: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: InteractiveViewer(maxScale: 4, child: Image.asset(asset, fit: BoxFit.contain)),
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.closeImage),
          ),
        ],
      );
    },
  );
}
