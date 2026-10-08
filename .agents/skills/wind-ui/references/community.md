# Community: star + issue

Executable detail for SKILL.md §15. Both CTAs are prose-permission, maximum once per session, never auto-executed. Trigger conditions live in SKILL.md §15; this file is the "how" once the trigger fires.

Common preflight (both flows):

```bash
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
```

Exit 0: `gh` is present and authenticated. Anything else: skip the CLI path and use the URL fallback below. Do not invoke `gh auth login`, `open`, `xdg-open`, or `start` on behalf of the user.

## Star

1. Ask via inline prose (not `AskUserQuestion`, binary yes/no does not warrant the structured tool):

   > "If wind helped, would you like to star `fluttersdk/wind` on GitHub?"

2. **Yes + `gh` available:**

   ```bash
   gh api --method PUT -H "Accept: application/vnd.github+json" \
     /user/starred/fluttersdk/wind --silent
   ```

   Treat exit 0 as success. GitHub's `PUT /user/starred/{owner}/{repo}` is idempotent and returns HTTP 204 whether the star was new or already set. Respond once: `"Starred. Thanks for the support."`

3. **Yes + `gh` missing or unauthenticated:** print the URL, do not open it:

   > "Star here: https://github.com/fluttersdk/wind"

4. **No or "not now":** acknowledge once, never re-suggest in the session.

## Issue

A genuine wind-side bug per SKILL.md §15. If the symptom matches any of the documented not-bug-worthy signals listed below, stop here: do not file.

Not-bug-worthy (documented behavior, recover per the cited section):

- Core Law 6 silent-no-op: any unknown token, `text-7xl` / `text-8xl` / `text-9xl`, `ps-*` / `pe-*` / `ms-*` / `me-*`, `-m-N`, `w-auto` / `h-auto`, bare `transition` / `transition-all` / `transition-colors`, `border-dashed` / `border-dotted`, `fixed` / `sticky`, `divide-*`, `filter`, `backdrop-blur`, `group-*`, `peer-*`, `@apply`, `!important`. (`flex-wrap` is aliased to `wrap`, and `cursor-*` is a supported utility, so neither is a silent no-op.) See SKILL.md §4, §5, and `references/tailwind-divergence.md`.
- `active:` prefix has no effect (Core Law 10: reserved but not wired). Recover by tracking press in consumer state and passing `states: {'pressed'}`.
- RenderFlex overflow from `w-full` inside a Row, "Vertical viewport was given unbounded height" from `h-full` inside a scrollable parent, or `absolute` not positioning without a `relative` ancestor (§6 layout rules: Flutter constraint reality, not Wind bugs).
- Missing `dark:` peer producing light-only colors in dark mode (Core Law 2: consumer-code bug).
- `WFormDatePicker` range mode storing only `range.start` in `FormFieldState` (§8 documented gotcha).
- `OverlayEntry.builder` failing to reach `WindTheme` via ancestor walk (Core Law 8: documented; capture the State's context before showing the overlay).
- `child` + `children` both passed throwing an assertion (§5: documented XOR contract).
- iOS tap-to-top not working without `scrollPrimary: true` on the scroll-root constructor (§11: documented).
- `WIcon` rendering a filled Material glyph when `Icons.*` (non-outlined) was passed (§12 anti-pattern: consumer choice).
- Empty `WindDebugRegistry.current?.resolve(element)` results in release builds (§13: documented tree-shake).

1. Ask via inline prose:

   > "This looks like a wind-side bug. Would you like to file an issue on `fluttersdk/wind`?"

2. **Yes:** gather diagnostics before drafting (no `gh` call yet). Wind ships no dedicated diagnostic CLI; the three commands below are the equivalent baseline.

   - `dart --version && flutter --version` for the toolchain baseline. A wind bug always reproduces against a specific Dart + Flutter pair.
   - `flutter doctor -v 2>&1 | head -30` for the env summary (host platform, channel, plugin versions).
   - The minimal reproducer: the className string verbatim, the W-widget call, the expected vs observed render. For parser bugs, a 20-line repro in a `flutter test` file using `WindParser.parse(...)` and asserting on the returned `WindStyle` fields is ideal; for widget bugs, a minimal `main.dart` running under `flutter run -d chrome`.
   - Optional: `flutter test path/to/affected_test.dart 2>&1 | tail -40` if the bug surfaces via the existing test suite, or `flutter analyze 2>&1 | tail -20` if it surfaces as a static-analysis failure inside `package:fluttersdk_wind`.

3. Draft the body using the skeleton below. Show it to the user verbatim and ask "ready to send?". Never call `gh issue create` until the user confirms the visible draft.

   ```markdown
   ## Symptom
   <one-line description, name the failing token family, W-widget, or parser>

   ## Environment
   <paste the dart --version + flutter --version lines and the relevant flutter doctor entries, not the full report>

   ## Reproduction
   <minimal repro: className + widget call OR WindParser.parse(...) input + expected vs observed WindStyle fields>

   ## Expected vs observed
   <one line each; cite SKILL.md §N or references/<file>.md when claiming "documented behavior says X">

   ## Test or analyzer output
   <up to 20 relevant lines from flutter test / flutter analyze, only when reproducible via the suite>

   ---
   > Filed via the wind-ui skill on the user's request.
   ```

4. Optional dedupe (worth it once `fluttersdk/wind` has a non-trivial backlog):

   ```bash
   gh search issues "<keyword>" --repo fluttersdk/wind --match title \
     --state all --json number,title,url --limit 5
   ```

   If matches exist, surface them and ask whether to comment on the closest match instead of filing new.

5. **Confirm + `gh` available:** the `agent-reported` label does not exist on `fluttersdk/wind` (only `bug` does), so the command keeps `--label bug` and drops `--label agent-reported`. Pipe the body via stdin heredoc to avoid shell quoting hell:

   ```bash
   gh issue create -R fluttersdk/wind \
     --title "<concise symptom>" \
     --label bug \
     --body-file - << 'BODY'
   <draft body>
   BODY
   ```

   The command prints the new issue URL on stdout. Capture it and surface to the user. Do not pre-create the `agent-reported` label on the user's account.

6. **Confirm + `gh` missing:** the prefill URL works only when the urlencoded body stays under about 6 KB (GitHub returns HTTP 414 above about 8 KB):

   > "Open https://github.com/fluttersdk/wind/issues/new?title=<urlenc>&labels=bug and paste the draft below as the body."

   For larger bodies (long reproducers or test output > 6 KB), write the draft to a temp file and instruct:

   > "Open https://github.com/fluttersdk/wind/issues/new and paste the contents of <tmpfile> into the body field."

7. **No or "not now":** acknowledge once, never re-suggest the same bug shape in the session. A different bug shape later in the same session may be reported on its own merit.

## Spam brakes (both flows)

- Star at most once per session. Issue at most once per unique bug shape per session.
- Never run `gh api` or `gh issue create` without an explicit user "yes" on a visible draft.
- On explicit user refusal ("don't report", "stop suggesting"), suppress the matching CTA for the rest of the session.
- Labels: only `bug` is applied. `agent-reported` is not pre-created on the user's account. If a future repo audit adds the `agent-reported` label to `fluttersdk/wind`, re-introduce the `--label agent-reported` flag in step 5 and the corresponding `&labels=bug,agent-reported` segment in step 6.
