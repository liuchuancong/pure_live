# UI Kit

> 语义组件库:**唯一允许 import fluttersdk_wind 的包**(wind 断供时唯一替换点)。

## 组件方向

`LiveRoomCard` / `ContentCard` / `FeedSectionView` / `PlayerControlBar` / `QualityLineMenu` / `SettingSection` / `SettingSlider` / `EmptyPlaceholder` / `SearchBar` / `ChannelRow` / `DanmakuToggle` …(随域实现增长)

## 规则

- 组件只暴露 Dart 参数 + design 运行时令牌;内部用 wind className 实现——复杂样式收敛在 ui_kit,页面不裸写长 className。
- 输入输出全部是统一模型(ContentItem/FeedItem/SearchItem),**不含路由、不含业务 provider**(I4)。
- 插件不直接控制 UI:插件输出领域模型 → UI Model → ui_kit 渲染(见 [../plugin/plugin-overview.md](../plugin/plugin-overview.md)),保证生态观感一致。
- 组件有 golden 测试(明暗两套主题)。
