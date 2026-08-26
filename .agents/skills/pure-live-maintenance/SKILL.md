---
name: pure-live-maintenance
description: Triage Pure Live bugs, review upstream changes or upstream Issues, and integrate fixes while preserving the Android/Windows maintenance fork's behavior and evidence requirements.
---

# Pure Live Maintenance

<!-- maintenance-skill-markers: bug-provenance-required; semantic change ledger -->

Read [`../../../MAINTENANCE_POLICY.md`](../../../MAINTENANCE_POLICY.md) whenever a task reports a Bug, requests an upstream sync, asks to inspect upstream Issues, or changes repository maintenance rules.

## Bug workflow

1. Freeze the current fork SHA, relevant upstream SHA and merge base.
2. Reproduce from source, deterministic tests, logs or interface fixtures before editing.
3. Classify the source as `upstream-existing`, `fork-regression`, `integration-conflict`, `external-drift`, `environment-or-data`, or `not-reproduced`.
4. Trace the first invalid state and its call/event lifecycle. Do not treat the final UI symptom as the root cause.
5. Select direct reuse, adapted merge, compatibility layer or local rewrite based on product invariants and regression surface.
6. Record affected modes, focused regression evidence, migration/rollback behavior and remaining evidence gaps.
7. Apply `bugfix-android-release-default` after the repair batch passes: increment one patch/build version, complete the local Android arm64 Release gate, sync `master`, publish the fixed-certificate GitHub Release, and refresh the release index. Related fixes in the same user task share one version; other platforms remain explicitly scoped.

## Upstream workflow

Before merging, also read [`../../../UPSTREAM_REVIEW_POLICY.md`](../../../UPSTREAM_REVIEW_POLICY.md) and run `tool/review_upstream_update.ps1`. Review the three-way history and every incoming file. The committed audit must include the semantic change ledger, issue/Bug mapping, fork-feature impact, quality assessment, explicit disposition and regression plan required by the gate.

Feature requests filed against this maintenance fork route to the original project. Local Issue work focuses on reproducible maintenance regressions, with Android first and Windows as the other primary maintained target.

Use [`../../../BUILD_POLICY.md`](../../../BUILD_POLICY.md) only when validation, packaging or release commands are part of the current task.
