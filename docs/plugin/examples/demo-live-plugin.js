/* PureLive-Plugin-Manifest
{
  "id": "purelive.demo.js",
  "name": "Demo 直播源 (JS)",
  "version": "1.0.0",
  "apiVersion": 1,
  "runtime": "js",
  "capabilities": ["live", "search"],
  "permissions": ["network"]
}
*/
//
// The example plugin from docs/plugin/js-plugin.md, importable as-is:
// 设置 -> 插件管理 -> 导入,然后打开开关。首页会出现这个源的分节。
// Every request goes through the host's PluginNetwork (allowlist, timeout,
// size limits); kv is namespaced to this plugin; no other host surface exists.

PureLive.registerPlugin({
  manifest: { id: 'purelive.demo.js', name: 'Demo 直播源 (JS)' },

  live: {
    async browse(query) {
      const page = (query && query.page && query.page.page) || 1;
      const rooms = [
        { id: 'room-01', title: '一起看 · 重构进行时', nick: '纯度 100', area: '一起看' },
        { id: 'room-02', title: '深夜电波电台', nick: '阿波', area: '唱见' },
        { id: 'room-03', title: '像素风独立游戏通关', nick: '像素君', area: '游戏' },
        { id: 'room-04', title: '手冲咖啡研究所', nick: '豆子老师', area: '生活' },
      ];
      if (page > 1) {
        return { items: [], page: page, hasMore: false };
      }
      return {
        items: rooms.map(function (room) {
          return {
            ref: { sourceId: 'purelive.demo.js', contentId: room.id, kind: 'liveRoom' },
            title: room.title,
            subtitle: room.nick + ' · ' + room.area,
          };
        }),
        page: 1,
        hasMore: false,
      };
    },

    async detail(ref) {
      return {
        summary: {
          ref: ref,
          title: '直播间 ' + ref.contentId,
          subtitle: 'Demo 直播源 (JS)',
        },
        description: '示例插件的房间详情',
      };
    },

    async resolve(ref) {
      // The room count proves the plugin actually ran, and the test stream is
      // a public asset: the point is the plumbing, never the content.
      const seen = (await PureLive.kv.get('resolveCount')) || 0;
      await PureLive.kv.set('resolveCount', seen + 1);
      await PureLive.log('info', 'resolving ' + ref.contentId + ' (count ' + (seen + 1) + ')');
      return {
        ticket: {
          id: 'purelive.demo.js/' + ref.contentId,
          uri: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          kind: 'vod',
          protocol: 'hls',
          createdAt: new Date().toISOString(),
          refresh: { supported: false },
          metadata: { isLive: false },
        },
      };
    },

    async refresh(expired) {
      return { ticket: expired };
    },
  },

  search: {
    async search(query) {
      const keyword = (query && query.keyword) || '';
      const page = await PureLive.http({
        method: 'GET',
        url: 'https://httpbin.org/json',
        timeoutMs: 8000,
      });
      await PureLive.log('info', 'search "' + keyword + '" via ' + page.finalUri + ' -> ' + page.statusCode);
      return { items: [], page: (query.page && query.page.page) || 1, hasMore: false };
    },
  },
});
