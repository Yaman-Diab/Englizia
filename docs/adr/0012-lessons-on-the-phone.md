# 12. Lessons on the phone: preferences for now

Status: Accepted · Date: 2026-10-31

## Context
A lesson opened before must open offline, and no answer may be lost (S §21). D-026 left the storage technology open, and the same preferences already keep the placement test's answers. A database or files would mean a new direct dependency, and the rule is a little code over a package when that is enough.

## Decision
- Lessons are kept as they came, as JSON, in `SharedPreferences`: the last five opened. A lesson's text is a few kilobytes, and nothing else needs querying.
- The oldest go first, but never a lesson in progress, which carries on with the version it started on. Online, a lesson not started takes the newest version.
- Only a network failure falls back to what is kept; a refusal from the server stays a failure.
- Answers wait in order, each with its stable attempt id, in the same preferences. `AnswersSync`, started by `App`, sends them when the app opens with a session and when the connection returns, whether or not a lesson is open.
- An answer the server refuses for good (400, 404, 409, 410, 422) is dropped and logged, so it can't hold back the rest; anything else stays for the next time.

## Consequences
Preferences load whole at startup, so this suits small text only: pictures and clips aren't kept (D-058). Move to files or a database when media or the next lesson's preload (S §21) arrive.
