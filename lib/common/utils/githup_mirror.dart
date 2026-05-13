class GitHubMirror {
  final String owner;
  final String repo;
  final String branch;

  GitHubMirror({required this.owner, required this.repo, this.branch = 'master'});

  /// 单个文件路径生成
  String rawUrl(String filePath) {
    return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$filePath';
  }

  /// jsdelivr CDN
  String jsdelivr(String filePath) {
    return 'https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$filePath';
  }

  /// fastly CDN
  String jsdelivrFastly(String filePath) {
    return 'https://fastly.jsdelivr.net/gh/$owner/$repo@$branch/$filePath';
  }

  /// 生成所有镜像
  List<String> mirrors(String filePath) {
    final raw = rawUrl(filePath);
    return [
      raw,
      'https://raw.kkgithub.com/$owner/$repo/$branch/$filePath',
      'https://wget.la/$raw',
      'https://ghproxy.net/$raw',
      'https://ghfast.top/$raw',
      'https://gh.catmak.name/$raw',
      'https://g.blfrp.cn/$raw',

      // CDN
      jsdelivr(filePath),
      jsdelivrFastly(filePath),
    ];
  }
}
