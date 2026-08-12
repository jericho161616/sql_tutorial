# 4. Turn plain English into SQL

**Use when:** you know what you want but not how to express it.

---

```
Convert this business question into SQL: «your question».

Schema:
«schema»

Dialect: PostgreSQL 17.

Before writing any SQL, tell me:
- which tables are required and why
- which filters apply, and whether each belongs in WHERE, HAVING, or a join's
  ON clause
- what one row of the result will represent
- what the row count should be, roughly, and how I can check it

Then write the query with a comment on each clause explaining why it is there.

Finally:
- list every assumption you made, especially about anything ambiguous in my
  question
- give me one validation query I can run to check the result is right —
  ideally one that computes the same number a different way
- tell me the most likely way this query could return a plausible but wrong
  answer

If my question is ambiguous, ask me rather than picking an interpretation.
```

---

**The "plausible but wrong" request is the valuable one.** After week 5 you know the answer is
usually fan-out, and asking for it explicitly makes it visible before you trust the number.
