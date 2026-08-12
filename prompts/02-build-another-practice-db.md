# 2. Build another practice database

**Use when:** you want a second domain to practise on, or a schema closer to your actual job.

Your Nimbus database is an e-commerce schema. Practising on a second, differently-shaped one
is genuinely valuable — it stops you memorising *these* table names instead of learning the
skill.

---

```
Create a beginner-friendly SQL practice database for a fictional «healthcare
clinic / logistics company / school / SaaS product / bank».

Requirements:
- PostgreSQL 17. Put everything in its own schema so it cannot collide with my
  existing `shop` schema.
- 5 to 7 tables with realistic columns, proper primary and foreign keys, NOT NULL
  where appropriate, and CHECK constraints on any column with a fixed set of values.
- Include at least one one-to-many relationship and one many-to-many via a
  junction table.
- Include a self-referencing table if the domain has any natural hierarchy.
- 20 to 40 rows in each reference table, and enough transaction rows to make
  GROUP BY results interesting.
- Generate the transaction data deterministically with arithmetic on a row
  number rather than random(), so the same script always produces identical data.

Deliberately build in these teaching traps, and tell me at the end which rows
contain them:
- some parent rows with no children (so INNER JOIN silently drops them)
- some nullable columns with real NULLs (so `<>` comparisons lose rows)
- at least one one-to-many relationship that will inflate a SUM if joined naively
- some rows in a "cancelled" or "void" state that must be excluded from totals

Give me: the CREATE TABLE statements, the seed script, a plain-English
explanation of the schema, and five beginner questions I can answer with it.

Do not give me the answers to those five questions.
```

---

**The "deliberately build in traps" section is the important part.** A clean practice database
teaches you to write queries that work on clean data, which is not a skill anybody needs.
