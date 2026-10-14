# PureLive package tooling

Repository gates for package layout, required files, and dependency boundaries.
They are parsed with lightweight text matching rather than a YAML parser, which is
adequate for the rules they check and is the reason each one prints its findings as
file and line.

## Files

- `tool/scaffold_package.ps1`: generates a package skeleton.
- `tool/validate_packages.ps1`: validates workspace packages and required files.
- `tool/check_architecture.ps1`: checks selected dependency-boundary rules and the
  shape of each UI style adapter.

## What `check_architecture.ps1` guards

Dependency direction: the UI core may not name a concrete style library, adapters
may not depend on each other, and no package outside an adapter may import or
depend on that adapter's widget library (`fluent_ui`, `macos_ui`, `material_ui`,
`cupertino_ui`, `glass_morphism_plus`, `flutter_neumorphic_ui_kit`,
`fluttersdk_wind`).

Adapter shape, which is §17 of every `live_uikit_*/live-uikit-*.md` specification,
enforced once over the adapter/library map at the top of the script:

- an adapter reaches its library through its documented prefix (`mu`, `cu`,
  `fluent`, `macos`, `glass`, `neu`, `wind`) — never unqualified. `material_ui` and
  `cupertino_ui` deliberately shadow Flutter's own Material and Cupertino names, so an
  unqualified import there silently resolves to the SDK's widgets instead of the fork's;
  for the other five the prefix is the uniform convention that makes the rule checkable;
- the public barrel exports the registration file and nothing else;
- the `*_capabilities.dart` set matches exactly the control methods the adapter
  overrides, so a builder added without declaring it, or a declaration without an
  override, fails the build instead of lying through `LiveUiResolver`;
- the localization-delegate surface matches what each specification's §6/§14 says it
  ships: the `material_ui`, `cupertino_ui` and `fluent_ui` adapters export a delegate
  the composition root must append, and the other four export none — a delegate that
  appears or disappears without the spec saying so under-wires or breaks the host app;
- each adapter README's list of native controls is compared with the capability set,
  and each name it uses must be a real `LiveUiControl` member. Prose that drifts from
  the declaration is what misleads whoever reads only the README;
- each specification's §4 directory tree (for the core and every adapter) is compared
  with the package: a file the current-layout tree names but the package no longer has
  is a stale claim, and a `test/**_test.dart` the tree omits is a test no reader of the
  specification will find. Optional, not-yet-created modules live in a second block and
  are deliberately outside the check.

Adding an adapter means adding one entry to that map; every rule above then covers
it automatically. Three of these rules read prose (the README list, the delegate
expectation, the §4 tree), so they assert that the *documented* claim matches the code;
they do not prove the claim is the design anyone wants — that is still review.

## Running

```powershell
.\tool\scaffold_package.ps1 -Name live_uikit_fluent -Category ui -Type flutter
.\tool\scaffold_package.ps1 -Name live_result -Category foundation -Type dart
.\tool\validate_packages.ps1
.\tool\validate_packages.ps1 -CheckFormatting
.\tool\check_architecture.ps1
```

`check_architecture.ps1` runs as a fatal gate in `.github/workflows/architecture.yml`.
`validate_packages.ps1` runs in the same job as a report (`continue-on-error`) because
it currently lists 57 pre-existing gaps — packages without `README.md`/`CHANGELOG.md`/`test/`,
and `live_pagination`, whose name has no `live_` prefix. Flip it to fatal when its
count reaches zero; until then a hard gate would only teach people to ignore red CI.

Both scripts used to fail at startup: `$PSScriptRoot` is still empty while a `param()`
block is evaluated under Windows PowerShell, so the default `-Root` resolved against
an empty path. The root is now resolved inside the script body.

## Important limitations

- The scaffold script deliberately does not rewrite root `pubspec.yaml`; add the generated package path to `workspace:` after reviewing the diff. This avoids corrupting YAML formatting or comments.
- The scripts use lightweight text parsing, not a full YAML parser. A rule they cannot see is a rule they will not report; add to them rather than trusting them as complete.
- The adapter-shape checks are textual by design: they read import directives, and the drift check recognises an override as a `Widget <control>(` signature in the adapter file, ignoring `wrap` and names starting with `_`. An override written in a shape that regex does not match reads as "not overridden", and a builder that never reaches the adapter class is invisible to it.
- `live_` naming and required files are checked per *workspace member* read from the root `pubspec.yaml`; a package that is not in that list is invisible to them.
- The generated `analysis_options.yaml` assumes the repository has a compatible root analysis configuration. Adjust relative paths if your repository uses a different package depth.
- The `test: any` and code-generation dependency placeholders must be replaced with versions compatible with the workspace SDK and dependency policy.
