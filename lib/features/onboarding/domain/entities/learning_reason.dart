/// Why the learner studies English: the multi-select answer of the "why"
/// step, kept on the learner's profile (requirements v3.0 §4.2).
// ASSUMPTION(api): the value names double as the wire values sent with the
// account (docs/api/README.md); not confirmed by the backend team.
enum LearningReason { communication, fun, education, travel, career, exams }
