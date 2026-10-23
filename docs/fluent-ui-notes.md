# fluent_ui 用法速查(PureLive v4 UI 统一重构)

> **示例仓库**:`C:\Users\m1779\Downloads\fluent_ui-master\fluent_ui-master`
> ——下文所有 `example/lib/...`、`lib/src/...` 引用均相对该目录;行号对应该快照。
>
> **方案文档**:`C:\Users\m1779\Downloads\purelive-v4-ui-architecture.md`
>
> 所有 API 与代码片段均摘自上述示例仓库,未引入其中不存在的 API。

---

## 1. 应用根与主题

### FluentApp — 应用根 Widget(替代 MaterialApp)

`FluentApp(title: , theme: , darkTheme: , themeMode: , builder: , home: , locale: )`。
`theme` 与 `darkTheme` 各传一份 `FluentThemeData`;`builder` 里可包 `Directionality`/`NavigationPaneTheme`/`MediaQuery` 等全局包装;`color` 设窗口色。

```dart
FluentApp(
  title: appTitle,
  themeMode: appTheme.mode,
  color: appTheme.color,
  darkTheme: FluentThemeData(brightness: Brightness.dark, /* ... */),
  theme: FluentThemeData(/* ... */),
  locale: appTheme.locale,
  builder: (context, child) => Directionality(
    textDirection: appTheme.textDirection,
    child: child!,
  ),
  home: const MyHomePage(),
)
```

参考:`example/lib/main.dart:87-135`;定义在 `lib/src/fluent_app.dart:39`。

### FluentThemeData — 主题数据构造

常用参数:`brightness` / `accentColor` / `visualDensity` / `focusTheme` / `fontFamily`。
`accentColor` 收 `AccentColor` 类型(不是单个 `Color`);`fontFamily` 设全局字体。

```dart
FluentThemeData(
  brightness: Brightness.dark,
  accentColor: appTheme.color,
  visualDensity: appTheme.visualDensity,
  focusTheme: FocusThemeData(glowFactor: is10footScreen(context) ? 2.0 : 0.0),
  fontFamily: kIsWeb ? 'Segoe UI' : null,
)
```

参考:`example/lib/main.dart:92-108`;定义在 `lib/src/styles/theme.dart:261`(字体相关 `423-454`)。

### FluentTheme.of(context) — 读取当前主题

取 `brightness`、`typography`、`accentColor`、`scaffoldBackgroundColor`、`micaBackgroundColor` 等:

```dart
final theme = FluentTheme.of(context);
Text('Theme mode', style: theme.typography.subtitle),
```

参考:`example/lib/main.dart:176`、`example/lib/screens/settings.dart:97`。

### FluentApp.themeMode — 深浅色切换

`themeMode` 设 `ThemeMode.dark` / `ThemeMode.light`(`ThemeMode.system` 为默认,见 `example/lib/theme.dart:16`)。开关钮本身用 `ToggleButton`,选中态由 `theme.brightness == Brightness.dark` 推出:

```dart
ToggleButton(
  checked: theme.brightness == Brightness.dark,
  onChanged: (v) => appTheme.mode = v ? ThemeMode.dark : ThemeMode.light,
  child: const Icon(WindowsIcons.lightbulb, size: 16),
)
```

参考:`example/lib/main.dart:215-226`。

### SystemTheme.accentColor.load() — 加载系统强调色

启动时在 `main()` 里加载 Windows 系统强调色(包内来自 `system_theme` 插件):

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    SystemTheme.accentColor.load();
  }
  runApp(const MyApp());
}
```

参考:`example/lib/main.dart:32-44`。

### SystemTheme.accentColor.accent — 读取(经平台守卫助手)

`accentColor.accent` 是纯字段读,不抛异常;但 `load()` 完成前(或读取失败时)返回
插件 fallback 色(`kDefaultFallbackColor = 0xFF00B7C3`)而非 null,所以「取系统强调色」
要包一层平台守卫助手,由助手决定无色可取时返回 null:

```dart
Color? readSystemAccentColor() {
  if (!Platform.isWindows) {
    return null;
  }
  return SystemTheme.accentColor.accent;
}
```

要点:`load()` 内部自带 `MissingPluginException` 捕获,不支持的平台上静默保持
fallback;`SystemTheme.onChange` 流只在 Windows/macOS 推送,且是就地改字段、不
触发 widget 重建,需要界面跟随得自己接状态层。本仓库落点:
`apps/pure_live/lib/system/theme/ui_configuration_mapper.dart` 的
`readSystemAccentColor()`,取色优先级为 动态取色 > 存储强调色 > 系统强调色 > null。

参考:包源码 `system_theme-3.3.0/lib/system_theme.dart:75-76, 134-142, 150-175`。

### AccentColor.swatch({...}) — 手工构造强调色

用 `darkest → lightest` 七档色阶构造;可包装 `SystemTheme.accentColor`,也用于主题间插值:

```dart
AccentColor get systemAccentColor => AccentColor.swatch({
  'darkest': SystemTheme.accentColor.darkest,
  'darker':  SystemTheme.accentColor.darker,
  'dark':    SystemTheme.accentColor.dark,
  'normal':  SystemTheme.accentColor.accent,   // 主色在 normal 档
  'light':   SystemTheme.accentColor.light,
  'lighter': SystemTheme.accentColor.lighter,
  'lightest': SystemTheme.accentColor.lightest,
});
```

参考:`example/lib/theme.dart:84-97`。

### Colors.accentColors — 内置强调色列表

包内内置的强调色列表(`lib/src/styles/color.dart:228`),直接遍历给用户选色:

```dart
...List.generate(Colors.accentColors.length, (index) {
  final color = Colors.accentColors[index];
  return Tooltip(message: name, child: _buildColorBlock(appTheme, color));
})
```

参考:`example/lib/screens/settings.dart:251`。

### accentColor.defaultBrushFor(brightness) — 强调色画刷

按亮暗主题取强调色画刷,给文本/图标着色:亮色主题返回 `dark` 档、暗色主题返回 `lighter` 档(`lib/src/styles/color.dart:347-352`);另有 `secondaryBrushFor`(0.9 alpha)。

```dart
final color = appTheme.color.defaultBrushFor(theme.brightness);
```

参考:`example/lib/main.dart:250`。

## 2. 导航骨架(NavigationView)

### NavigationView — 应用骨架

`NavigationView(pane: , titleBar: , onOpenSearch: )`:导航面板 + 内容区 + TitleBar。`onOpenSearch` 可直接接 `searchFocusNode.requestFocus` 响应搜索快捷键。

```dart
NavigationView(
  key: viewKey,
  titleBar: TitleBar(icon: ..., title: ..., content: AutoSuggestBox(...)),
  pane: NavigationPane(/* ... */),
  onOpenSearch: searchFocusNode.requestFocus,
)
```

参考:`example/lib/main.dart:177-480`(`onOpenSearch` 在 479)。

### NavigationPane — 侧边栏定义

`selected` + `onChanged` 驱动页面切换(索引存 `State`,`onChanged` 里 `setState`)。构造参数还包括 `header`、`items`、`footerItems`、`displayMode`(默认 `PaneDisplayMode.auto`)、`autoSuggestBox` / `autoSuggestBoxReplacement`、`indicator`(默认 `StickyNavigationIndicator`)、`toggleable` 等,见 `lib/src/controls/navigation/navigation_view/pane.dart:101-140`。

```dart
NavigationPane(
  selected: _index,
  onChanged: (index) => setState(() => _index = index),
  header: SizedBox(height: kOneLineTileHeight, child: ...),
  displayMode: appTheme.displayMode,
  items: [ /* PaneItem / PaneItemHeader / PaneItemExpander ... */ ],
  footerItems: [PaneItemSeparator(), PaneItem(icon: ..., title: ..., body: ...)],
)
```

参考:`example/lib/main.dart:240-478`。

### PaneDisplayMode — 面板显示模式

`top` / `expanded` / `compact` / `minimal` / `auto` 五种(`lib/src/controls/navigation/navigation_view/pane.dart:35-84`)。
`auto`(默认)按窗口宽度阈值自动切换:

- 窗口 ≤640px → `minimal`(只留汉堡按钮)
- 641–1007px → `compact`(只显示图标)
- ≥1008px → `expanded`(完整展开)

阈值可用 `NavigationPane(compactModeThresholdWidth:)` / `(expandedModeThresholdWidth:)` 覆盖(显式指定 `displayMode` 时忽略阈值)。示例在设置页用 `RadioButton<PaneDisplayMode>` 遍历 `PaneDisplayMode.values` 供切换。

参考:`example/lib/screens/settings.dart:129-147`。

### NavigationView.onDisplayModeChanged — 模式变化回调

面板在展开/收起之间变化时触发,签名 `ValueChanged<PaneDisplayMode>?`(`lib/src/controls/navigation/navigation_view/view.dart:139,223`):

```dart
NavigationView(
  onDisplayModeChanged: (mode) => debugPrint('display mode changed to $mode'),
  /* ... */
)
```

参考:`example/lib/screens/navigation/navigation_view.dart:314`。

### PaneItem 家族 — 导航项

- `PaneItem(icon:, title:, body:)` — 普通导航项,`body` 为页面内容;图标用 `WindowsIcon(WindowsIcons.*)`。
- `PaneItemExpander(icon:, title:, items:, initiallyExpanded:)` — 可折叠分组。
- `PaneItemHeader(header:)` — 分组小标题;`PaneItemSeparator()` — 分隔线。
- `PaneItemAction(icon:, onTap:, ...)` — 点击执行动作、不切页面的项(不关联页面,`selectsOnInvoked` 默认 false),见 `lib/src/controls/navigation/navigation_view/pane_items.dart:789-811`。

```dart
items: [
  PaneItem(icon: const WindowsIcon(WindowsIcons.home), title: const Text('Home'), body: const HomePage()),
  PaneItemHeader(header: const Text('Controls')),
  PaneItemExpander(
    icon: const WindowsIcon(WindowsIcons.button_a),
    title: const Text('Basic input'),
    items: [
      PaneItem(title: const Text('Button'), body: inputs.ButtonPage()),
      /* ... */
    ],
  ),
],
footerItems: [
  PaneItemSeparator(),
  PaneItem(icon: const WindowsIcon(WindowsIcons.settings), title: const Text('Settings'), body: const Settings()),
],
```

参考:`example/lib/main.dart:271-477`。

### NavigationView.dataOf(context).pane?.changeTo(item) — 程序化切换

脱离 `onChanged` 直接切到某个导航项;典型配合是标题栏 `AutoSuggestBox` 搜索跳转(从 `pane.allItems` 里筛出可跳转的 `PaneItem`):

```dart
final allItems = NavigationView.dataOf(context).pane!.allItems
    .where((i) => i is PaneItem && i is! PaneItemExpander && i.body != null && i.enabled)
    .cast<PaneItem>();
AutoSuggestBox<PaneItem>(
  onSelected: (item) => NavigationView.dataOf(context).pane?.changeTo(item.value!),
  items: [
    for (final item in allItems)
      AutoSuggestBoxItem<PaneItem>(value: item, label: (item.title! as Text).data!),
  ],
)
```

参考:`example/lib/main.dart:188-210`(`changeTo` 在 199)。

## 3. 页面脚手架

### ScaffoldPage.scrollable + PageHeader — 标准页面写法

每个页面用 `ScaffoldPage.scrollable(header: PageHeader(title:), children: [...])`:标题头 + 可滚动内容列。

```dart
return ScaffoldPage.scrollable(
  header: const PageHeader(title: Text('Settings')),
  children: [ /* ... */ ],
);
```

参考:`example/lib/screens/settings.dart:94-95`。

## 4. 按钮

### Button — 标准按钮

`onPressed` 传 `null` 即禁用(外观同步变灰):

```dart
Button(onPressed: disabled ? null : () {}, child: const Text('Standard Button'))
```

参考:`example/lib/screens/inputs/button.dart:81-84`。

### FilledButton — 强调色填充按钮

用于对话框确认键 / 页面主操作:

```dart
FilledButton(child: const Text('Yes'), onPressed: () { Navigator.pop(context); /* ... */ })
```

参考:`example/lib/main.dart:494-500`;`example/lib/screens/inputs/button.dart:107`。

### IconButton + SmallIconButton — 图标按钮

`IconButton(icon:, onPressed:, autofocus:)`;需要更小尺寸时外包一层 `SmallIconButton`(它是 `InheritedWidget`,`lib/src/controls/buttons/icon_button.dart:156`,让后代 `IconButton` 走小尺寸路径,图标 20px 而非 24px):

```dart
SmallIconButton(
  child: IconButton(
    icon: const WindowsIcon(WindowsIcons.graph_symbol, size: 20.0),
    onPressed: disabled ? null : () {},
  ),
)
```

参考:`example/lib/screens/inputs/button.dart:195-206`(包装在 203)、`44-48`(`autofocus` 用法)。

### ToggleButton — 开关型按钮

外观像 Button、行为像 CheckBox:`checked` + `onChanged`。深浅色切换钮即用它实现:

```dart
ToggleButton(
  checked: toggleState,
  onChanged: disabled ? null : (v) => setState(() => toggleState = v),
  child: const Text('Toggle Button'),
)
```

参考:`example/lib/main.dart:215-226`;`example/lib/screens/inputs/button.dart:255-264`。

## 5. 对话框

### showDialog + ContentDialog — 模态对话框

`showDialog<T>()` 返回 `Future<T>`;`actions` 里 `Navigator.pop(context, 结果)` 回传值:

```dart
final result = await showDialog<String>(
  context: context,
  builder: (context) => ContentDialog(
    title: const Text('Delete file permanently?'),
    content: const Text('If you delete this file, you won\'t be able to recover it.'),
    actions: [
      Button(child: const Text('Delete'), onPressed: () => Navigator.pop(context, 'User deleted file')),
      FilledButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, 'User canceled dialog')),
    ],
  ),
);
```

参考:`example/lib/screens/popups/content_dialog.dart:76-97`。

## 6. 输入框

### TextBox — 输入框

`placeholder` / `maxLines` / `readOnly` / `controller` / `contextMenuBuilder` / `enabled`。
`maxLines: null` 即多行;外包 `InfoLabel(label:)` 加标签:

```dart
InfoLabel(
  label: 'Enter your name:',
  child: const TextBox(placeholder: 'Name'),
)
// 多行: TextBox(maxLines: null)   只读: TextBox(readOnly: true)   禁用: TextBox(enabled: false)
```

参考:`example/lib/screens/forms/text_box.dart:30-53`(InfoLabel)、`61-69`(readOnly)。

## 7. 标签页

### TabView + Tab — 标签页控件

fluent_ui 中名为 `TabView`(即 WinUI 的 TabControl)。`TabView` 参数:`tabs` / `currentIndex` / `onChanged` / `onNewPressed` / `onReorder` / `closeButtonVisibility`(收 `CloseButtonVisibilityMode`)/ `tabWidthBehavior`(收 `TabWidthBehavior`)等;`Tab` 参数:`text` / `icon` / `body` / `onClosed`,`onClosed` 里移除对应 `Tab` 并修正 `currentIndex`:

```dart
Tab generateTab(int index) {
  late Tab tab;
  tab = Tab(
    text: Text('Document $index'),
    icon: Icon(...),
    body: Container(color: ...),
    onClosed: () => setState(() {
      tabs!.remove(tab);
      if (currentIndex > 0) currentIndex--;
    }),
  );
  return tab;
}

TabView(
  tabs: tabs!,
  currentIndex: currentIndex,
  onChanged: (index) => setState(() => currentIndex = index),
  onNewPressed: () => setState(() => tabs!.add(generateTab(tabs!.length + 1))),
  onReorder: (oldIndex, newIndex) => setState(() { /* 移动并同步 currentIndex */ }),
  tabWidthBehavior: tabWidthBehavior,
  closeButtonVisibility: closeButtonVisibilityMode,
)
```

参考:`example/lib/screens/navigation/tab_view.dart:30-45`(Tab)、`243-274`(TabView)。

## 8. 焦点与快捷键

### FocusThemeData(glowFactor:) — 焦点辉光

主题级配置;示例按 `is10footScreen(context)`(10 英尺电视/大屏场景)取 `2.0`,普通桌面取 `0.0`:

```dart
FluentThemeData(
  focusTheme: FocusThemeData(glowFactor: is10footScreen(context) ? 2.0 : 0.0),
)
```

参考:`example/lib/main.dart:96-105`;`lib/src/controls/utils/focus.dart:186`。

### CallbackShortcuts — 自定义快捷键

`bindings: {SingleActivator(...): 回调}`。`TabView` 内建的 `Ctrl+T`(新建)、`Ctrl+W` / `Ctrl+F4`(关闭)、`Ctrl+1~9`(切换)即此实现;Apple 平台上 `control` 换成 `meta`,自定义快捷键可照抄:

```dart
FocusScope(
  autofocus: true,
  child: CallbackShortcuts(
    bindings: {
      SingleActivator(LogicalKeyboardKey.keyT, control: ctrl): () => onNewPressed?.call(),
      SingleActivator(LogicalKeyboardKey.keyW, control: ctrl): onClosePressed,
      SingleActivator(LogicalKeyboardKey.f4, control: ctrl): onClosePressed,
      // Ctrl+1~9 由 List.generate(9, ...) + LogicalKeyboardKey.digit1..9 生成
    },
    child: child,
  ),
)
// var ctrl = true, meta = false; 在 iOS/macOS 上 ctrl=false, meta=true
```

参考:`lib/src/controls/navigation/tab_view/tab_view.dart:705-750`。

## 9. 页面转换范式(后续页面任务统一执行)

> 试点页:`apps/pure_live/lib/features/toolbox/toolbox_page.dart`(下称「成品页」)。
> 本节引用与上文不同:除标注外均指向本仓库内文件。后续页面任务按本节执行——
> 页面内直接使用的 Material 组件逐一替换成 pure_uikit 的 Pure 组件,只动 UI 层;
> 业务逻辑、Riverpod、路由、数据访问一律不动。analyze 由脚本统一执行,不要自跑,
> 但不得留下语法错误或未使用的导入。

### 9.1 替换对照表

| Material | 换成 | 视觉/行为保持 | 成品页先例 |
|---|---|---|---|
| `Scaffold` + `AppBar` | `PureScaffold(body:, appBar: PureAppBar(title:, actions:))` | 标题走 `context.t.*`;右上动作放 `actions`(如 `SettingsEntryButton`);页体滚动列外套 `Center + ConstrainedBox(maxWidth: 720)` 的卡片列 | `apps/pure_live/lib/features/toolbox/toolbox_page.dart:287-296` |
| `TextField` | `PureTextField` | `controller` / `placeholder` / `maxLines` / `keyboardType` / `enabled` 一一对应(定义见 `pure_uikit/lib/src/styling/widgets/controls/pure_field.dart:19`);禁用态由 `enabled:` 驱动,自带变灰 | `toolbox_page.dart:401-407` |
| `SnackBar` | `PureToast.show(context, message, type:)` | `type: info/success/warning/error` 定色;挂根 Overlay、无需 Scaffold(`pure_uikit/lib/src/styling/widgets/overlays/pure_toast.dart:33-72`);页面内封一个 `_toast` 助手统一默认 `error` | `toolbox_page.dart:78-82` |
| `showDialog` | `showPureDialog<T>(context:, title:, maxWidth:, child:, actions:)` | `actions` 用**对话框的** context(`dialogContext`)构建,回值一律 `Navigator.pop(dialogContext, v)`;取消键 `PureButton(variant: ButtonVariant.ghost)`(定义见 `pure_uikit/lib/src/styling/widgets/overlays/pure_dialog.dart:37-68`) | `toolbox_page.dart:253-283` |
| `ElevatedButton` / `TextButton` | `PureButton(label:, icon:, variant:, size:, expand:, loading:)` | 主操作 `ButtonVariant.primary`、次操作 `secondary`、文字态 `ghost`;`onPressed: null` 禁用;忙态用 `loading:`(自带进度环并拒输入),不要自己换图标 | `toolbox_page.dart:414-446` |
| `IconButton` | `PureIconButton(tooltip:, icon:, size:, onPressed:)` | `tooltip` 必填(兼无障碍名);`size: ControlSize.sm` 得小号;`onPressed: null` 禁用(定义见 `pure_uikit/lib/src/styling/widgets/controls/pure_button.dart:144`) | `toolbox_page.dart:390-395` |
| `Card` | `PureCard(padding: EdgeInsets.zero)` | 卡内直接铺 `PureListRow` 或自管 `Column`(文本块手动 `Padding`);卡片之间 `SizedBox(height: 16)` | `toolbox_page.dart:319-331`、`375-380` |
| `ListTile` / `InkWell` 视觉 | `PureListRow(title:, subtitle:, leading:, trailing:, onTap:, divided:)` | 自带 fluent ListViewItem 的 hover/pressed 填充与选中视觉,**不要**再手写 Ink/hover(`pure_uikit/lib/src/styling/widgets/content/pure_card.dart:360-409`);`onTap: null` 即非交互;`divided: false` 关闭行底分隔线 | `toolbox_page.dart:321-331` |
| `Divider` | `PureDivider` | — | `toolbox_page.dart:462` |
| `PopupMenuButton` | fluent `MenuBar` / Pure 菜单 | 本页未涉及,暂无成品先例;API 拿不准先读示例仓库(`example/lib`)与上文第 2–7 节 | 无 |
| `Checkbox` / `Switch` / `Slider` / `DropdownButton` | 对应 Pure 组件,没有再用 fluent 原生(`CheckBox` / `ToggleButton` / `Slider` / `DropDownButton`) | 本页未涉及,暂无成品先例;首个遇到的页面任务补写先例行 | 无 |

### 9.2 保留不动清单

- **`Icons.*`(material.dart 的图标字形)**:全仓库图标惯例,Pure 组件的 `icon:` / `leading:` 直接吃它;不替换、不改字形(会变视觉),`import 'package:flutter/material.dart'` 因此保留。
- 布局与基建设施不算「Material 组件」:`Text`、`SelectableText`、`EdgeInsets`、`BoxConstraints`、`CrossAxisAlignment`、`TextEditingController`、`WidgetsBinding`、`Clipboard`(flutter/services)等照用。
- 业务逻辑、Riverpod provider、go_router 路由、数据访问一律不动;纯 UI 重排只在视觉等价的前提下做(如成品页把运行中的「取消」按钮放在卡片尾部而非动作行内,`toolbox_page.dart:436-448`)。

### 9.3 视觉保持套路

- 页面只从 `PureTheme.of(context)` 取 token:色用 `theme.colors.*`(`primary`、`textSecondary`),字用 `theme.text.*`(`body`、`caption`)再 `copyWith` 微调,不手写裸色值(`toolbox_page.dart:320、373、457-483`)。
- 卡片列宽与间距照抄成品页:`maxWidth: 720`、卡间距 16(`toolbox_page.dart:296、301-306`)。
- 每个组件上的 `///` 注释保留 3.x 参照与替换理由;后续页面任务同样把「为什么这么换」写进注释。

### 9.4 已核实的陷阱

- `const new({super.key});` 是全仓库的构造函数写法:Dart 3.13 允许 `new` 作构造名,实例化照旧写 `ToolboxPage()`(见 `apps/pure_live/lib/system/navigation/app_router.dart:808`)。已用一次性探针 `dart analyze` 验证无语法错误——**不是笔误,不要"修复"**。
- grep 检查残留 Material 组件时,`TextField\(` 这类宽松正则会误命中 `PureTextField(`;用词边界或人工核对构造返回行。
- 验收口径:页面内不得出现 9.1 表左列的 Material 组件构造;不创建/不修改测试文件;不自行 commit / push。
