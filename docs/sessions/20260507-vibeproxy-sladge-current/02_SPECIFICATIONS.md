# Specifications

Acceptance criteria:

- Add exactly one Sladge badge to the README badge row.
- Do not modify Swift, app bundle, workflow, or generated assets.
- Preserve canonical detached checkout state; do not integrate into a checked
  out branch.
- Validate with diff hygiene, badge search, and the lightest available build
  metadata checks.

ARUs:

- Assumption: isolated badge evidence is the correct outcome while canonical is
  detached.
- Risk: full macOS build may require local signing/runtime context. Mitigation:
  run lightweight Makefile or Swift package checks when available and record
  blockers exactly.
