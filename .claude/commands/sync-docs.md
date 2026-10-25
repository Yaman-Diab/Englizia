---
description: Compare the current diff with CLAUDE.md and docs/ and fix statements that are no longer true
---

1. Run `git diff main...HEAD --stat` and `git diff` (staged and unstaged) to see what changed.
2. For each change, check whether `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/api/README.md`, `docs/STATUS.md`, `docs/adr/`, `README.md`, `CHANGELOG.md` or `RELEASE.md` now say something false or incomplete.
3. Edit those statements so the docs describe the **current state** (no history, no volatile numbers). New lasting decisions get a new ADR.
4. Add user-visible changes under `Unreleased` in `CHANGELOG.md`.
5. In `docs/STATUS.md`: move finished Deferred rows out, add rows for anything the diff skipped or stubbed, and fix the feature table (status and mock/connected/confirmed).
6. Keep `CLAUDE.md` under ~150 lines.
7. Show the doc diff and propose a `docs(...)` commit. Do not push.
