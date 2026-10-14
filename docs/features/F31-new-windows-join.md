# F31: New windows join the arrangement

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: superseded by [F23](F23-automatic-docking.md) (automatic docking)
Reference items: T16, T18, T19 (inferred)

The audit of 2026-10-14 ranked this second among what TrellisWM has and Arbor
lacks: "Past the limit, new windows float on the Desktop" (T19) and "Don't Arrange [app]" (T18) only make sense if TrellisWM arranges
new windows without being asked, while Arbor floats every one unless a rule names its app's exact bundle id.

F23 was already being built for the same thing when this number was taken, with the same setting (`newWindows`: `"float"` or `"dock"`),
guards for small and fixed-size windows, and `"app": "*"` in rules. This file stays only so that references to F31 (F57, QUESTIONS Q13)
lead somewhere. What a new window does while one window is framed is F57's question. Which default TrellisWM's behaviour calls for is Q13.
