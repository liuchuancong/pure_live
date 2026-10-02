class GitHubMirror {
  final String owner;
  final String repo;
  final String branch;

  GitHubMirror({required this.owner, required this.repo, this.branch = 'master'});

  /// 原始地址
  String rawUrl(String filePath) {
    return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$filePath';
  }

  /// jsdelivr CDN
  String jsdelivr(String filePath) {
    return 'https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$filePath';
  }

  /// fastly CDN（jsdelivr 备用节点）
  String jsdelivrFastly(String filePath) {
    return 'https://fastly.jsdelivr.net/gh/$owner/$repo@$branch/$filePath';
  }

  /// ghproxy 风格前缀（拼在 raw 地址前面）
  /// 顺序 = 优先级，越靠前越稳
  static const List<String> _rawPrefixes = [
    // 🟢 最佳：支持 206 断点续传
    'https://cdn.gh-proxy.org/',
    'https://edgeone.gh-proxy.org/',
    'https://hk.gh-proxy.org/',
    'https://gh.noki.eu.org/',
    'https://gh-proxy.com/',
    'https://slink.ltd/',

    // 🟡 可用
    'https://ghproxy.link/',
    'https://gh-proxy.net/',
    'https://gitproxy.click/',
    'https://v6.gh-proxy.org/',

    // 🟠 仅下载可用（API 被限，raw 文件正常）
    'https://ghproxy.net/',
    'https://wget.la/',
    'https://gh.catmak.name/',
    'https://g.blfrp.cn/',
  ];

  /// 生成所有镜像（去重）
  List<String> mirrors(String filePath) {
    final raw = rawUrl(filePath);

    return List.unmodifiable({
      // 原始地址
      raw,

      // ghproxy 前缀类
      for (final prefix in _rawPrefixes) '$prefix$raw',

      // 自有格式的镜像
      'https://raw.kkgithub.com/$owner/$repo/$branch/$filePath',

      // CDN
      jsdelivr(filePath),
      jsdelivrFastly(filePath),
    });
  }
}
