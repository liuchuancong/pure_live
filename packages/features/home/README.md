# pure_live_home

> 职责:首页标签页的**声明 → 排序 → 可见性**规则,与按 App 命名的持久化。
> 具体标签页由 App 声明(`HomeTab` 列表),这里只拥有"用户的选择与声明怎么合并"。

## 模块

| 文件 | 提供 | 为什么在这一层 |
|---|---|---|
| `domain/home_tab.dart` | `HomeTab`(`defaultVisible`)、`HomeLayout`、`ArrangedHomeTab`、`HomeTabOrganizer` | 合并规则必须只有一处:设置页、长按菜单、遥控器要给出同一个结果 |
| `domain/home_layout_repository.dart` | `HomeLayoutRepository` 接口 | 排序跟账号走还是跟设备走是 App 的决定;接口在域里,UI 不认存储 |
| `domain/home_layout_service.dart` | `recordUse` / `setHidden` / `staleSavedIds` / `reset` | 两种用户意图的落点;三份实现就是"标签既被排序又被删除"的来源 |
| `data/stored_home_layout.dart` | `StoredHomeLayout`(信封 `{v,order,hidden}`、命名空间、读坏记账) | 落盘格式与迁移是本包的债 |

## 行为契约

- 保存的顺序在前,App 声明而用户没排过的标签**保持默认位置**接在其后。
- 存档里认不出的 id 忽略(标签已被删);重复 id 不会渲染两块。
- `defaultVisible: false` 的标签在用户明确打开之前不显示 —— 这是本轮修掉的缺陷:原来只有一个 `visible`
  字段,organizer 从 hidden 集合覆盖它,导致出厂隐藏的标签一跑排序就变可见。
- 隐藏是**另一个集合**,不是从 order 里删:再显示时回到原来那一行。
- `hidden` 写入前排序:两个设备做同样选择就写出同样的字节。
- 读盘不抛:坏行 → 空布局(出厂顺序)+ `onReadFailure` 记账;版本比本机新 → 不读也不改写。
- 无存档行但缺 `hidden` 字段算迁移,不算损坏(把它报成坏行会连顺序一起丢)。

## 依赖

允许:`L0`(`pure_live_storage` / `pure_live_utils`)。禁止:`features/*` 同层互依、providers 直连、App 反向依赖。

**机制复用已落地**:本包的布局行现在是 `PreferencesStore` 里的一个类型化键(`PreferenceKey<HomeLayout>`)。先前它自己实现信封,是因为机制住在 `features/settings` —— 同层,§3 禁边;2026-10-10 机制下沉到 `foundation/storage`(L0)后就没有这个理由了。旧行(信封之前的 JSON 字符串)由 `PreferenceKey.upgrade` 读回,**读不回写**:迁移磁盘形状是 `SchemaMigrator` 步骤的活,一个只是来显示布局的界面不该顺手改存储。
这份重复是架构发现,记在 [docs/roadmap/packages-rebuild-progress.md](../../../docs/roadmap/packages-rebuild-progress.md) §5,
待决策的是"把偏好机制沉到 L0/L1",不是"允许 feature 互相 import"。

## 平台矩阵

纯 Dart,Android / Android TV / Windows / iOS / web 一致;落盘经 `pure_live_storage`。

## 未验证

- **没有 App 消费者**:`apps/pure_live` 目前不装配本包(拆壳波次未完成),18 个测试是唯一的门。
- 标签的 `label` 是硬编码中文,没有走 l10n —— 等 UI 波决定"由 App 传已翻译的标签"还是"这里存 key"。
- TV 端 d-pad 重排交互未验证(那是 UI 波的事,但排序规则变更要回头改这里的契约)。
