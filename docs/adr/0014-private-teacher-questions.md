# 14. Questions to the teacher are private

## Context
S §17 and the design "Grammar Video" have a public section under the video: every learner's questions by name, with "report this question" and "block this student", as Google Play requires for content users publish to each other.

The owner decided otherwise (2026-11-01): one learner's question must never appear to another. Each learner has their own questions and the replies of the teacher or the admins to them.

## Decision
This overrides S §17 on what a learner sees.

- A learner sees only their own questions and the replies to them, on that lesson. The section is called «أسئلتك للمدرس» and says who can read it.
- Privacy is the server's to enforce: `GET .../questions` answers with the caller's questions and nothing else. The app has no filter to rely on, and never receives anyone else's.
- A reply carries who wrote it and their role, teacher or admin, as both may answer.
- Reporting a question, blocking a student, "hidden from students" and accepting terms before a first question are not built: they exist for what learners publish to each other, and nothing here is published.

## Consequences
The panel's questions page stays as a teacher's inbox, but a reply goes to one learner only, and SV's moderation of public questions needs the backend's review. The empty state, «اسأل أول سؤال، والمدرس يرد عليك هنا», still holds. A question can't be answered once for the whole class: if the owner wants that later, it is a new feature, not a setting.
