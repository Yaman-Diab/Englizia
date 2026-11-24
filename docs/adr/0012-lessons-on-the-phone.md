# 12. Lessons on the phone: preferences for now

Status: Accepted · Date: 2026-10-31

## Context
A lesson opened before must open offline, and no answer may be lost (S §21). D-026 left the storage technology open, and the same preferences already keep the placement test's answers. A database or files would mean a new direct dependency, and the rule is a little code over a package when that is enough.

## Decision
- Lessons are kept as they came, as JSON, in `SharedPreferences`: the last five opened. A lesson's text is a few kilobytes, and nothing else needs querying.
- The oldest go first, but never a lesson in progress, which carries on with the version it started on. Online, a lesson not started takes the newest version.
- Only a network failure falls back to what is kept; a refusal from the server stays a failure.
- Answers wait in order, each with its stable attempt id and its account's id, in a place of their own that no account's clearing touches (B-28), built once in the server's terms: the lesson's and the question's version, and the lesson's run. `AnswersSync`, started by `App`, sends them when the app opens with a session, when the connection returns and every few minutes, whether or not a lesson is open, and again by itself after a failure, later each time.
- Answers go together (`POST /api/v1/app/sync`, docs/api/lessons.md), the oldest first, and each leaves the phone once the server has said what it did with it, whatever that is; a request that fails whole leaves them all. What else waits (a report, a saved word, watching, a lesson's end) goes one by one after them, and one the server refuses for good (400, 404, 409, 410, 422) is dropped and logged, so it can't hold back the rest.

## Consequences
Preferences load whole at startup, so this suits small text only: pictures and clips aren't kept (D-058). Move to files or a database when media or the next lesson's preload (S §21) arrive.
