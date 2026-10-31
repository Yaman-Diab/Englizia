# 11. The exercise engine: one session, sealed templates, no extra layers

Status: Accepted · Date: 2026-10-31

## Context
The requirements define 17 exercise templates (S §7.3, server doc §20.6) that differ a lot: matching and the kids' mode have no check button, reading is several steps in one question, speech can't be wrong, an AI answer can be pending. A proposal for an "Exercise Engine" asked for a session page, an engine, a renderer, type components, shared UI, sealed models, an evaluator and a versioned contract. The first three templates had shown what breaks: one `selectedId` in the state, marking inside a widget, widgets reading the cubit.

## Decision
- **`ExerciseCubit` is the engine.** It runs the session: current question, draft, evaluation, hint, progress, clip. There is no engine layer over it, and one cubit per template would repeat all of that (ADR 1).
- **What goes in the cubit:** whatever the button, the marks or the attempt need, or what outlives the question. What only draws a question stays in its widget (the active blank, a held card, a text controller). Speech has its own small cubit, `MicCubit`, like an interactive sheet under ADR 1.
- **`exerciseBody()` is the renderer:** one exhaustive `switch` on the sealed `Exercise`. No registry or factory: the set of templates is closed, each needs its own code anyway, and a registry loses the compiler's check. "A new track needs no code" is about tracks and content, not templates.
- **Bodies take props** (`BodyAnswer`, `BodyClip`) and never read the session's cubit, so a concept review (S §11.2) can show them too. A body with no check button asks for the check itself (`onSubmit`, `Exercise.checksItself`).
- **Word cards fly in one place,** `ChipStage`: it measures a card, lets the answer change, then flies it on its own layer. Nothing outside the stage rebuilds per frame.
- **Sealed `Exercise`, one class per template; sealed `ExerciseDraft` and `Evaluation`, one class per way of answering.** About seven drafts will cover the 17 templates (choice, slots, sequence, pairs, text, speech, error correction). Only what a built template uses exists; the rest is added with its template.
- **`evaluate()` is a pure function in domain,** for instant feedback offline (S §7.1). The server marks again and its result is the official one (S §2). The learner's screen doesn't change if they differ; completion and points follow the server.
- **The order of options is the phone's:** `stableOrder` by installation and question. The lesson is cached and the same for everyone, and chips are split on the phone, so the server can't do it.
- **Progress is by question id,** not position, so a new version or a hidden question can't misplace the learner. A checked question counts as done, so leaving after checking returns to the next one and can't answer it twice; "the same question" (S §7.1) applies to one not answered yet.
- **The contract follows server doc §20.6** under the API's rules: the discriminator is `template`, flat, in camelCase with lower-camel enum values (`docs/api/README.md`). No JSON Schema on the phone: the server validates on import (server doc §21), and fixtures test the parser.
- **Placement stays out of the engine.** It has no keys, hints or feedback; it shares only small pieces in core.

## Consequences
A new template means a subclass, a body, a parser case, an evaluator case and tests; the compiler points at each `switch`, and other templates' files don't change. Adding a draft family breaks the exhaustive `switch` in `evaluate` and `attemptToJson` on purpose.
