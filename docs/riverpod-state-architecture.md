
# PureLive 状态管理架构方案

> **最终决策：直接使用 Riverpod，不自建 `live_state` 状态管理封装层。**
>
> 适用范围：PureLive Flutter 多平台应用及其业务模块。

## 1. 设计目标

PureLive 使用 Riverpod 作为状态管理和依赖注入基础设施，使用 `riverpod_generator` 生成 Provider 代码。

业务模块直接编写状态和业务逻辑，不再通过自建的 `LiveStateManager`、`BaseController<T>`、`LiveAsyncController<T>` 等通用抽象转发 Riverpod API。

### 核心原则

1. **优先使用官方能力**：状态管理、依赖注入、Provider 生命周期和代码生成由 Riverpod 负责。
2. **业务逻辑就近组织**：状态与它服务的业务功能放在同一个 feature 中。
3. **只抽取真实重复的能力**：抽取具体业务能力或 UI 组件，不为了统一而创建通用状态管理框架。
4. **依赖方向清晰**：UI 调用业务状态；业务状态调用 Repository / Service；数据访问层不依赖 Flutter 页面。
5. **生命周期明确**：页面状态、功能级状态和应用级服务分别管理，尤其保护播放器与插件运行时资源。
6. **可测试优先**：通过 Provider overrides 替换依赖，避免用全局可变单例隐藏依赖。
7. **渐进式拆分**：简单功能不强制采用完整的 Clean Architecture 四层目录。

## 2. 技术选型

| 能力 | 方案 | 决策 |
|---|---|---|
| 状态管理与依赖注入 | `flutter_riverpod` | 直接使用 |
| Provider 代码生成 | `riverpod_annotation` + `riverpod_generator` | 强制使用生成式声明 |
| 代码生成工具 | `build_runner` | 统一生成流程 |
| 不可变状态模型 | `freezed` | 复杂状态按需使用 |
| JSON 序列化 | `json_serializable` | 按模型需求使用 |
| UI 状态展示 | Flutter 与现有设计系统 | 重复时才抽取组件 |
| 数据访问 | Repository / Service | 按实际职责组织 |

版本号以 PureLive workspace 中经过验证的依赖组合为准。不要未经验证就混用 Riverpod 主包、注解包和生成器的大版本。

## 3. 推荐的依赖方向

```text
Feature Presentation
        |
        v
Feature Application
(Riverpod Providers / Notifiers)
        |
        v
Feature Domain (按需设置)
        |
        v
Feature Data
(Repository / API / Database)
        |
        v
Platform / External Packages
```

职责约定：

- **Presentation**：负责页面、组件、用户交互和状态展示。
- **Application**：负责 Provider、Notifier、业务状态和操作流程编排。
- **Domain**：仅在业务规则复杂、需要独立建模时引入。
- **Data**：负责数据读取、写入、网络和数据库适配。
- **Platform**：负责文件、路径、系统信息、插件运行时等独立的平台能力。

Repository 不负责弹窗、导航或 Widget 生命周期。

## 4. 目录组织

以功能模块为中心组织 Provider，不建立一个汇集全项目状态的巨大全局目录。

```text
apps/pure_live/lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── app_providers.dart
│
└── features/
    ├── live/
    │   ├── data/
    │   │   └── channel_repository.dart
    │   ├── application/
    │   │   ├── channels_provider.dart
    │   │   └── channel_filter_provider.dart
    │   └── presentation/
    │       ├── channel_list_page.dart
    │       └── widgets/
    │
    ├── player/
    │   ├── data/
    │   ├── application/
    │   └── presentation/
    │
    ├── plugins/
    │   ├── data/
    │   ├── application/
    │   └── presentation/
    │
    └── settings/
        ├── data/
        ├── application/
        └── presentation/
```

目录规则：

- 小功能可以直接在 feature 目录中组织少量文件，不要求一次创建所有层。
- Provider 文件按业务对象或用途命名，例如 `channels_provider.dart`。
- 不建立没有实际职责的 `controllers/`、`managers/` 或 `common_state/` 目录。
- `app_providers.dart` 只放真正的应用级依赖，不集中存放所有业务状态。
- 当数据访问或领域规则变复杂时，再拆分对应目录。

## 5. Provider 编写规范

### 5.1 查询数据

使用函数式 `@riverpod` 声明数据来源。

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'channels_provider.g.dart';

@riverpod
Future<List<Channel>> channels(Ref ref) {
  final repository = ref.watch(channelRepositoryProvider);
  return repository.fetchChannels();
}
```

约定：

- Provider 通过 Repository 获取业务数据。
- 使用 `ref.watch` 声明需要跟随变化的依赖。
- 异步结果使用 `AsyncValue` 表达加载、成功和失败状态。
- 重试优先使用 `ref.invalidate` 或相应 Provider 的刷新机制。
- 只有确实需要共享或保留结果时，才调整自动销毁策略。

### 5.2 可变业务状态

使用生成式 `Notifier` 管理需要显式修改的业务状态。

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'channel_filter_provider.g.dart';

@riverpod
class ChannelFilter extends _$ChannelFilter {
  @override
  ChannelFilterState build() {
    return const ChannelFilterState();
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  void reset() {
    state = const ChannelFilterState();
  }
}
```

约定：

- 状态变更通过具备业务含义的方法完成。
- 复杂的不可变状态可以使用 Freezed。
- Widget 不负责编排复杂的状态转换。
- 简单的局部 UI 状态，例如弹窗展开状态，应优先留在 Widget 内。
- 不为每个 Notifier 创建自定义基类。

### 5.3 异步业务操作

对于配置导入、设置保存、刷新资源等操作：

- Notifier 负责业务流程与可观察状态。
- Repository 负责实际数据访问和持久化。
- 明确重复提交、取消、错误分类和成功后的数据刷新策略。
- 不设计带有大量可选参数的万能异步执行器。
- 只有相同策略在多个业务中稳定重复时，才抽取具体 helper 或服务。

### 5.4 UI 消费状态

页面直接使用 `ConsumerWidget`、`ConsumerStatefulWidget`、`ref.watch` 和 `ref.read`。

```dart
class ChannelListPage extends ConsumerWidget {
  const ChannelListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(channelsProvider);

    return result.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(channelsProvider),
      ),
      data: (items) => ChannelListView(channels: items),
    );
  }
}
```

实际项目应使用 PureLive 现有的设计系统组件，统一加载、错误、空数据和成功状态的视觉表现。

## 6. 生命周期策略

### 页面级状态

- 默认使用生成器对应的自动销毁行为。
- 页面离开后不再需要的筛选条件、临时表单和短期查询应允许释放。
- 不要仅为了避免重新请求而无条件使用 `keepAlive`。

### 功能级共享状态

- 多个页面确实需要共享状态时，使用合适的上层 Provider 管理。
- 明确共享范围、失效条件和重新加载时机。
- 多个 Widget 使用同一状态，不代表该状态必须永久存活。

### 应用级服务

- 配置、数据库连接、Repository、插件协调器等服务应有明确的创建与销毁位置。
- 使用 Provider 组合依赖，不通过隐藏的全局可变单例传递依赖。
- 对需要显式释放的资源，明确其所有者和释放责任。

### 播放器与插件运行时

- 播放器控制器、播放会话和插件执行环境可能长于单个页面的生命周期。
- 页面 Provider 不应意外关闭仍在使用的播放会话。
- `keepAlive` 不能替代资源所有权设计。
- 插件任务、订阅、文件句柄和后台任务应提供明确的取消或释放路径。

## 7. 错误与加载状态

先使用 Riverpod 原生 `AsyncValue`，再结合 PureLive 的设计系统。

- 区分加载、错误、空数据和成功状态。
- 对可恢复错误提供合理的重试方式。
- 区分用户可理解的业务错误与开发诊断信息。
- 不要把所有错误简单转换为字符串后丢失异常和堆栈。
- 全局错误分类、日志和通知只有在确实需要跨模块统一时才抽取。
- Repository 不负责弹出 SnackBar、显示对话框或执行页面导航。

## 8. 依赖注入与测试

依赖通过 Provider 提供，并在测试中使用 overrides 替换。

至少覆盖以下场景：

1. 查询成功、失败与空数据。
2. Notifier 状态变化和业务操作。
3. Repository 的失败场景。
4. 业务支持时的重复提交、取消和重试。
5. 页面离开后的资源释放。
6. 播放器和插件运行时等长生命周期资源的所有权与清理。

测试约定：

- 验证业务行为，而不是 Riverpod 内部实现细节。
- 网络和文件访问应可替换，避免单元测试依赖真实外部服务。
- 生命周期测试应明确等待异步任务和销毁过程。
- 优先覆盖业务分支和风险边界，不为每个 Provider 编写没有额外价值的重复测试。

## 9. 代码生成与工程规范

- 业务 Provider 优先使用 `riverpod_annotation` 的生成式声明。
- `.g.dart` 文件由 `build_runner` 管理，禁止手工编辑。
- 在 CI 中执行代码生成检查、静态分析和测试。
- Monorepo 应统一生成命令的执行入口。
- 运行时、注解包和生成器版本必须通过依赖解析、生成、分析和测试验证。
- 保持官方 API 的可读性，不通过大量别名或代理方法隐藏 `watch`、`read` 和 `invalidate`。

建议 CI 至少执行：

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

根据 workspace 结构调整命令的执行位置。代码生成检查也应加入 CI，例如在干净工作区执行生成命令，并确认没有未提交的生成差异。

## 10. 明确不做的事情

- 不创建 `live_state` 包来转发 Riverpod API。
- 不创建万能 `BaseController<T>` 或多层继承的状态基类。
- 不为每个 Provider 再定义一套自有注解。
- 不为了减少一两行代码而隐藏官方 API。
- 不强制每个功能采用完整的四层架构。
- 不把所有 Provider 集中到全局目录。
- 不把短暂的 Widget 状态全部提升到应用级状态管理。
- 不以 `keepAlive` 作为解决缓存、生命周期或资源所有权问题的通用手段。
- 不提前建立通用命令总线、事件总线或状态管理 DSL。

## 11. 何时抽取公共能力

只有满足以下条件时，才考虑新增公共 helper、组件或基础设施包：

1. 存在多个真实使用场景，而不是预想中的未来需求。
2. 重复行为具有稳定、清晰的语义。
3. 抽取后能减少重复代码或降低错误率。
4. 不引入更复杂的配置、隐式生命周期或难以测试的行为。
5. 能通过测试证明抽取后的行为一致。

优先抽取具体能力，例如：

- 统一的异步内容展示组件。
- 明确的请求错误分类与日志策略。
- 具有清晰所有权的播放器会话管理。
- 插件运行时的任务取消和资源释放。
- 可复用的配置导入、校验与迁移服务。

不要先创建通用框架，再寻找业务来使用它。

## 12. 落地计划

### 阶段一：确立基础规范

- 固定经过验证的 Riverpod、注解包和生成器版本组合。
- 统一 Provider 命名、文件命名和生成流程。
- 明确页面级、功能级、应用级资源的生命周期规则。
- 将格式化、静态分析、生成检查和测试接入 CI。

### 阶段二：选择一个真实功能验证

选择频道列表或配置导入等复杂度适中的功能：

- 使用生成式 Provider。
- 通过 Repository 访问数据。
- 用 `AsyncValue` 表达异步状态。
- 使用 Provider overrides 编写测试。
- 检查页面退出后的状态与资源释放。

### 阶段三：推广规范

- 将验证有效的模式应用到直播、点播、插件、音乐和设置模块。
- 只把真实重复的 UI 状态展示抽成组件。
- 不要求所有模块使用完全相同的目录层级，但要求依赖方向和生命周期约定一致。

### 阶段四：按实际问题优化

- 通过代码评审和测试发现重复模式。
- 优先抽取具体能力。
- 只有简单 helper、组件或服务无法解决实际问题时，才考虑更高层抽象。

## 13. 最终决策摘要

- **状态管理：** Riverpod 原生能力。
- **代码生成：** `riverpod_generator`。
- **模型：** 按需使用 Freezed 与 JSON 序列化。
- **业务逻辑：** 放在所属 feature 内，由 Provider / Notifier 协调 Repository 和服务。
- **UI：** 直接消费 Provider，复用现有设计系统。
- **公共抽象：** 只抽取有真实重复和独立职责的能力。
- **生命周期：** 明确区分页面状态、共享业务状态和长生命周期资源。
- **架构策略：** 先保持简单，通过真实业务与测试逐步演进。

> **一句话总结：不再二次封装 Riverpod；统一使用方式、业务边界和生命周期规范。把架构投入留给 PureLive 真正复杂的领域能力。**
