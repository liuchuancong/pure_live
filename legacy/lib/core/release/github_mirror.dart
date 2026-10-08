class GitHubMirror {
  final String owner;
  final String repo;
  final String branch;

  GitHubMirror({required this.owner, required this.repo, this.branch = 'master'});

  String rawUrl(String filePath) {
    return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$filePath';
  }

  /// jsdelivr CDN
  String jsdelivr(String filePath) {
    return 'https://cdn.jsdelivr.net/gh/$owner/$repo@$branch/$filePath';
  }

  String jsdelivrFastly(String filePath) {
    return 'https://fastly.jsdelivr.net/gh/$owner/$repo@$branch/$filePath';
  }

  static const List<String> _rawPrefixes = [
    'https://cdn.gh-proxy.org/',
    'https://edgeone.gh-proxy.org/',
    'https://hk.gh-proxy.org/',
    'https://gh.noki.eu.org/',
    'https://gh-proxy.com/',
    'https://slink.ltd/',

    'https://ghproxy.link/',
    'https://gh-proxy.net/',
    'https://gitproxy.click/',
    'https://v6.gh-proxy.org/',

    'https://ghproxy.net/',
    'https://wget.la/',
    'https://gh.catmak.name/',
    'https://g.blfrp.cn/',
  ];

  List<String> mirrors(String filePath) {
    final raw = rawUrl(filePath);

    return List.unmodifiable({
      raw,

      for (final prefix in _rawPrefixes) '$prefix$raw',

      'https://raw.kkgithub.com/$owner/$repo/$branch/$filePath',

      // CDN
      jsdelivr(filePath),
      jsdelivrFastly(filePath),
    });
  }
}
