# 16. Notifications: all or none

## Context
Design `Settings` gives each kind of notification its own switch: the daily goal's reminder, the warning before a streak breaks, and a teacher's reply. The owner decided against letting the learner pick among them (2026-11-05).

## Decision
- One switch, «السماح بالإشعارات», sent to the server as `notifications` with the other preferences (docs/api/me.md). The server sends every kind or none.
- The phone has the last word. Turning the switch on asks it first, and a refusal keeps the switch off. A learner who wanted notifications while the phone keeps them off sees the band «الإشعارات متوقفة من إعدادات الهاتف» with «افتح الإعدادات». A learner never asked doesn't.
- The reminder's time stays its own setting, as it is when, not whether.

The design's reading text size («حجم نص القراءة») is left out of the settings by the same decision. It stays in the reader's own Aa button.

## Consequences
A kind of notification added later needs no new switch. Per-kind choices, if they come back, are new preferences fields and rows in the same group.
