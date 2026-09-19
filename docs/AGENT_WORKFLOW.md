# Agent task and workflow routing

This is an on-demand execution map. AGENTS.md contains session defaults; BUILD_POLICY.md owns resource/signing rules; MAINTENANCE_POLICY.md owns bug provenance; UPSTREAM_REVIEW_POLICY.md owns merge review. Do not duplicate those rules in new skills.

## Select the evidence needed

| Change | Start with | Completion evidence |
| --- | --- | --- |
| Instructions, prose, links | Changed files and direct references | Link/frontmatter checks, `git diff --check` |
| Workflow/config/scripts | Changed configuration and callers | YAML/PowerShell/Python syntax plus relevant static policy checks; no live dispatch by default |
| UI styling/text | Affected widget and constraints | Targeted layout check where behavior/overflow is at risk; no mechanical test for every label |
| Parser/API contract | Real or sanitized response and parser callers | Positive/negative fixture tests; external probe only when necessary |
| Platform registration or capability expansion | Registry, bundled locale labels, settings migration and shared consumers | `test/sites_test.dart` plus the affected adapter, migration, search and recording contracts; do not treat adapter-only tests as application coverage |
| Player/lifecycle/recording | State/event sequence, ownership and disposal | Reproduction plus adjacent pause/exit/source-change regressions; native/device evidence when in scope |
| Upstream merge | Frozen fork/upstream/base and all incoming changes | Full semantic audit required by UPSTREAM_REVIEW_POLICY.md, then affected regression |
| Formal release | Clean source commit and completed repair batch | Full quality gate and platform-specific artifact/signing/publication verification |

Run analyze once after Dart edits settle. Reuse successful checks only when their inputs remain unchanged; failures, new changes and unresolved risk justify another check. Stop expanding validation when acceptance is satisfied. Do not invent a fixed elapsed-time soak or claim whole-repository semantic review from a file scanner.

For code-only changes that still require native acceptance later, preserve the exact pending scenario and build SHA. Device presence is not a prerequisite for code diagnosis. Logs and historical audit reports are evidence, not current instructions.

### Rapid Issue and bug lane

Use this lane before a bespoke investigation. Its purpose is to reach the first decision with one read of each input and to stop work that cannot change the current product.

1. Freeze `HEAD`; read the Issue body/comments once and map its reported version to a local tag.
2. Search the affected paths, `tag..HEAD` commits, exact test names and existing reports. Retrieve matching sections by path; do not load the full documentation chronology.
3. Record the decision in [ISSUE_TRIAGE_LEDGER_3_2_0.md](ISSUE_TRIAGE_LEDGER_3_2_0.md):
   - `already-fixed`: cite the current commit/test. Stop unless the current inputs differ or the cited contract has changed.
   - `present`: add the smallest deterministic red test, fix the first invalid state, run the affected group, then analyze once after Dart edits settle.
   - `not-reproduced`: state the missing discriminator and the exact event that reopens investigation; do not loop on equivalent probes.
   - other maintenance classifications follow `MAINTENANCE_POLICY.md`.
4. Batch independent read-only Issue decisions into one ledger commit. Keep code fixes independently reversible, but run shared affected tests once after the batch settles.

An unchanged `already-fixed` decision does not create another issue-specific report, add a duplicate acceptance timeline paragraph, run full analysis, build a client, browse screenshots again or start a device session. A detailed audit remains appropriate for a current code change, a complex ownership/data migration decision, a release artifact, or evidence that future maintainers need beyond the ledger row.

### Documentation ownership

Update only the owner of the information; avoid copying the same batch narrative across large files.

| Information | Authoritative owner | Update rule |
| --- | --- | --- |
| Public features, install/use guidance | root `README.md` | Only user-visible behavior or delivery changes |
| Documentation navigation | `docs/README.md` | Stable topic/ledger links, not every individual audit |
| Issue classification and reopen trigger | `ISSUE_TRIAGE_LEDGER_3_2_0.md` | Every completed Issue triage; compact rows |
| 62 Android/Windows acceptance states | `ACCEPTANCE_MATRIX_3_1_0.md` | Only when row evidence or state changes |
| Current totals and major release blockers | `ACCEPTANCE_STATUS_3_2_0.md` | Snapshot changes, not routine per-Issue prose |
| 3.2.0 execution order and gates | `ACCEPTANCE_3_2_0.md` | Procedure changes; its historical timeline is frozen |
| Full client case catalog | `FULL_CLIENT_TEST_PLAN_2026_08_28.md` | New/changed user-observable cases only |
| Root cause/design/release evidence | focused audit/stage document | Only when the compact ledger is insufficient |

This ownership map supersedes the older habit of inserting the same result into the root README, both acceptance narratives, the matrix and the docs index. Historical timelines now live in `ACCEPTANCE_HISTORY_3_2_0.md`, `ACCEPTANCE_STATUS_HISTORY_3_2_0.md`, `ACCEPTANCE_MATRIX_HISTORY_3_1_0.md` and `README_HISTORY_2026_09_19.md`; treat them as read-only evidence and never append current status to them.

Read the compact active files first. Open a history archive only when a current row, Issue or audit links to an older batch whose exact evidence is needed. Do not load an archive merely to answer current progress, choose the next test, or repeat a completed investigation.

The 2026-09-19 audit baseline contained 498 Markdown files (about 3.64 MB). `ACCEPTANCE_3_2_0.md` and `ACCEPTANCE_STATUS_3_2_0.md` alone held about 473 KB and repeated the same recent batch summaries. The ownership table and frozen timelines address that measured duplication without deleting historical evidence.

## Local entrypoints

- `tool/validate_build_policy.ps1`: static repository policy checks, no Flutter/Gradle/ADB.
- `tool/validate_agent_workflow.py`: instruction links and workflow graph/trigger invariants (requires Python 3.11+ and PyYAML in the developer environment).
- Acceptance status, numbered matrix or platform-count changes: `python -m unittest discover -s tool/tests -p test_acceptance_status_alignment.py`; checks all 62 unique A/W rows, current PASS/RUN/NR totals and the registered-site count against the platform-expansion head.
- Release text/input changes: `python -m unittest discover -s tool/tests -p test_release_workflow_data.py`; needs Bash (Git Bash on Windows, optionally selected by `BASH_EXE`). Executes only tag validation and Markdown rendering in temporary directories; no release calls.
- `tool/local_ci.ps1 -Scope Focused -TestPath <paths> [-Analyze] [-SkipPubGet]`: affected code verification. It skips repository-wide policy/device-fixture audits by default; add `-IncludeRepositoryChecks` only when those owners changed or a diagnostic explicitly needs the combined preflight.
- `tool/local_ci.ps1 -Scope Full`: formal delivery quality gate.
- `tool/build_local_release.ps1 -Target <target> -Configuration <Debug|Release>`: one selected platform. Use documented evidence-based retry flags, not ad-hoc shell builds.

The quality/build entrypoints already acquire the heavy-task lease. Direct Flutter/Dart/Gradle commands acquire it explicitly; do not nest leases. No automatic setup build or dependency resolution on opening a workspace.

## GitHub workflow routes

GitHub Actions remain explicit fallback/signing infrastructure; local Android/Windows builds are preferred. This table selects an existing path, not permission to dispatch it.

| Route | Use |
| --- | --- |
| `audit-upstream.yml` | Read-only incoming-change inventory; no merge |
| `feature-build.yml` | Main hosted fallback; selected platforms run serially. Sole owner of `stage-linux-*`, `stage-macos-*`, `stage-ios-*` tag triggers |
| `build_pure_live_release.yml` | Manual legacy/all-ABI compatibility entrypoint; no stage-tag trigger |
| `build-ios-unsigned.yml` | Explicit manual standalone iOS build; no duplicate tag build |
| `local-signed-android.yml` | Explicit self-hosted Android fallback |
| `sign-staged-android.yml` | Sign/verify the already locally built APK using repository Secrets |
| `publish-signed-android.yml` | Verify and publish an existing signed artifact |
| `stage-hosted-artifacts.yml` | Validate source identity and attach hosted artifacts to a draft |
| `publish-staged-release.yml` | Verify a coordinated all-platform release and selected Windows source |
| `update_releases.yml` | Manually update the release index on master |

Do not run both primary and legacy builders for one deliverable. Release mutation stages are sequential; inspect a prior run's terminal result before dispatching another. A selected platform's failed/cancelled build blocks downstream builds and publication, even when an intermediate unselected job is skipped. Build cancellation must not interrupt another workflow sharing its group. A concurrency group is not a durable FIFO job queue; callers wait for a terminal result between runs.

Keep stable workflow filenames/artifact names for existing callers. Consolidating all legacy signing and packaging implementations requires a separate artifact-equivalence review; removing duplicate triggers does not warrant rewriting thousands of packaging lines.

Pass free-form workflow inputs and release text through environment variables or files, not GitHub-expression interpolation into `run` scripts. Validate their values before using them; script generation happens before shell validation. Static workflow checks guard this boundary without dispatching a build.

## Model and task handoff

The runtime controls model and reasoning effort. Reserve **Astra Light** for Windows client acceptance that genuinely requires Computer Use visual interaction. Astra is especially strong at Computer Use, but its higher cost makes it a focused GUI-test resource rather than the general-purpose model. When GUI testing begins, create exactly one Astra Light task for the Windows acceptance batch and reuse that same task for every GUI check until the batch is complete; do not create one task per screen or test case. Treat this as a strict cost guardrail: the complete GUI batch gets one Astra Light task in total, while all work outside that batch gets zero Astra usage. Source review, ordinary tests, builds, documentation, Android work and other non-Computer-Use checks use the regular configured model. Agent/build files have no OpenAI API request settings, so writing model API parameters into them does not configure the running Codex session. Optimize useful context and evidence, not token count or parallelism in isolation. Record this rule once in the workflow; routine status updates and focused audit documents omit unchanged policy text and zero-usage boilerplate.

For long work, retain a concise checkpoint: current request, changed paths, evidence already passed, failures/pending acceptance and the next action. New user scope changes take effect immediately; preserve previous uncommitted work separately. Ask a focused question only when the missing answer changes the outcome, while continuing independent authorized work.

Keep task-specific device status, temporary merge freezes, running command IDs and past failures in that checkpoint or an acceptance record, not permanent AGENTS/skill defaults. After a handoff, verify Git state and the current request before resuming a historical next action. Retrieve relevant report sections by path rather than repeatedly loading entire histories. For asynchronous tools, wait on the returned task/session ID; launch a replacement only after checking the prior attempt's outcome.

Use subagents only with an explicit request under AGENTS.md. Delegate bounded independent work if requested, avoid competing writes, and keep resource/device gates serial. No blanket maximum-effort, forced delegation or repeated full-test mandate.
