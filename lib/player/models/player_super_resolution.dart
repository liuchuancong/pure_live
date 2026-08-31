enum SuperResolutionMode {
  off(
    storageValue: 1,
    nameEn: 'Off',
    nameZh: '关闭',
    descriptionEn: 'Disable super resolution by default',
    descriptionZh: '默认禁用超分辨率',
  ),

  efficiency(
    storageValue: 2,
    nameEn: 'Efficiency',
    nameZh: '效率档',
    descriptionEn: 'Enable Anime4K-based super resolution by default (efficiency priority)',
    descriptionZh: '默认启用基于 Anime4K 的超分辨率（效率优先）',
  ),

  quality(
    storageValue: 3,
    nameEn: 'Quality',
    nameZh: '质量档',
    descriptionEn: 'Enable Anime4K-based super resolution by default (quality priority)',
    descriptionZh: '默认启用基于 Anime4K 的超分辨率（质量优先）',
  );

  const SuperResolutionMode({
    required this.storageValue,
    required this.nameEn,
    required this.nameZh,
    required this.descriptionEn,
    required this.descriptionZh,
  });

  final int storageValue;

  final String nameEn;
  final String nameZh;

  final String descriptionEn;
  final String descriptionZh;

  static SuperResolutionMode fromStorageValue(int value) {
    return SuperResolutionMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => SuperResolutionMode.off,
    );
  }
}
