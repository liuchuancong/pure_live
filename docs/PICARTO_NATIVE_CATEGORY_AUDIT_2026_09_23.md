# Picarto 官网动态分类与原生分页（2026-09-23）

## 来源与生产观察

- 官网[直播分类入口](https://picarto.tv/explore/categories)的当前脚本从 `https://ptvintern.picarto.tv/api/languages-categories` 读取直播分类，而不是把视频分类或旧的全站类目硬编码进客户端。2026-09-23 匿名响应包含 26 个直播分类；这一数字是当时快照，不固定为产品承诺。
- 官网分类路由形如[示例 Furry](https://picarto.tv/explore/categories/8/Furry)。当期脚本对 `/api/explore` 使用 `filter_params[categories]=8: true`、`filter_params[adult]=false`、`filter_params[languages]=`、`type=stream`、按 viewers 降序。
- 匿名接口探针中，公开目录返回 `total=54`；分类 8 返回 `total=8`、分类 33 返回 `total=2`，分类 ID 与返回房间类别一致。分类 22 在当前成人过滤下 `total=0`；分类名称可以存在而对应公开结果为空。数量会随时间变化。
- 分类元数据里的 `online_channels` 只是分类统计，客户端既不把它写入单个房间，也不当作同时在线观众数。房间 `viewers` 与详情 `total_views` 维持分开的数据口径。

## 源码合同

- `PicartoApi.categories()` 逐次读取官网直播分类元数据，验证 ID、名称、重复项和响应规模；`PicartoSite.getCategores()` 保留原公开目录入口，并追加当期官网分类。后续页为空，因为分类元数据接口一次给出全量列表。
- `directoryPage()` 接受分类身份，按官网筛选参数读取服务器原生页，返回服务器 `last_page` 对应的 `hasMore`，不以过滤后条数猜测末页。公开目录、分类目录共用严格页码/状态/成人标识检查；分类结果还逐行核对分类 ID。
- 目录保留 `adult=false` 与直播状态过滤。官网分类的标签列表与当前可播放公开流列表是不同范围；标签存在不代表此时有可展示房间。
- 搜索维持官网网页入口，远端弹幕仍按未接入呈现；本批没有扩展这两项，也没有生成新的 Android/Windows 候选。

## 回归与后续

定向覆盖官网分类响应、原生分类筛选、分页末页、畸形元数据、身份不匹配、站点入口与区域分页。原生候选集中验收时补 Android/Windows 分类进入、翻页、切换、播放与回退；旧安装包不作为这批源码的界面证据。
