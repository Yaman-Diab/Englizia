# Contributing

## Branches — GitHub Flow

- `main` is always releasable. Once GitHub protection is on: PR required, CI required, no force-push.
- Every change after the initial setup goes on a short-lived branch:

| Prefix | Use | Example |
|---|---|---|
| `feat/` | new behavior | `feat/auth-email-login` |
| `fix/` | bug fix | `fix/reader-caption-overlap` |
| `refactor/` | no behavior change | `refactor/network-json-reader` |
| `chore/`, `docs/`, `test/`, `ci/` | the rest | `docs/api-auth-contract` |

- Open a PR even when working alone: CI runs and the description becomes the change log. Squash-merge with a Conventional Commit title.

## Commits — Conventional Commits

```
<type>(<scope>): <imperative summary, lower case, no period, ≤ 72 chars>

<body: why the change is needed and what it affects. Wrap at 72.>

<footer: BREAKING CHANGE: ..., Refs #12, Co-Authored-By: ...>
```

**Types:** `feat` · `fix` · `refactor` · `perf` · `test` · `docs` · `build` (deps, Gradle, pubspec) · `ci` · `chore` · `style` · `revert`

**Scopes** (pick the closest; add new feature names as they appear):

| Area | Scopes |
|---|---|
| Kernel | `core`, `network`, `session`, `router`, `design`, `l10n`, `di` |
| App | `app`, `android`, `ios`, `deps`, `release` |
| Features | `auth`, `onboarding`, `tracks`, `learn`, `lesson`, `reader`, `exercises`, `placement`, `wordbank`, `errorbank`, `shadowing`, `conversation`, `profile`, `kids`, `motivation` |

**Rules**
- One logical change per commit (roughly < 400 changed lines). If the summary needs "and" or a comma list, split it (`git add -p`).
- Never mix `feat`, `fix` and `refactor` in one commit.
- The body explains **why**; the diff already shows what.
- A follow-up fix to an unpushed commit: `git commit --fixup <sha>` then `git rebase -i --autosquash` before pushing.
- Tests, translations and docs that belong to a change go in **the same commit**.
- Nothing is pushed without the owner's approval.

**Good**
```
fix(network): send bearer token on refresh request

The refresh Dio has no interceptors, so the header was never attached and
every token expiry logged the user out. Adds a test asserting the header.
```

**Bad:** `update files` · `fix bug` · `feat: login, profile and theme changes` · `WIP`

## Versioning

- SemVer: `0.x` until store launch. MINOR per delivered milestone (v0.1 … v0.5), PATCH per fix.
- Bump `+build` in `pubspec.yaml` on every distributed build; tag `vX.Y.Z` on that commit.
- Record user-visible changes in `CHANGELOG.md` under `Unreleased`.

## Optional local hooks

`lefthook.yml` checks formatting, analysis, commit message format and tests. Install [lefthook](https://github.com/evilmartians/lefthook), then run `lefthook install` once.
