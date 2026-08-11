# How this course actually works

Read this once, before week 1. It's the operating manual: what teaches you, where you
write your answers, and how to get unstuck.

---

## The three teachers

They do different jobs. Don't substitute one for another.

### 1. The week's README — teaches the concepts

`weeks/week-01/README.md` and friends. Written explanation, a worked example built up line
by line, then exercises. This is the lecture, and it's written down on purpose: in week 9
you will have forgotten week 4, and you'll want something to re-read rather than a
conversation to scroll back through.

### 2. Claude — your tutor

That's me. I'm for when you're **stuck**, or when you want your attempt **critiqued**.
I'm not for looking up answers — the material and the solutions already do that better.

Come to me with a specific situation, not "explain joins". Something like:

> I'm on week 4, exercise 4.2. Here's my query: `[paste it]`
> Here's the error I get: `[paste it]`
> I expected 120 rows and got 348. Where am I going wrong?

That gets you a real explanation. `prompts/` has ten pre-written prompts for the common
situations so you don't have to compose one while frustrated.

### 3. `solutions/` — the marking scheme

Answers with reasoning. Several show a wrong version first, because the wrong version is
usually more instructive. **Read after attempting, not instead of attempting.**

---

## Where each thing happens

| Activity | Where | Link |
|---|---|---|
| **Reading the material** | GitHub, or your editor | this repo |
| **Writing and running SQL** | Supabase SQL Editor | [open it](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/sql) |
| **Browsing data without SQL** | Supabase Table Editor | [open it](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/editor) |
| **Seeing the schema diagram** | Supabase Schema Visualiser | [open it](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/database/schemas) |
| **Saving your answers** | `my-answers/week-NN.sql` | in this repo |
| **Getting unstuck** | Claude, using `prompts/` | — |
| **Tracking progress** | `PLANNER.md` checkboxes | [PLANNER.md](PLANNER.md) |

**All queries run in the Supabase SQL Editor.** That's the only place SQL actually
executes. Keep it open in one browser tab and the week's README in another — you'll be
switching between them constantly, and that's the intended rhythm.

---

## A study session, start to finish

Budget ~2.5 hours per week. Split it however suits you.

**1 — Read the concepts** *(~30 min)*
Open the week's README. **Run every example query as you read it.** Reading SQL and running
SQL are different activities and only one of them teaches you anything. Don't take notes;
run queries.

**2 — Work the worked example** *(~20 min)*
It's built up step by step with its real output shown. Before you run each step, predict
what will come back. Then run it. When your prediction is wrong, that gap is the lesson —
stop and work out why before continuing.

**3 — Do the three exercises** *(~60 min)*
Write your own SQL in the editor. They get harder within the week.

> **The 15-minute rule.** Stuck? Stay stuck for 15 minutes before opening the solution.
> Try a smaller version of the query. Run the inner part on its own. Check your column
> names in the Table Editor. That struggle is where the learning is concentrated — skipping
> it feels efficient and teaches you nothing.
>
> After 15 minutes, either come to me or open the solution. Being stuck for 45 minutes
> isn't noble, it's just slow.

**4 — Save your answers**
Paste your working queries into `my-answers/week-NN.sql`. There's a template file waiting
for each week.

**5 — Compare against the solution**
Open `solutions/week-NN.sql`. Don't just read it — **compare it to what you wrote**. The
difference between your query and the solution is the actual lesson. If they're different
but both correct, that's worth understanding too; SQL usually has several right answers.

**6 — Mini-project** *(~30 min)*
One realistic task combining the week's skills.

**7 — Tick the box in `PLANNER.md`.**

---

## Saving your answers

Each week has a template in `my-answers/`. Paste your queries in as you go.

Why bother, when the queries already ran in the browser?

- **The editor forgets.** Your week 2 work will be gone by week 6, and week 6 revisits it.
- **You'll want to see your own progress.** Reading your week 1 SQL after week 9 is a
  genuinely encouraging experience.
- **It's what you'd show someone.** "Here's a repo where I worked through 12 weeks of
  Postgres" is a more credible thing to point an interviewer at than "I did a course".
- **When you ask me for help**, having your attempt written down means you can paste it
  immediately instead of reconstructing it.

Commit whenever you finish a week:

```bash
git add my-answers/ PLANNER.md
git commit -m "Week 4 done"
git push
```

---

## When you get stuck — in order

1. **Read the error message properly.** Postgres errors are unusually good. `column
   "margin" does not exist` means precisely that, and the fix is nearly always in the
   week's concepts section.
2. **Run a smaller piece.** If a three-table join returns nonsense, run the two-table
   version. Then one table. Find the step where it breaks.
3. **Check your assumptions against the data.** `SELECT * FROM customers LIMIT 5` costs
   nothing and settles most "why is this empty" questions. Is the value really `'Storage'`
   and not `'storage'`?
4. **Count your rows.** Got more rows than you expected? That's a join fanning out
   (week 5). Fewer? That's a `NULL` or an `INNER JOIN` dropping rows (weeks 2 and 4).
5. **Ask me.** Use a prompt from `prompts/`. Paste your query *and* the error *and* what
   you expected.
6. **Open the solution.** Not a failure. Just do steps 1–5 first.

---

## The rule about solutions

**Do not open `solutions/` until you have genuinely attempted the exercise** — including
getting it wrong, hitting an error, and trying again.

This is not about discipline for its own sake. Reading a correct query produces a strong
feeling of understanding and almost no actual learning. Writing a broken one and repairing
it is what builds the thing you're here for. The feeling is a poor guide; the struggle is
the mechanism.

If you break this rule occasionally, nothing bad happens. If you break it every week, you
will finish 12 weeks with a strong sense that you know SQL and an inability to write it,
which is a genuinely unpleasant thing to discover in an interview.

---

## If you fall behind

You will. Three hours a week is a real commitment and life happens.

- **Missed a week?** Pick up where you left off. Nothing expires and there are no
  deadlines.
- **Short on time?** Skip the mini-project, never the exercises. The exercises are the
  learning; the mini-project is consolidation, and consolidation can wait.
- **Don't skip weeks 2, 5 or 9.** `NULL` handling, join fan-out, and schema design. Each
  is a topic where "I sort of know this" versus "I actually know this" shows up on a real
  system at an inconvenient hour.

---

## If you break the database

Good — that means you're actually using it.

Run these three files in the SQL Editor, in order, and you're back to a clean state in
about 30 seconds:

1. `db/01_schema.sql`
2. `db/02_seed.sql`
3. `db/03_messy_data.sql`

The seed data is generated arithmetically rather than randomly, so you get **identical rows
every time**. The answers in `solutions/` stay correct no matter how many times you reset.

There is no way to break this permanently, and nothing in it is real. Experiment freely —
that's the entire point of having a practice database rather than learning on production.
