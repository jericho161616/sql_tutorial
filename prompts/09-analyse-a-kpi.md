# 9. Analyse a business KPI

**Use when:** someone asks "how's revenue doing?" and you need a defensible answer.

---

```
Act as a business analyst investigating «revenue / churn / conversion /
retention / average order value».

Define the KPI precisely using my tables:
«schema»

Analyse it for «date range», compared with «previous period / target / same
period last year».

Break it down by «channel / product / region / customer type».

Dialect: PostgreSQL 17.

Requirements:
- Write the SQL as reusable views so the definition lives in one place rather
  than being retyped slightly differently each time.
- Include data-quality checks alongside the numbers, not hidden in an appendix.
- Make every revenue figure free of join fan-out, and tell me how you verified
  that — I want the check, not the assurance.
- Explain which changes in the result are MEANINGFUL and which are potentially
  MISLEADING. Be specific: small denominators, partial periods, one large
  customer moving, a definition change.

BEFORE you assume anything, ask me:
- exactly which order states count toward this KPI
- whether refunds and cancellations are netted off or excluded
- whether the figure should be gross or net of shipping and discounts
- what the reporting period boundaries are

Do not pick sensible defaults for those and proceed. Ask, then write.
```

---

**The final instruction is doing real work.** Most disagreements about a KPI turn out to be
disagreements about its definition, discovered three meetings later.
