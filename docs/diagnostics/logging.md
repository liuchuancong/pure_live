# Logging

> talker 装配的分级日志(L0 logging 包)。

- 分级:trace/debug/info/warning/error;默认 release 收敛到 info,诊断模式全开。
- 域道:network(经 talker_dio_logger,自动脱敏 Cookie/Token)、plugin(每插件子道)、media、sync。
- 保留策略:环形缓冲 + 按大小/天滚动;不含凭据(脱敏规则强制)。
- 设置页:日志级别、导出。
