---
name: pure-live-maintenance
description: Diagnose Pure Live bugs and review upstream Issues or code changes while preserving fork behavior. Use for bug fixes or upstream reviews; not ordinary wording edits or standalone builds.
---

# Pure Live Maintenance

<!-- maintenance-skill-markers: bug-provenance-required; semantic change ledger -->

Use [MAINTENANCE_POLICY.md](../../../MAINTENANCE_POLICY.md) for provenance and product invariants. Read only the sections relevant to the task.

- Trace the symptom to the first invalid state, its owner and affected modes. Record the local SHA and evidence-backed provenance; inspect relevant upstream history as needed. Pending provenance does not block an independently supported local repair.
- Build a focused reproduction, fix the cause and check callers. Use [AGENT_WORKFLOW.md](../../../docs/AGENT_WORKFLOW.md) for risk-based regression, especially lifecycle, retries, persistence and source switches.
- Actual upstream integration requires [UPSTREAM_REVIEW_POLICY.md](../../../UPSTREAM_REVIEW_POLICY.md)'s semantic change ledger for every incoming commit/file. Read-only comparison is separate from merging.
- Delivery follows `bugfix-android-release-default` in [BUILD_POLICY.md](../../../BUILD_POLICY.md); retain pending evidence and respect an analysis-only/deferred request.

Device access and Issue intake follow AGENTS.md.
