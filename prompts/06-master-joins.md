# 6. Help me master joins

**Use when:** week 4–5, or any time a row count looks wrong.

---

```
Teach me how to join these tables: «table names, their columns, and how they
relate».

My goal is to calculate: «desired result».

Dialect: PostgreSQL 17.

Please:
1. Show me the correct join, with each ON clause explained.
2. Illustrate WHICH ROWS MATCH using a tiny worked example — four or five rows
   per table, drawn out, so I can see the output row by row.
3. Explain INNER JOIN versus LEFT JOIN for this specific case, and tell me which
   one is correct here and why.
4. Tell me what the row count should be before and after each join, so I can
   check as I build it up.

Then check for these three risks specifically, and give me a diagnostic query
for each:
- FAN-OUT: will joining a one-to-many relationship duplicate rows and inflate
  any SUM or COUNT? Show me the inflated number and the correct one side by side.
- MISSING ROWS: will an INNER JOIN silently drop rows that should be in the
  result?
- DUPLICATES: could either table contain unexpected duplicate keys?

For fan-out in particular, do not just warn me about it — show me the actual
wrong number my query would produce.
```

---

**Asking for the wrong number as well as the right one is the trick.** Being told "watch out
for fan-out" teaches nothing; seeing $2,938.50 where the answer is $976.50 teaches it
permanently.
