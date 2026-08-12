# 1. Adjust my learning plan

**Use when:** the pace is wrong, your goal shifts, or you want to re-plan after week 12.

The original version of this prompt built a plan from scratch. Yours already exists in
[`PLANNER.md`](../PLANNER.md), so this version is for *changing* it — which is the more
useful job once you've started.

---

```
Act as a patient SQL instructor. I am a beginner working through a structured
12-week PostgreSQL course aimed at database administration and data engineering,
with some application development. I study under 3 hours per week.

Here is my current plan:
«paste PLANNER.md»

I have completed weeks «1-N». What I want to change:
«e.g. "I have more time now, ~6 hours a week" / "I want to move toward
application development instead" / "week 5 took me three weeks and I want to
slow down" / "I have a job interview in 4 weeks and need to prioritise">

Revise the remaining weeks only. Do not repeat material I have already covered.
For each revised week give: the concepts, why that concept matters for my goal,
and roughly how long it should take at my stated pace.

Be honest if my request is unrealistic — if I am asking to cover something in
less time than it genuinely takes, say so and tell me what to cut instead of
quietly compressing everything.
```

---

**Why the last paragraph matters.** Without it you will get a plan that fits whatever
timeframe you named, because that is what you asked for. Plans that fit by pretending the
material is smaller are how people end up three weeks behind and assuming it's their fault.
