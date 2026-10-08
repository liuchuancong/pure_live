# 环境搭建(Setup)

## 依赖

- Flutter SDK:以 `.fvmrc` 为准,经 `tool/flutterw.ps1` 调用(自动定位/校验版本)。
- melos:`dart pub global activate melos`(bootstrap 在根目录执行)。
- Android:AGP 9 + 内建 Kotlin(仓库已配置);TV 调试需 adb 设备。

## 常用命令

```powershell
tool/flutterw.ps1 pub get          # 根解析
melos bootstrap                    # 全仓链接
melos run gen                      # build_runner(按包)
melos run analyze                  # 全仓分析
melos run test                     # 全仓测试
tool/check_architecture.dart       # 依赖护栏
```

## 注意

- 重命令受 `tool/build_resource_guard.ps1` 约束:一次一个重任务。
- 生成物折中:drift/hive 生成物入库;riverpod/freezed 由 CI 生成(本地开发需先 `melos run gen`)。
