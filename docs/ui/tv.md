# TV(电视形态)

> Android TV 的体验层;核心业务(repository/生态)与手机完全共享。

## 专项

- **DPad 焦点树**:全页面焦点可达、焦点记忆、dpad 库接入;遥控键位映射(OK/返回/菜单)。
- **Leanback 式布局**:大卡片网格、横向行导航、焦点缩放动效。
- **文字输入**:远距输入差 → 二维码登录为主、语音搜索(系统能力)预留、`android_tv_text_field`(AGP9 补丁,待引入)。
- **背景**:低干扰纯色/静态图优先;焦点态高亮用令牌。
- **性能**:低端盒子降级策略(adaptive 输出)。

## 边界

TV 只属于 Experience 层;`pure_live_TV` 未来作为第二宿主复用全部 repository/services,不复制业务(见 [../architecture/runtime.md](../architecture/runtime.md))。
