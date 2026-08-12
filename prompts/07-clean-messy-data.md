# 7. Clean a messy dataset

**Use when:** week 8, and roughly forever afterwards in a real job.

---

```
Act as a data-cleaning analyst.

My table is «table name». Its columns are:
«paste schema — include the actual data types, especially if everything is text»

Problems I think exist:
«nulls / duplicates / inconsistent dates / spelling variants / outliers /
placeholder strings / numbers stored as text»

Dialect: PostgreSQL 17.

Work in this order and do not skip step 1:

1. PROFILE FIRST. Write queries that COUNT each problem before changing
   anything. Show me the actual distinct bad values, not just how many there are
   — I need to see what I am dealing with.
2. For each problem, propose a cleaning rule and explain the reasoning. Where a
   rule involves a judgement call, say so and give me the alternatives.
3. Write the cleaning SQL as a VIEW, not as UPDATE statements. The raw table
   must stay untouched.
4. Distinguish clearly between values you can FIX mechanically (whitespace,
   case), values that need a LOOKUP or mapping (synonyms), and values you should
   only FLAG rather than change (suspected test data, outliers).
5. Finish with validation queries comparing raw against cleaned — row counts,
   distinct value counts, and anything that should have stayed the same.

Two rules:
- Never delete rows during cleaning. Flag them.
- If a value is ambiguous — a date that could be DD/MM or MM/DD, an outlier that
  might be real — do not silently pick one. Tell me it is ambiguous and what you
  would need to know to resolve it.
```

---

**Step 1 is the one people skip.** Cleaning without profiling is how somebody normalises 40
rows and destroys 4 they didn't know were different.
