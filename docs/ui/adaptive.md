# Adaptive(自适应)

> TV/手机/桌面的布局策略层:把"这是什么设备/什么输入方式"变成布局决策,feature 只消费决策。

## 输出

- 布局形态:单列/双列/侧栏/Leanback 网格
- 输入行为:触屏手势 / DPad 焦点树 / 鼠标 hover+滚轮 / 键盘快捷键
- 密度与字号:大屏低密度、TV 远视距离大字号
- 能力降级:低性能设备背景降级、动效简化

## 规则

- 业务层不出现平台判断(`Platform.isXxx` 禁止出现在 feature/domain);判断收敛在 adaptive 与 platform。
- TV 专属(DPad 焦点/遥控键位映射)在此实现,dpad 库接入;不得污染 Provider/Repository。
- 断点与令牌对齐(wind breakpoints 同源,避免两套断点漂移)。
