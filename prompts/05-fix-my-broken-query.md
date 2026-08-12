# 5. Fix my broken query

**The one you'll use most.** Reach for it the moment an error stops making sense, or a result
looks wrong.

---

```
Act as a senior data analyst reviewing a beginner's SQL.

What I am trying to get: «desired result, in plain English».

My query:
«paste query»

What happened:
«paste the exact error message, OR the wrong output, OR "it runs but returns
N rows and I expected M"»

Schema:
«schema»

Dialect: PostgreSQL 17.

Please:
1. Identify the exact cause. Not a list of things it might be — the actual
   reason, and how you can tell from what I gave you.
2. Give me the SMALLEST possible corrected query. Do not rewrite it in your
   style; change what is broken and leave the rest alone so I can see the diff.
3. Explain the fix in plain English.
4. Tell me how to RECOGNISE this class of mistake next time — what does it look
   like before it goes wrong?
5. Tell me one habit that would have prevented it.

If my query runs without error but gives a wrong answer, say so explicitly. I
would rather hear "this runs and is wrong" than have you fix the syntax and stop.
```

---

**Point 2 matters more than it sounds.** An AI handed a broken query will often return a
completely rewritten one that works and teaches you nothing, because you can't tell which part
was the bug. Asking for the smallest change keeps the lesson visible.
