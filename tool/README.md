# PureLive package tooling

Repository gates for package layout, required files, and dependency boundaries.
They are parsed with lightweight text matching rather than a YAML parser, which is
adequate for the rules they check and is the reason each one prints its findings as
file and line.

## Files

- `tool/scaffold_package.ps1`: generates a package skeleton.
- `tool/validate_packages.ps1`: validates workspace packages and required files.
- `tool/check_architecture.ps1`: checks selected dependency-boundary rules.

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
and `pagination_core`, whose name has no `live_` prefix. Flip it to fatal when its
count reaches zero; until then a hard gate would only teach people to ignore red CI.

Both scripts used to fail at startup: `$PSScriptRoot` is still empty while a `param()`
block is evaluated under Windows PowerShell, so the default `-Root` resolved against
an empty path. The root is now resolved inside the script body.

## Important limitations

- The scaffold script deliberately does not rewrite root `pubspec.yaml`; add the generated package path to `workspace:` after reviewing the diff. This avoids corrupting YAML formatting or comments.
- The scripts use lightweight text parsing, not a full YAML parser. A rule they cannot see is a rule they will not report; add to them rather than trusting them as complete.
- `live_` naming and required files are checked per *workspace member* read from the root `pubspec.yaml`; a package that is not in that list is invisible to them.
- The generated `analysis_options.yaml` assumes the repository has a compatible root analysis configuration. Adjust relative paths if your repository uses a different package depth.
- The `test: any` and code-generation dependency placeholders must be replaced with versions compatible with the workspace SDK and dependency policy.
