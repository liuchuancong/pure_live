import 'package:live_sites/live_sites.dart' show SiteIds;

/// What the account page can say about a stored login, and how it finds out.
///
/// Only the platforms whose adapters actually consume a login cookie have an
/// entry: bilibili, douyin, douyu, huya, kuaishou, twitch and yy are built
/// into the registry today, and cc and soop are listed for the capability a
/// sibling workstream adds. A platform left out (chzzk, acfun, youtube, …)
/// takes no cookie at all, so a stored login would tell the viewer nothing
/// about it and it has no business being on the page.
enum AccountCheckKind {
  /// Asks the platform who its stored cookie signs in (bilibili, douyin).
  online,

  /// Douyu: judged from the cookie's own session token and when it ends.
  douyu,

  /// Twitch: judged from the chat identity the cookie carries.
  twitch,

  /// Huya: judged from the account id the cookie carries.
  huya,

  /// Nothing to judge: the credential is stored exactly as it came in.
  none,
}

/// One platform of the account page.
///
/// The page's own naming and the sign-in flows come from the site registry
/// (`localizedSiteName`, `LiveAuthCapability`), so an entry carries only what
/// the registry does not know: how its login is judged, which group it is
/// listed under and whether its cookie rides on requests today.
final class AccountPlatform {
  /// Creates the catalog entry.
  const AccountPlatform({
    required this.id,
    required this.website,
    this.check = AccountCheckKind.none,
    this.overseas = false,
    this.usedByRequests = true,
  });

  /// The platform id, always one of `SiteIds`.
  final String id;

  /// Where the viewer signs in on the web: the page to open when pasting a
  /// cookie by hand.
  final Uri website;

  /// How the stored credential is judged.
  final AccountCheckKind check;

  /// Whether the row sits under the overseas platforms.
  final bool overseas;

  /// Whether the adapters send the cookie today. CC only stores it until the
  /// signed-in danmaku join lands, so its row says the login is not used yet
  /// rather than claiming an active session.
  final bool usedByRequests;

  @override
  String toString() => 'AccountPlatform($id, ${check.name})';
}

/// The platforms with an account entry, in the page's order.
final List<AccountPlatform> accountPlatforms = [
  AccountPlatform(
    id: SiteIds.bilibili,
    check: AccountCheckKind.online,
    website: Uri.https('passport.bilibili.com', '/login'),
  ),
  AccountPlatform(id: SiteIds.douyu, check: AccountCheckKind.douyu, website: Uri.https('www.douyu.com', '/')),
  AccountPlatform(id: SiteIds.huya, check: AccountCheckKind.huya, website: Uri.https('www.huya.com', '/')),
  AccountPlatform(id: SiteIds.douyin, check: AccountCheckKind.online, website: Uri.https('live.douyin.com', '/')),
  AccountPlatform(id: SiteIds.kuaishou, website: Uri.https('live.kuaishou.com', '/')),
  AccountPlatform(id: SiteIds.yy, website: Uri.https('www.yy.com', '/')),
  AccountPlatform(id: SiteIds.cc, website: Uri.https('cc.163.com', '/'), usedByRequests: false),
  AccountPlatform(
    id: SiteIds.twitch,
    check: AccountCheckKind.twitch,
    overseas: true,
    website: Uri.https('www.twitch.tv', '/'),
  ),
  AccountPlatform(id: SiteIds.soop, overseas: true, website: Uri.https('www.sooplive.co.kr', '/')),
];

/// The catalog entry of platform [id], or null when the page does not list
/// it.
AccountPlatform? accountPlatformOf(String id) {
  final key = id.trim().toLowerCase();
  for (final platform in accountPlatforms) {
    if (platform.id == key) return platform;
  }
  return null;
}
