# Wind 1.5: WDynamic (server-driven UI)

JSON node tree → Wind widget tree. Reach for this file when rendering UI from a CMS, A/B framework, remote-config service, or any source where the widget shape is decided at runtime.

For static UI, write Dart directly. WDynamic is the right reach only when remote rendering is a hard requirement (server-driven layouts, ship-blocking releases avoided, dynamic forms from API schema, etc.).

## Contents

1. [JSON node schema](#1-json-node-schema)
2. [Allowed widget types](#2-allowed-widget-types)
3. [Constructor + lifecycle](#3-constructor--lifecycle)
4. [Props mapping (no auto-rename)](#4-props-mapping-no-auto-rename)
5. [State binding by `id`](#5-state-binding-by-id)
6. [Actions](#6-actions)
7. [Custom builders and icons](#7-custom-builders-and-icons)
8. [Security model](#8-security-model)
9. [Worked examples](#9-worked-examples)
10. [Known limitations](#10-known-limitations)

---

## 1. JSON node schema

Every node is a `Map<String, dynamic>` with one required field and two optional fields:

```json
{
  "type": "WDiv",
  "props": {
    "className": "flex flex-col gap-4 p-6",
    "id": "optional-id-for-state-binding",
    "onTap": {"action": "actionName", "args": {"key": "value"}}
  },
  "children": [
    {"type": "WText", "props": {"text": "Hello"}}
  ]
}
```

- `type` (required, String): the widget type name. Must match an allowed type (§2) or a registered custom builder (§7), or the node renders an error box.
- `props` (optional, `Map<String, dynamic>`): widget constructor arguments. Keys are widget-prop names exactly (no auto-rename; see §4).
- `children` (optional, `List<Map>`): nested nodes. Recursively processed depth-first.

All `Map` values are deep-converted to `Map<String, dynamic>` internally; mixed `Map<Object?, Object?>` payloads from JSON parsers are normalized automatically.

Recursion depth is capped at `maxDepth: 50` by default; deeper trees render a red error widget at the threshold node.

---

## 2. Allowed widget types

The default whitelist covers 13 Wind widgets and 16 Flutter core widgets.

**Wind widgets** (use these as the primary surface; they consume className):

`WDiv`, `WText`, `WButton`, `WImage`, `WIcon`, `WAnchor`, `WInput`, `WCheckbox`, `WSvg`, `WSelect`, `WPopover`, `WDatePicker`, `WSpacer`

**Flutter core widgets** (escape hatches for layout primitives that Wind does not wrap):

`Column`, `Row`, `Center`, `SizedBox`, `Expanded`, `Container`, `Wrap`, `Stack`, `Positioned`, `Padding`, `Align`, `Opacity`, `AspectRatio`, `FittedBox`, `ClipRRect`, `Spacer`

**Not on the whitelist:** `WBadge`, `WCard`, `WSwitch`, `WRadio`, `WTabs` (the five widgets added in 1.2.0), plus the `WForm*` family, `WBreakpoint`, `WDynamic` itself, and `WKeyboardActions`. A JSON node naming one of them is treated as an unknown type and renders the error box, so do not reach for them in a payload. Register a custom builder (§7) when a server-driven tree genuinely needs one, for example `builders: {'WCard': (props, children) => WCard(className: props['className'], child: children.first)}`.

Extension via `builders:` constructor param adds new types (§7); these bypass the whitelist entirely.

Restriction via `denyWidgets: Set<String>` blocks specific defaults from a payload. Useful when accepting partially-trusted JSON that should not be allowed to render text inputs, for example.

---

## 3. Constructor + lifecycle

```dart
const WDynamic({
  Key? key,
  required Map<String, dynamic> json,
  Map<String, Function> actions = const {},
  WDynamicController? controller,
  Set<String>? denyWidgets,
  Map<String, WWidgetBuilder>? builders,
  Map<String, IconData>? customIcons,
  int maxDepth = 50,
  void Function(String type, Map<String, dynamic> props)? onUnknownWidget,
})
```

State ownership:
- If `controller` is provided, `WDynamic` does not own the underlying `WDynamicState` (consumer disposes).
- If `controller` is null, `WDynamic` creates a new `WDynamicState` internally and disposes on `dispose()`.

The `actions:` map is captured at construction; updating it requires rebuilding the widget. For dynamic action sets, route through a controller and dispatch via `WDynamicState.set(id, value)` inside a handler that delegates further.

---

## 4. Props mapping (no auto-rename)

Props keys map 1:1 to Wind widget constructor parameters. There is NO snake_case → camelCase conversion. The JSON must use the exact Dart parameter name.

Right:
```json
{
  "type": "WInput",
  "props": {
    "id": "email",
    "type": "email",
    "placeholder": "you@example.com",
    "className": "rounded-lg p-3 border border-gray-300 focus:ring-2 focus:ring-blue-500"
  }
}
```

Wrong (silent drop because `class-name` / `place_holder` do not match Dart param names):
```json
{"type": "WInput", "props": {"class-name": "...", "place_holder": "..."}}
```

For nested objects (action descriptors, option lists, callbacks), see §6 (actions) and §9 (worked examples).

---

## 5. State binding by `id`

Widgets that maintain a value (WInput, WCheckbox, WSelect, WDatePicker) bind to `WDynamicState` via a string `id` prop. The value is stored in the state's internal map; reads and writes go through `state.get(id)` / `state.set(id, value)`.

Binding flow:
1. Widget mounts → reads `state.get(id)` for initial value.
2. User interacts → the widget calls `state.set(id, value)`. The `id` alone is enough; no `onChange` is required for the value to land in the store.
3. When the node also carries an `onChange` action, it dispatches after that write, with the new value injected into its args as `_value`. `WDatePicker` is the exception: its action dispatches with no injected value, so its handler reads the date from `state.get(id)`.
4. The state's `notifyListeners()` triggers a rebuild; widgets reading the same `id` reflect the new value.

A node with neither an `id` nor an `onChange` has nowhere to put a value and gets no callback at all, which is how a display-only control is expressed in JSON.

Programmatic mutation via controller:

```dart
final controller = WDynamicController();

WDynamic(
  json: schema,
  controller: controller,
  actions: {'submit': (args, state) => api.send(state.getAll())},
);

// Elsewhere:
controller.setValue('email', 'admin@example.com');
final value = controller.getValue('email');
final allValues = controller.getAll();

controller.addListener('email', (newValue) {
  // fires when 'email' changes
});

controller.reset();   // clears all values
controller.dispose(); // when done (only if not passed to WDynamic that owns it)
```

`WDynamicState` is a `ChangeNotifier`; you can also subscribe at the state level. Listeners scoped by id receive only their own id's changes.

---

## 6. Actions

Actions reference handlers by string name in JSON. Handler resolution is dynamic at dispatch time.

JSON form:
```json
{"action": "incrementCounter", "args": {"step": 1}}
```

Constructor:
```dart
WDynamic(
  json: schema,
  actions: {
    'incrementCounter': (Map<String, dynamic> args, WDynamicState state) {
      final current = (state.get('counter') as int?) ?? 0;
      final step = (args['step'] as int?) ?? 1;
      state.set('counter', current + step);
    },
    'submit': (args, state) => api.submit(state.getAll()),
    'open': (args) => MagicRoute.to(args['route'] as String),
  },
);
```

Handler signature is auto-detected in order:
1. `Function(Map<String, dynamic>, WDynamicState)`: preferred when handler needs to read or mutate state
2. `Function(Map<String, dynamic>)`: pure action with no state access
3. Fallback `Function.apply(handler, [args, state])`: for handlers with unusual signatures

Unknown action names log `WindDynamic: Unknown action "<name>", ignored.` via `debugPrint` and return null. Exceptions inside handlers are caught and logged via `debugPrint('WindDynamic: Action "<name>" error: <err>')`. Neither crashes the build.

Value actions (used by WInput, WCheckbox, WSelect, WDatePicker):
- The widget's `onChange` callback is wired through `parseValueAction<T>`.
- The changed value is injected into args as `_value`.
- If the widget also has an `id` prop, `state.set(id, value)` runs BEFORE the action dispatches, so the handler sees the updated state.

Example:
```json
{
  "type": "WInput",
  "props": {
    "id": "email",
    "onChanged": {"action": "validateEmail", "args": {}}
  }
}
```

Handler:
```dart
'validateEmail': (args, state) {
  final value = args['_value'] as String?;     // the new text input value
  // state.get('email') == value already (set by parseValueAction)
}
```

Async actions can return `FutureOr<void>` but the dispatcher fires-and-forgets. There is no `await` on action dispatch.

---

## 7. Custom builders and icons

### Builders

Add a custom widget type by registering a `WWidgetBuilder`:

```dart
typedef WWidgetBuilder = Widget Function(Map<String, dynamic> props, List<Widget> children);

WDynamic(
  json: schema,
  builders: {
    'MyChart': (props, children) => MyChartWidget(
      data: props['data'] as List<num>,
      color: props['color'] as String?,
    ),
    'MarkdownBlock': (props, children) => Markdown(data: props['source'] as String),
  },
);
```

Then in JSON:
```json
{"type": "MyChart", "props": {"data": [1, 2, 3, 4], "color": "#3B82F6"}}
```

Custom builders BYPASS the whitelist entirely. If you register `MyChart`, it renders even if added to `denyWidgets`. Build the security model around your `builders:` map (don't accept builder definitions from untrusted JSON).

### Custom icons

Override or extend the 24 built-in icon names:

```dart
WDynamic(
  json: schema,
  customIcons: {
    'app-logo': Icons.flutter_dash_outlined,
    'arrow_right': Icons.east_outlined,            // override built-in
  },
);
```

In JSON:
```json
{"type": "WIcon", "props": {"icon": "app-logo", "className": "w-8 h-8 text-blue-500"}}
```

Built-in icon names (default fallback, 24 total): `star`, `star_outline`, `home`, `person`, `check`, `close`, `settings`, `search`, `add`, `edit`, `delete`, `favorite`, `favorite_outline`, `mail`, `menu`, `info`, `warning`, `error`, `help`, `code`, `chevron_left`, `chevron_right`, `arrow_back`, `arrow_forward`. Names are matched case-insensitively (lowercased). Unknown names fall back to `Icons.help_outline`.

The `customIcons:` map merges with the built-in defaults; user keys override.

---

## 8. Security model

`WDynamicConfig.isAllowed(type)` runs in priority order:
1. Custom builders win (always allowed; bypass everything).
2. `denyWidgets` blocks.
3. Default whitelist allows (13 Wind + 16 Flutter core).
4. Unknown type → `onUnknownWidget` callback if provided, else a red error widget.

Threat model considerations:
- **JSON source matters.** A controlled backend rendering a known schema is safe. Untrusted client input is not; even with whitelist enforcement, props can hold dangerous data (URLs that load attacker-controlled assets via `WImage(src:)`, action names that overlap with privileged handlers).
- **`builders:` is the escape hatch.** If you don't add custom builders, the surface is bounded by the 29-widget whitelist + the action handlers you registered. Action handlers run consumer Dart code; they are the trust boundary.
- **Action argument coercion is shallow.** `args['_value'] as String?` will succeed if the JSON sends `"_value": "<script>"`. The script tag is just a string. But `args['url']` passed to `Magic.launch.url(args['url'])` opens the URL. Validate at the handler.
- **Recursion limit prevents stack overflow.** Default `maxDepth: 50` is plenty for legitimate UI; reduce for stricter bounds when accepting third-party JSON.

---

## 9. Worked examples

### A counter

```dart
WDynamic(
  json: {
    'type': 'WDiv',
    'props': {'className': 'flex flex-col gap-4 p-6'},
    'children': [
      {
        'type': 'WText',
        'props': {
          'id': 'counter',
          'text': '0',                 // initial; updated via state binding
          'className': 'text-4xl font-bold text-gray-900 dark:text-white',
        },
      },
      {
        'type': 'WButton',
        'props': {
          'className': 'bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg',
          'onTap': {'action': 'increment', 'args': {'step': 1}},
        },
        'children': [
          {'type': 'WText', 'props': {'text': 'Increment'}},
        ],
      },
    ],
  },
  actions: {
    'increment': (args, state) {
      final current = int.tryParse(state.get('counter') as String? ?? '0') ?? 0;
      final step = (args['step'] as int?) ?? 1;
      state.set('counter', (current + step).toString());
    },
  },
);
```

Note: `WText` does not subscribe to id-based state changes automatically (it's a stateless display widget). For a reactive counter display, either listen via `WDynamicController` and rebuild the JSON tree, or use a stateful Dart widget that reads state.

### A form

```dart
final controller = WDynamicController();

WDynamic(
  controller: controller,
  json: {
    'type': 'WDiv',
    'props': {'className': 'flex flex-col gap-4 p-6 max-w-md mx-auto'},
    'children': [
      {
        'type': 'WInput',
        'props': {
          'id': 'email',
          'type': 'email',
          'placeholder': 'you@example.com',
          'className': 'rounded-lg p-3 border border-gray-300 dark:border-gray-600 focus:ring-2 focus:ring-blue-500',
        },
      },
      {
        'type': 'WInput',
        'props': {
          'id': 'password',
          'type': 'password',
          'placeholder': 'Password',
          'className': 'rounded-lg p-3 border border-gray-300 dark:border-gray-600 focus:ring-2 focus:ring-blue-500',
        },
      },
      {
        'type': 'WButton',
        'props': {
          'className': 'bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg',
          'onTap': {'action': 'submit', 'args': {}},
        },
        'children': [{'type': 'WText', 'props': {'text': 'Sign in'}}],
      },
    ],
  },
  actions: {
    'submit': (args, state) async {
      final result = await api.login(
        state.get('email') as String? ?? '',
        state.get('password') as String? ?? '',
      );
      // ...
    },
  },
);
```

### A select with options

```dart
{
  'type': 'WSelect',
  'props': {
    'id': 'country',
    'placeholder': 'Pick a country',
    'searchable': true,
    'options': [
      {'value': 'tr', 'label': 'Türkiye'},
      {'value': 'us', 'label': 'United States'},
      {'value': 'de', 'label': 'Germany'},
    ],
    'onChange': {'action': 'pickCountry', 'args': {}},
    'className': 'rounded-lg p-3 border border-gray-300 dark:border-gray-600',
  },
}
```

Options accept maps with `value` + `label` (+ optional `disabled`, `icon` name) OR plain strings (which become both value and label).

---

## 10. Known limitations

- **Snake-case → camelCase**: not done. JSON keys must match Dart parameter names exactly.
- **WSelect<String> + null initial value crash**: documented edge case. When passing simple string options with a null initial value, the renderer's catch path swallows the type error and renders the error widget. Workaround: pass map-typed options or an explicit initial value.
- **WDatePicker action signature asymmetry**: uses `parseAction()` (no `_value` injection) instead of `parseValueAction<DateTime>()`. Handlers must read the new value from `state.get(id)`, not from `args['_value']`.
- **Async actions fire-and-forget**: the dispatcher does not await. Compose action handlers carefully; for sequenced operations, store intermediate state via `state.set()` and dispatch follow-up actions explicitly.
- **No partial re-render**: when `state.set(id, value)` runs, the entire JSON tree rebuilds (it's a single `setState` in the renderer). For high-frequency state, prefer Dart with targeted listeners.
- **No subtree caching**: the JSON tree is rebuilt every frame; the WindStyle cache helps but the JSON-to-Widget tree is fresh each time.
- **`WText` is not reactive to state by `id`**: it's a stateless display widget. To display a state value reactively, listen via `WDynamicController` from a Dart widget that wraps WDynamic.

For static UI, Dart is faster, simpler, and easier to debug. Reach for WDynamic only when the use case actually requires runtime-defined trees.
