# M3U

> M3U/M3U8 是 IPTV 的 Data Plugin 格式。

## 解析

- 标准 `#EXTM3U` 属性:`tvg-id` / `tvg-name` / `tvg-logo` / `group-title`。
- 条目 → Channel(ContentRef: `iptv://channel/<slug>`),分组 → Group。
- 解析容错:坏行跳过计数,不致命;编码自动探测(gbk 常见于中文列表)。
- URL 支持直链与 udpxy 中继地址;播放走统一 MediaTicket(直播语义,TTL 常为无限)。

## 管理

- 多列表并存,可启停;列表更新策略手动/自动。
- 导入来源:文件(file_picker)/URL/剪贴板/桌面拖拽(desktop_drop)。
