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
- `tool/check_prefs_manifest.ps1`: re-derives every `StoragePrefs` key and the kind
  its call sites speak, and fails when `kBackedUpPrefs` or `kSettingsProviders`
  disagrees with what the code actually does.
- `tool/check_settings_ia.ps1`: re-derives the settings surface's four copies of the
  same fact — section registry, module menu, pane dispatch, search catalogue — and
  fails when they disagree about which page a row lives on.

## What `check_settings_ia.ps1` guards

`SettingsSection` is written down four times over: the enum itself, the module menu
(`kModuleNavigation`), the pane `switch` in `settings_page.dart`, and the hand-maintained
search catalogue. A round that adds a row to the wrong page, or that leaves a search hit
naming a section the menu no longer lists, compiles and runs — it just navigates to the
wrong place. The gate parses all four and checks the invariants the settings redesign is
built on:

- every section is exactly one of sidebar row / subpage / deep-link alias, and every
  alias resolves to a real page (no alias chains, no alias that is also a row);
- `parentSection` and `settingsChildrenOf` agree, a subpage's parent is a row the menu
  actually lists, and no subpage hangs another subpage off it — which is what keeps the
  surface at two page levels and the breadcrumb at three segments;
- every section has a pane case, and an alias case renders exactly its canonical page's
  pane, so a stored deep link cannot land on a page its merge removed;
- every subpage is opened from its parent's pane (`SettingsChildEntry`, `openSettingsChild`
  or a `settingsChildrenOf` list), so no page exists only in the enum;
- every search hit names a real page that some module menu can open, every page has at
  least one hit, and the hit's label key appears among the files that page renders.

The last check is weaker than it reads, and knows it: while the private panes share
`settings_page.dart`, that file imports the whole settings surface, so the reachable set
contains every label and a hit re-hung on another *real* page still passes. What it does
catch is a label that disappeared. Extracting each pane to its own file narrows the reach
to the page and turns it into a real attribution gate. The stricter reading — the pane's
own file only — was measured on the current tree at 27 false positives (a pane that is a
shell over another file, and page-level hits whose title key names the page, not a row),
so it is not enforced behind an exemption table.

Like its sibling gate, it takes `-Root` so a throwaway copy of the tree can be used to
prove a check bites; the checks were verified that way rather than by trusting a green run.

## What `check_prefs_manifest.ps1` guards

The settings manifests sit beside code that already knows the answer, so they drift
the moment a surface adds a pref. The gate reads the app (and the packages, to
catch a package that starts owning keys) and checks four things:

- a pref key with no `kBackedUpPrefs` entry, which means a backup silently loses it
  and a restore can never bring it back;
- a `kBackedUpPrefs` kind that no call site speaks, which means capture reads the
  wrong typed getter and the key never enters the document;
- a `kBackedUpPrefs` entry no call site uses any more;
- a `NotifierProvider` whose controller reads `StoragePrefs` but which is missing
  from `kSettingsProviders`, so a restored backup or another window's write leaves
  it serving its old values.

Run it as part of the settings gate: a new pref is only finished once it appears in
`kBackedUpPrefs` with the kind its call sites speak, and in `kSettingsProviders` when a
controller reads it.

Keys reach the facade in three shapes and all three are resolved: a literal
argument, a `const`/`static const` name (file-scoped, taking the declaration above
the call site, since one file reuses `prefsKey` across classes; unambiguous
cross-file names resolve too), and a file-local helper that takes the key as a
`String key` parameter (its call-site values are collected under the kind the
helper's own body speaks). A computed key — `window.pip.<orientation>`,
`vod.progress.<bvid>` — cannot be resolved this way, so it is printed for review
instead of failed on; adding such a key to a backup is a deliberate edit.

Two exemptions are tables in the script, each with the sentence that justifies it:
`recorder.saveDir` (a legacy fallback read, never written) and the controllers a
window keeps to itself (navigation state, and the live window-size tracker). A new
exemption has to carry a reason, not just a name.

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
.\tool\check_prefs_manifest.ps1
.\tool\check_settings_ia.ps1
.\tool\check_settings_ia.ps1 -Root .\.tmp\copy-of-repo
```

The last line is how the settings gate's checks were proven to bite: `-Root` points it at a
throwaway copy of the tree, where a drift can be injected without touching the working tree.

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
