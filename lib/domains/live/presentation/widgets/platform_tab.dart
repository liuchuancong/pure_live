import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

/// Logo size inside a platform tab or chip.
const double kPlatformLogoSize = 18;

/// One platform's logo, rounded and sized for a tab strip or a chip.
///
/// A missing asset falls back to a neutral icon instead of Flutter's red error
/// box: the platform list is compiled in, but artwork can lag behind a newly
/// added site.
class PlatformLogoAsset extends StatelessWidget {
  const PlatformLogoAsset({super.key, required this.asset, this.size = kPlatformLogoSize});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (asset.isEmpty) return Icon(Icons.live_tv_rounded, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.live_tv_rounded, size: size),
      ),
    );
  }
}

/// [PlatformLogoAsset] for a resolved platform.
class PlatformLogo extends StatelessWidget {
  const PlatformLogo({super.key, required this.site, this.size = kPlatformLogoSize});

  final Site site;
  final double size;

  @override
  Widget build(BuildContext context) => PlatformLogoAsset(asset: site.logo, size: size);
}

/// A platform tab: the platform's logo followed by its name. Every platform
/// selector builds this one widget.
class PlatformTab extends StatelessWidget {
  const PlatformTab({super.key, required this.site});

  final Site site;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlatformLogo(site: site),
          const SizedBox(width: 6),
          Text(site.name),
        ],
      ),
    );
  }
}
