# PureLive Package Creation and Engineering Standards

- **Document:** `docs/engineering/package-standards.md`
- **Scope:** All Dart and Flutter packages in the PureLive monorepo
- **Workspace:** Dart Pub Workspace
- **Status:** Normative engineering specification

## 1. Goals

Every package must follow the same rules for naming, structure, dependencies, public APIs, documentation, testing, formatting, and CI validation.

The goals are:

- One package has one clear responsibility.
- Package names and directory names follow a consistent convention.
- Internal packages share the root Pub workspace.
- Public APIs are intentional and stable.
- Dependencies follow an explicit dependency direction.
- Business packages do not depend on concrete UI libraries or platform implementations unnecessarily.
- Generated files, formatting, and imports follow predictable rules.
- Every package can be tested and analyzed independently.
- New packages can be created using a standard script rather than manually copying directories.

The rules in this document are mandatory unless an approved architecture decision record explicitly permits an exception.

## 2. Repository layout

Use the following repository structure as the standard layout:

```text
pure_live/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── README.md
├── CHANGELOG.md
├── apps/
│   └── pure_live/
├── packages/
│   ├── foundation/
│   ├── integrations/
│   ├── ecosystem/
│   ├── services/
│   ├── ui/
│   ├── features/
│   └── providers/
├── third_party/
├── fixtures/
├── tool/
│   ├── scaffold_package.ps1
│   ├── validate_packages.ps1
│   └── check_architecture.ps1
└── docs/
    ├── architecture/
    ├── engineering/
    ├── decisions/
    └── development/
```

### Directory responsibilities

| Directory | Responsibility |
|---|---|
| `apps/` | Application entry points and composition roots |
| `packages/foundation/` | Fundamental models, contracts, utilities, and shared primitives |
| `packages/integrations/` | Adapters for external libraries and platform integrations |
| `packages/ecosystem/` | Plugin formats, external runtimes, and source integrations |
| `packages/services/` | Application-independent services |
| `packages/ui/` | Shared UI systems and style adapters |
| `packages/features/` | Reusable business capabilities |
| `packages/providers/` | Concrete implementations of shared provider contracts |
| `third_party/` | Explicitly maintained forks or vendored code |
| `fixtures/` | Shared test data and fixtures |
| `tool/` | Development scripts, validation, and automation |
| `docs/` | Architecture, engineering, decisions, and development documentation |

Place a package in the directory that best represents its responsibility. Do not create a new category for a single package unless there is a clear architectural reason.

Examples:

```text
packages/
├── foundation/
│   ├── live_platform_contracts/
│   ├── live_common/
│   └── live_result/
├── integrations/
│   ├── live_network/
│   └── live_storage/
├── ecosystem/
│   ├── live_extension_gateway/
│   └── live_script_runtime/
├── ui/
│   ├── live_uikit/
│   ├── live_uikit_fluent/
│   ├── live_uikit_material/
│   └── live_uikit_cupertino/
└── features/
    ├── live_playback/
    ├── live_library/
    └── live_interaction/
```

These are naming and placement examples, not a requirement to create every listed package immediately.

## 3. Package naming

### 3.1 Naming rules

1. Use lowercase `snake_case`.
2. Use the `live_` prefix for PureLive-owned packages.
3. Use the same name for the package and its directory.
4. Each package name must be unique across the repository.
5. Names must describe the package's responsibility.
6. Avoid ambiguous names such as `common2`, `utils_new`, `base`, `core2`, and `shared`.
7. Do not include version numbers in package names.
8. Do not use a third-party library's name as the package name unless the package is intentionally its adapter.

Examples:

| Package name | Directory | Valid |
|---|---|---|
| `live_uikit` | `packages/ui/live_uikit/` | Yes |
| `live_uikit_fluent` | `packages/ui/live_uikit_fluent/` | Yes |
| `live_storage` | `packages/integrations/live_storage/` | Yes |
| `live_playback` | `packages/features/live_playback/` | Yes |
| `LiveUIKit` | `packages/ui/LiveUIKit/` | No |
| `live-uikit` | `packages/ui/live-uikit/` | No |
| `common_utils` | `packages/foundation/live_common/` | No |

The directory name must exactly match the `name:` field in `pubspec.yaml`.

### 3.2 Adapter naming

Use the following pattern for UI adapters:

```text
live_uikit_<style>
```

Examples:

```text
live_uikit_material
live_uikit_cupertino
live_uikit_fluent
live_uikit_macos
live_uikit_neumorphic
live_uikit_glass
live_uikit_wind
```

The adapter must depend on `live_uikit`, not the other way around.

## 4. Package creation workflow

Every new package must follow this sequence:

1. Determine whether the functionality belongs in an existing package.
2. Define the package's single responsibility.
3. Select the appropriate category directory.
4. Define its public API and dependency direction.
5. Create it using `tool/scaffold_package.ps1`.
6. Add it to the Pub workspace.
7. Implement the smallest valid public API.
8. Add tests and documentation.
9. Run formatting, dependency resolution, static analysis, and tests.
10. Verify architectural boundaries.
11. Review the package before merging.

Do not create a package solely to wrap one function if that function belongs naturally in an existing package. Conversely, do not combine unrelated capabilities simply to reduce the package count.

### 4.1 Standard creation command

The scaffold script should support a command such as:

```powershell
.\tool\scaffold_package.ps1 `
  -Name live_uikit_fluent `
  -Category ui `
  -Type flutter
```

For a pure Dart package:

```powershell
.\tool\scaffold_package.ps1 `
  -Name live_result `
  -Category foundation `
  -Type dart
```

For a package requiring code generation:

```powershell
.\tool\scaffold_package.ps1 `
  -Name live_models `
  -Category foundation `
  -Type dart `
  -WithCodegen
```

These commands define the desired script interface. The script must implement these parameters before the commands are considered executable.

The script should:

- Validate the package name.
- Validate the category and package type.
- Reject duplicate package names.
- Reject an existing destination directory.
- Generate standard files.
- Generate the correct SDK and dependency sections.
- Add the package to the root `workspace:` list.
- Preserve alphabetical ordering where required.
- Avoid overwriting existing files.
- Print the generated paths and next steps.
- Exit with a nonzero status if validation or generation fails.

The script must not silently rewrite unrelated packages.

## 5. Required package files

Every package must contain these files:

```text
live_example/
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
├── analysis_options.yaml
├── lib/
│   ├── live_example.dart
│   └── src/
└── test/
```

The following files are additionally required where applicable:

| File or directory | Requirement |
|---|---|
| `LICENSE` | Required for independently distributed or published packages; follow repository licensing policy |
| `example/` | Required for public-facing packages where an example materially improves integration |
| `integration_test/` | Required when platform integration behavior cannot be verified with unit/widget tests alone |
| `tool/` | Only for package-specific development or generation scripts |
| `lib/src/` | Standard location for private implementation |
| `CHANGELOG.md` | Required for every package, including initial development |
| `README.md` | Required for every package, including internal packages |

Do not add empty directories just to satisfy a template. Required files should contain meaningful initial content.

## 6. Pub workspace rules

PureLive uses Dart Pub Workspace for internal package development.

### 6.1 Root workspace

The root `pubspec.yaml` is the source of truth for workspace membership.

Conceptual example:

```yaml
name: pure_live_workspace
publish_to: none

environment:
  sdk: ^3.13.0

workspace:
  - apps/pure_live
  - packages/foundation/live_platform_contracts
  - packages/integrations/live_storage
  - packages/ui/live_uikit
  - packages/ui/live_uikit_fluent
```

The list above is illustrative. Keep the actual root workspace list synchronized with all existing workspace members.

### 6.2 Member packages

Each workspace member must include:

```yaml
resolution: workspace
```

Use compatible SDK constraints and the workspace's shared lockfile.

Do not create separate package lockfiles for ordinary workspace members.

### 6.3 Internal dependencies

Declare internal dependencies explicitly in each package's `pubspec.yaml`.

Example:

```yaml
dependencies:
  flutter:
    sdk: flutter
  live_uikit:
    path: ../live_uikit
```

The example assumes sibling package directories. Adjust relative paths to match the actual category directories.

Never rely on a package being present in the workspace without declaring it as a dependency.

### 6.4 Dependency overrides

- Keep workspace-wide overrides in the root `pubspec.yaml` where practical.
- Do not introduce package-specific overrides to conceal incompatible dependency constraints.
- Document the reason for every non-obvious override.
- Remove obsolete overrides when they are no longer needed.
- Resolve dependency conflicts rather than randomly downgrading unrelated packages.

### 6.5 Pure Dart versus Flutter packages

Choose the package type deliberately.

**Pure Dart package**

Use when the package only requires Dart libraries and does not need Flutter APIs.

```yaml
dependencies:
  meta: ^1.19.0

dev_dependencies:
  test: <workspace-compatible-version>
```

**Flutter package**

Use when the package imports Flutter APIs or builds widgets.

```yaml
dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

Do not add Flutter dependencies to a pure Dart contracts or models package just for convenience.

The versions above are illustrative. The actual test framework versions must be compatible with the workspace SDK and dependency constraints.

## 7. Package responsibility and boundaries

Every package must document one primary responsibility.

Its README must answer:

- What problem does the package solve?
- What does it own?
- What does it explicitly not own?
- Which packages may depend on it?
- Which dependencies does it require?
- What is its public entry point?
- How is it tested?

### 7.1 Dependency direction

Use a directed acyclic graph for internal package dependencies.

Example:

```text
Application composition root
       |
       +----> Feature packages
       |          |
       |          +----> Shared contracts
       |          +----> Services
       |
       +----> UI core
       |          ^
       |          |
       |      UI adapters
       |
       +----> Concrete providers
```

The actual graph must be documented in the architecture documentation.

Rules:

1. Lower-level contracts must not depend on business features.
2. Shared models must not depend on application widgets.
3. UI core must not depend on concrete UI adapters.
4. UI adapters may depend on UI core.
5. Concrete implementations must depend on their contracts where appropriate.
6. Avoid circular package dependencies.
7. Do not import another package's private `lib/src/` implementation.
8. Do not add a dependency solely to reuse one private helper without evaluating the proper abstraction boundary.

### 7.2 State management

Packages must not depend on Riverpod or GetX merely to make state available to callers.

Use state-management dependencies only when they are an intentional part of the package's public architecture. Prefer framework-independent contracts in reusable foundation and service packages.

The application composition root is responsible for connecting framework-specific state management to reusable services and adapters.

## 8. Directory and source-code conventions

### 8.1 Standard library structure

```text
lib/
├── live_example.dart
└── src/
    ├── models/
    ├── contracts/
    ├── services/
    └── internal/
```

Only create the subdirectories needed by the package.

Do not use the same generic directory structure blindly for every package. A UI adapter, a storage integration, and a pure data-model package have different internal needs.

### 8.2 Public entry point

Use one primary public barrel file:

```text
lib/live_example.dart
```

It must export the supported public API.

Example:

```dart
library live_example;

export 'src/models/example_config.dart';
export 'src/services/example_service.dart';
```

The exports must match actual files and intended public symbols.

Rules:

- Keep implementation details in `lib/src/`.
- Do not export internal implementation files indiscriminately.
- Do not require callers to import `package:live_example/src/...`.
- Do not create multiple overlapping public entry points without a documented reason.
- Treat exported classes, constructors, and method signatures as public compatibility commitments.

### 8.3 Naming

Use these conventions:

| Element | Convention | Example |
|---|---|---|
| Package | `snake_case` | `live_storage` |
| File | `snake_case.dart` | `storage_bootstrap.dart` |
| Class | `UpperCamelCase` | `StorageBootstrap` |
| Enum | `UpperCamelCase` | `StorageMode` |
| Variable | `lowerCamelCase` | `storageMode` |
| Method | `lowerCamelCase` | `initializeStorage()` |
| Constant | `lowerCamelCase` | `defaultTimeout` |
| Private member | Leading underscore | `_openingBoxes` |
| Type parameter | Meaningful uppercase name | `T`, `TValue` |

Use descriptive names. Avoid unexplained abbreviations and names that duplicate the containing package without adding meaning.

## 9. Dart and Flutter coding rules

### 9.1 Formatting

Use the Dart formatter as the canonical formatter for Dart source files.

```powershell
dart format .
```

In the repository's validation scripts, prefer checking formatting without modifying files:

```powershell
dart format --output=none --set-exit-if-changed .
```

The exact scope should be limited to tracked Dart source and generated Dart files that are expected to follow formatter output.

Do not allow individual IDE settings to define a different canonical formatting style.

### 9.2 Imports

- Use package imports for public cross-package APIs.
- Use relative imports for files within the same package when consistent with repository conventions.
- Sort imports with the project's selected lint rules.
- Separate Dart SDK, Flutter SDK, third-party, and internal imports according to the configured lint policy.
- Do not add unused imports.
- Do not import private implementation paths from another package.

### 9.3 Comments and documentation

All source-code comments and API documentation written for PureLive must be in English.

Use Dart documentation comments for public APIs:

```dart
/// Initializes the storage subsystem.
///
/// Reuses an in-flight initialization operation when one already exists.
Future<void> initialize() async {
  // Implementation details belong here.
}
```

Rules:

- Public APIs require meaningful documentation.
- Explain why non-obvious behavior exists, not merely what the code does.
- Document lifecycle, concurrency, error handling, and ownership where relevant.
- Avoid redundant comments that restate the method name.
- Keep comments accurate when code changes.
- Do not translate comments automatically into another language during formatting or refactoring.

### 9.4 Error handling

- Use typed errors or documented result types when callers need to distinguish failure cases.
- Do not silently swallow exceptions.
- Do not use empty `catch` blocks.
- Preserve original error context when rethrowing or wrapping exceptions.
- Document retry behavior and timeout behavior for network and asynchronous operations.
- Avoid logging credentials, tokens, cookies, or sensitive user input.

### 9.5 Asynchronous operations

- Use `Future` and `Stream` according to their semantics.
- Define cancellation and disposal behavior for long-running operations.
- Avoid duplicate initialization and request stampedes where concurrency requires protection.
- Do not create untracked background work.
- Dispose owned controllers, subscriptions, timers, and resources.
- Do not dispose resources owned by callers.

## 10. Formatting and code-generation policy

The repository must define one canonical formatting and analysis configuration.

Every package should use the repository's standard `analysis_options.yaml` or extend the approved shared configuration.

Rules:

1. Do not invent package-specific lint settings without a clear need.
2. Do not weaken lint rules merely to silence warnings.
3. Do not run a generator with a different SDK version from the workspace toolchain.
4. Do not manually modify generated files unless the generator explicitly supports it.
5. Keep generated files consistent with the checked-in source and generation configuration.
6. Document the command needed to regenerate code.
7. Keep generated outputs deterministic where practical.

For packages using code generation, document the appropriate command, for example:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Only use this command when the package actually uses `build_runner`.

If a formatting or import-order warning appears after saving a file, fix the underlying formatter/linter configuration or the source. Do not disable the rule globally just to preserve an accidental layout.

## 11. Dependency selection policy

Before adding a dependency, evaluate:

- Whether Flutter or Dart already provides the required capability.
- Whether an existing PureLive package already owns the functionality.
- Whether the dependency supports the required platforms.
- Whether its SDK constraints are compatible.
- Whether it introduces native binaries or platform build requirements.
- Whether it is maintained and appropriately licensed.
- Whether it creates a circular or undesirable dependency.
- Whether the feature can be hidden behind a small internal contract.

### Dependency rules

- Pin dependencies using compatible version constraints, not arbitrary exact pins.
- Prefer the workspace's established version policy.
- Avoid duplicate packages that solve the same problem.
- Do not expose third-party types in public APIs unless this is an intentional design decision.
- Do not make optional platform functionality mandatory for all platforms.
- Document native build requirements and platform limitations.
- Review major upgrades before merging.

## 12. Testing standards

Every package must have a `test/` directory.

### Minimum test expectations

| Package type | Minimum expectation |
|---|---|
| Pure Dart models | Serialization, validation, equality, or invariant tests as applicable |
| Contracts | Contract behavior and invalid-input tests |
| Services | Success, failure, and lifecycle tests |
| Storage | Initialization, concurrency, failure recovery, and disposal tests as applicable |
| UI core | Theme resolution, runtime dispatch, fallback, and widget tests |
| UI adapters | Theme mapping, control behavior, capabilities, and rendering tests |
| Platform integrations | Mocked unit tests plus real platform tests where required |

Test behavior rather than implementation details.

### Test naming

Use descriptive test names that explain the expected behavior:

```dart
test('reuses the in-flight initialization operation', () async {
  // Arrange, act, and assert.
});
```

### Coverage

Do not use coverage percentage as the only quality measure. Focus on public behavior, error paths, concurrency, lifecycle, platform differences, and architectural contracts.

## 13. README and CHANGELOG standards

### 13.1 README

Every package README must include:

1. Package purpose.
2. Responsibilities and exclusions.
3. Installation or workspace usage.
4. Basic usage example.
5. Public API entry point.
6. Dependencies and platform requirements.
7. Testing commands.
8. Known limitations.

For internal packages, explain how other PureLive packages should depend on and integrate with it.

### 13.2 CHANGELOG

Use a consistent format:

```markdown
# Changelog

## Unreleased

### Added

### Changed

### Fixed

### Breaking Changes
```

Keep the changelog focused on user-visible behavior, public API changes, compatibility, and important implementation changes.

Do not claim a feature is released before it has been implemented and validated.

## 14. Versioning and compatibility

For internal packages, use the repository's versioning policy consistently.

When an independently versioned package follows Semantic Versioning:

- **Patch:** Backward-compatible bug fixes.
- **Minor:** Backward-compatible features.
- **Major:** Breaking public API or behavioral changes.

Before changing an exported API:

1. Identify affected dependent packages.
2. Update callers and tests.
3. Document breaking changes.
4. Update the changelog.
5. Verify workspace resolution and the complete dependent build.

Do not use a version bump as a substitute for compatibility analysis.

## 15. Platform-specific code

When a package needs platform-specific behavior:

- Keep platform-independent contracts separate from platform implementations.
- Avoid importing platform-only APIs into common Dart code.
- Define capability detection and fallback behavior.
- Test unsupported platforms explicitly.
- Document native dependencies and minimum platform requirements.
- Avoid exposing platform-specific implementation details through unrelated public APIs.

For example, a media or window-management package should expose a shared contract and delegate platform-specific operations to suitable implementations.

## 16. CI validation

Every pull request that changes a package must run the relevant checks.

Recommended validation sequence:

```powershell
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
flutter test
```

Use the command appropriate to the package type and workspace. For a pure Dart package, use `dart test` or the repository's configured test runner where applicable. For Flutter packages, use `flutter test`.

The workspace CI should additionally verify:

- Workspace membership is correct.
- Package names are unique.
- Directory names match package names.
- Required files exist.
- All workspace packages declare `resolution: workspace`.
- Internal dependencies are declared correctly.
- No dependency cycles exist.
- Package boundaries are respected.
- Public exports do not expose private cross-package implementation.
- Code formatting and static analysis pass.
- Tests pass for affected packages and their relevant dependents.

Do not rely exclusively on testing the application entry point. Each reusable package must be independently analyzable and testable.

## 17. Architecture exceptions

An exception must be explicit rather than silently violating a rule.

Record non-trivial exceptions in:

```text
docs/decisions/
```

An architecture decision record should include:

- Context.
- Decision.
- Alternatives considered.
- Consequences.
- Affected packages.
- Conditions for reconsideration.

Temporary exceptions should include a removal condition or target milestone.

## 18. New-package acceptance checklist

Before merging a new package, verify:

- [ ] Its responsibility is clearly defined.
- [ ] Its name follows the repository convention.
- [ ] Its directory name matches `pubspec.yaml`.
- [ ] It is in the correct category directory.
- [ ] It is registered in the Pub workspace.
- [ ] It declares `resolution: workspace`.
- [ ] It uses the correct pure Dart or Flutter package type.
- [ ] Its dependencies follow the architecture graph.
- [ ] It has a single intentional public entry point.
- [ ] Internal implementation remains in `lib/src/`.
- [ ] It includes `README.md` and `CHANGELOG.md`.
- [ ] It includes meaningful tests.
- [ ] Public APIs have English documentation.
- [ ] Formatting and static analysis pass.
- [ ] Tests pass.
- [ ] Platform limitations are documented.
- [ ] Architectural exceptions are documented.
- [ ] CI checks the package boundaries.

## 19. Final rule

Creating a package is not complete when its directory exists or its code compiles.

A package is complete only when its responsibility, dependency direction, public API, documentation, tests, formatting, workspace integration, and architectural boundaries have all been validated.
