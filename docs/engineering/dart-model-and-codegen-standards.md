# Dart Model and Code Generation Standards

## 1. Purpose

This document defines the model organization, code generation, serialization, public API, and testing standards for the PureLive Flutter monorepo.

The goals are to:

- Keep domain models independently organized.
- Keep generated files next to their source files.
- Prevent generated code from leaking into public APIs.
- Make code generation reproducible across local development and CI.
- Keep package dependencies and model ownership explicit.
- Ensure consistent organization as the monorepo grows.

These standards apply to all Dart packages in the workspace.

## 2. Core Rules

1. Each independently maintained model entity MUST have its own directory.
2. A model's handwritten source and generated files MUST reside in the same directory.
3. Generated files MUST NOT be edited manually.
4. A model MUST be owned by exactly one package.
5. Cross-package consumers MUST use public package exports instead of importing another package's `src/` files.
6. Each package MUST declare only the dependencies required by its actual implementation.
7. Code generation MUST be reproducible locally and in CI.
8. All handwritten Dart comments MUST be written in English.
9. Model directory names MUST use `snake_case`.
10. Generated files MUST follow the naming conventions defined in this document.

## 3. Package Directory Structure

Every package MUST follow the standard package structure.

Example:

```text
packages/
└── live_sources/
    ├── pubspec.yaml
    ├── README.md
    ├── CHANGELOG.md
    ├── analysis_options.yaml
    ├── lib/
    │   ├── live_sources.dart
    │   └── src/
    │       ├── models/
    │       ├── repositories/
    │       ├── services/
    │       └── utils/
    ├── test/
    │   └── src/
    └── example/
```

Not every package needs every optional directory. Create directories only when the package requires them.

## 4. Model Directory Structure

### 4.1 One model entity per directory

Each independently maintained entity MUST have its own directory under `lib/src/models/`.

Example:

```text
lib/
├── live_sources.dart
└── src/
    └── models/
        ├── live_source/
        │   ├── live_source.dart
        │   ├── live_source.freezed.dart
        │   └── live_source.g.dart
        ├── live_source_config/
        │   ├── live_source_config.dart
        │   ├── live_source_config.freezed.dart
        │   └── live_source_config.g.dart
        └── live_source_capability/
            ├── live_source_capability.dart
            └── live_source_capability.freezed.dart
```

The directory name MUST match the entity's `snake_case` name.

For example:

| Entity | Directory | Source file |
|---|---|---|
| `LiveSource` | `live_source/` | `live_source.dart` |
| `LiveSourceConfig` | `live_source_config/` | `live_source_config.dart` |
| `LiveSourceCapability` | `live_source_capability/` | `live_source_capability.dart` |
| `PluginManifest` | `plugin_manifest/` | `plugin_manifest.dart` |

Do not place all model files directly inside `models/`.

### 4.2 Files belonging to an entity

A model directory MAY contain:

- The handwritten model definition.
- Freezed-generated code.
- JSON serialization-generated code.
- Small entity-specific handwritten helper files.
- Additional handwritten files that have a clear, entity-specific responsibility.

Example:

```text
live_source/
├── live_source.dart
├── live_source.freezed.dart
├── live_source.g.dart
└── live_source_status.dart
```

`live_source_status.dart` is optional. Keep a small enum or helper type in `live_source.dart` when doing so keeps the implementation simple. Extract it when it has an independent responsibility or needs to be reused elsewhere.

Do not create extra files or directories merely to make the structure appear more granular.

### 4.3 Shared model types

Types shared by multiple entities MUST have their own directory.

Example:

```text
lib/src/models/
├── live_source/
│   ├── live_source.dart
│   ├── live_source.freezed.dart
│   └── live_source.g.dart
├── live_source_config/
│   ├── live_source_config.dart
│   ├── live_source_config.freezed.dart
│   └── live_source_config.g.dart
└── pagination/
    └── pagination.dart
```

A shared type MUST NOT be placed inside another entity's directory solely because that entity was implemented first.

Before extracting a shared type, verify that it represents a genuinely shared concept rather than creating premature abstractions.

## 5. Dependency Standards

### 5.1 Runtime dependencies

Add model-related dependencies only when the package uses them.

```yaml
dependencies:
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0
```

The versions above are an example of the intended dependency roles, not a guarantee that every package in the workspace can resolve them together. Use versions that are compatible with the workspace's resolved SDK, analyzer, and generator versions.

- `freezed_annotation`: runtime annotations and generated model support.
- `json_annotation`: JSON serialization annotations and generated serialization support.
- `equatable`: optional equality support for handwritten value objects that do not use Freezed.

Do not use Equatable and Freezed to implement equality for the same model. Freezed already generates value equality.

### 5.2 Development dependencies

Packages using Freezed and JSON code generation SHOULD declare their required generators as development dependencies.

```yaml
dev_dependencies:
  build_runner: <workspace-approved-version>
  freezed: <workspace-approved-version>
  json_serializable: <workspace-approved-version>
```

Replace placeholders with versions approved and verified for the workspace.

Do not copy generator versions blindly between packages. Resolve and test them against the actual workspace constraints before updating the standard versions.

### 5.3 Version compatibility

The following requirements MUST be checked together:

- Flutter SDK and Dart SDK constraints.
- `equatable: ^2.0.7`
- `freezed_annotation` and `freezed`.
- `json_annotation` and `json_serializable`.
- `build_runner`.
- `analyzer` constraints imposed by tests, linters, and other generators.

For a Pub workspace, run dependency resolution from the workspace root. Do not fix a conflict by adding arbitrary `dependency_overrides` without understanding which package imposes the incompatible constraint.

## 6. Model Implementation Standards

### 6.1 Freezed models

Use Freezed for immutable models that benefit from generated equality, `copyWith`, unions, or JSON serialization.

Example: `lib/src/models/live_source/live_source.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_source.freezed.dart';
part 'live_source.g.dart';

@freezed
abstract class LiveSource with _$LiveSource {
  const factory LiveSource({
    required String id,
    required String name,
    @Default(true) bool enabled,
  }) = _LiveSource;

  factory LiveSource.fromJson(Map<String, dynamic> json) =>
      _$LiveSourceFromJson(json);
}
```

This example assumes a compatible Freezed version that supports this declaration style. Generated output and syntax MUST be verified using the versions resolved by the project.

Rules:

- Use immutable fields by default.
- Use `@Default(...)` for explicit default values.
- Keep business validation in an appropriate domain layer rather than hiding complex rules in generated models.
- Keep network requests, persistence operations, and UI state management out of simple data models.
- Add JSON support only when the model needs serialization.
- Declare each generated `part` file explicitly.
- Do not import generated files directly.

### 6.2 Handwritten value objects

Use Equatable or a handwritten implementation when the model is small and does not need Freezed's generated functionality.

Do not add Freezed to a package simply because other packages use it.

### 6.3 JSON-only models

Use `json_serializable` directly when JSON conversion is required but Freezed's immutability, unions, and generated equality are unnecessary.

Keep the handwritten definition and generated `.g.dart` file in the same entity directory.

## 7. Generated File Standards

### 7.1 Naming

Generated filenames MUST match the handwritten source basename.

| Handwritten file | Generated file | Purpose |
|---|---|---|
| `live_source.dart` | `live_source.freezed.dart` | Freezed-generated model code |
| `live_source.dart` | `live_source.g.dart` | JSON serialization code |
| `plugin_manifest.dart` | `plugin_manifest.freezed.dart` | Freezed-generated model code |
| `plugin_manifest.dart` | `plugin_manifest.g.dart` | JSON serialization code |

Generated files MUST remain beside the source file that declares them.

Correct:

```text
live_source/
├── live_source.dart
├── live_source.freezed.dart
└── live_source.g.dart
```

Incorrect:

```text
models/
├── live_source.dart
└── generated/
    ├── live_source.freezed.dart
    └── live_source.g.dart
```

Do not create a package-wide `generated/` directory for files produced by `build_runner` unless a specific generator explicitly requires a different output layout.

### 7.2 Generated file handling

Generated files MUST:

- Be produced by the configured generator.
- Retain the generator's expected headers and structure.
- Never be edited manually.
- Be regenerated after changes to the source annotations or model definitions.
- Be validated by CI.

Do not manually change generated imports, equality implementations, serialization logic, or generated declarations.

### 7.3 Version control

PureLive SHOULD commit generated Dart files when they are needed to build and test the package from a clean checkout without relying on undocumented local generation steps.

The repository MUST adopt one consistent policy across packages.

If generated files are committed:

1. Regenerate them after relevant source changes.
2. Include the generated changes in the same commit.
3. Verify that regeneration produces no additional diff in CI.

If generated files are not committed, CI and all documented build workflows MUST generate them before analysis, testing, or compilation.

Do not mix these policies arbitrarily between packages.

## 8. Public API and Exports

Each package MUST have a public entrypoint:

```text
lib/<package_name>.dart
```

Example: `lib/live_sources.dart`

```dart
export 'src/models/live_source/live_source.dart';
export 'src/models/live_source_config/live_source_config.dart';
export 'src/models/live_source_capability/live_source_capability.dart';
```

Rules:

- Export public model definitions through the package entrypoint.
- Do not export generated `.freezed.dart` or `.g.dart` files directly.
- Do not require consumers to import `src/`.
- Keep implementation-only helpers private to the package.
- Review public exports whenever a new model is introduced.

When a package has many public models, it MAY use an internal export file to organize the entrypoint, provided consumers still import the main package entrypoint.

## 9. Test Directory Structure

Tests SHOULD mirror the source directory structure.

Example:

```text
test/
└── src/
    └── models/
        ├── live_source/
        │   └── live_source_test.dart
        ├── live_source_config/
        │   └── live_source_config_test.dart
        └── live_source_capability/
            └── live_source_capability_test.dart
```

Test filenames MUST end in `_test.dart`.

For serializable models, test:

- JSON round-trip behavior.
- Required fields.
- Optional fields and defaults.
- Null handling.
- Enum serialization where applicable.
- Compatibility with expected external payloads.
- Equality and `copyWith` behavior when those features are used.

Test observable behavior rather than generated implementation details.

## 10. Code Generation Commands

Run commands from the workspace root unless the repository's tooling explicitly specifies otherwise.

Generate code:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Watch for changes during development:

```powershell
dart run build_runner watch --delete-conflicting-outputs
```

Before committing:

1. Update the handwritten source.
2. Run code generation.
3. Run formatting.
4. Run static analysis.
5. Run tests.
6. Review the generated diff.
7. Confirm the working tree is clean after repeating generation.

Do not run generators from an arbitrary package directory if the workspace's dependency resolution and build configuration require root-level execution.

## 11. Formatting and Static Analysis

Handwritten Dart files MUST follow the workspace's Dart formatting and lint rules.

Recommended commands:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Run the commands in the scope appropriate to the package and workspace.

Rules:

- Do not use multiple competing formatters for Dart files.
- Keep import sorting consistent with the project's chosen lint configuration.
- Do not disable a lint globally merely to silence one warning.
- Do not manually reformat generated output to a style that conflicts with its generator.
- Ensure editor save actions and CI use compatible formatting rules.

## 12. Model Ownership and Package Boundaries

Each model MUST have one authoritative owning package.

For example:

- Live-source definitions belong to `live_sources`.
- Playback-session definitions belong to `live_playback`.
- Plugin manifest definitions belong to the plugin-contract or extension package that owns the contract.
- Shared platform contracts belong to their designated foundational package.

Avoid defining duplicate representations of the same domain concept in multiple packages.

When two packages need similar data, determine whether they share one domain concept or represent distinct boundary-specific models. Do not automatically merge them merely because their fields look alike.

Cross-package imports MUST use public package APIs.

Incorrect:

```dart
import 'package:live_sources/src/models/live_source/live_source.dart';
```

Correct:

```dart
import 'package:live_sources/live_sources.dart';
```

## 13. CI Requirements

The CI pipeline SHOULD verify the following steps in order:

1. Resolve workspace dependencies.
2. Generate code when required by the repository policy.
3. Check that generated output is up to date.
4. Check Dart formatting.
5. Run static analysis.
6. Run package tests.
7. Validate package boundaries and public exports.

The pipeline MUST fail when code generation, formatting, analysis, or required tests fail.

A package MUST NOT be considered ready merely because its source code compiles on the developer's machine.

## 14. Package Acceptance Checklist

Before merging a model-related change, verify:

- [ ] The model belongs to the correct package.
- [ ] The entity has its own directory.
- [ ] The directory and source filename use consistent `snake_case`.
- [ ] The handwritten model and generated files are in the same directory.
- [ ] Generator dependencies are correctly classified.
- [ ] Generator versions resolve with the workspace's SDK and analyzer constraints.
- [ ] Generated files were not edited manually.
- [ ] Public models are exported from the package entrypoint.
- [ ] Tests mirror the source directory structure.
- [ ] Serialization and default values are tested where applicable.
- [ ] Formatting and static analysis pass.
- [ ] CI can reproduce the generated output.
- [ ] No other package imports the model through an internal `src/` path.

## 15. Canonical Directory Rules

The following paths are the canonical convention for PureLive:

| Item | Canonical path |
|---|---|
| Model source | `lib/src/models/<entity>/<entity>.dart` |
| Freezed output | `lib/src/models/<entity>/<entity>.freezed.dart` |
| JSON output | `lib/src/models/<entity>/<entity>.g.dart` |
| Entity-specific helper | `lib/src/models/<entity>/<helper>.dart` |
| Shared model | `lib/src/models/<shared_entity>/<shared_entity>.dart` |
| Model test | `test/src/models/<entity>/<entity>_test.dart` |
| Public entrypoint | `lib/<package_name>.dart` |

**Final rule:** One independently maintained model entity, one directory. Handwritten source, generated files, and entity-specific helpers stay together. Tests mirror the source layout. Consumers access models through the owning package's public API.
