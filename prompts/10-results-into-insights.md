# 10. Turn results into insights

**Use when:** you have numbers and need to say something true about them.

---

```
Act as a senior analyst preparing findings for «my manager / a client / the
team».

Business goal: «what decision this informs».

My SQL query:
«paste query»

The results:
«paste output»

Please:
1. First, verify whether the query actually supports the conclusion I think it
   does. Check the logic before interpreting the numbers — if the query is
   wrong, the insights are worthless.
2. Flag any data or logic problems you can see: fan-out, missing NULL handling,
   partial periods, states that should have been excluded, percentages on tiny
   bases.
3. Identify the five most useful insights. For each give me: the supporting
   number, a possible cause, a recommended action, and one follow-up analysis.
4. Finish with a short executive summary.

Rules for the summary:
- Every claim must cite a number from the results.
- No exaggerated language. "Revenue rose 3%" not "revenue surged".
- Include at least one caveat — something in this data that could be misread,
  and how.
- If the data does not support a confident conclusion, say that instead of
  manufacturing one.

If any number looks implausible to you, say so before interpreting it. I would
rather be told my query is wrong than get a beautifully written summary of a
wrong number.
```

---

**Point 1 exists because the failure mode is so seductive.** An AI given a wrong query and its
output will write a confident, well-structured analysis of a number that means nothing, and it
will read extremely well.
