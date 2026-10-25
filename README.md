# AI-Assisted Lead Qualification Pipeline (n8n, Azure OpenAI, Azure SQL)

## Business problem

A consulting firm that helps mid-sized German companies digitalise their operations wants to find the right prospects faster. Researching and judging each company by hand takes a business development team hours.

This project automates the first pass with AI, while a person keeps the final decision.

## What it does

```
Azure SQL: company list
   → n8n reads companies not yet scored
   → AI step 1 (Azure OpenAI): assess each company against the ideal customer profile
        → fit score 1–5, digital maturity, key signal, reasoning (fixed JSON structure)
   → results saved to Azure SQL
   → AI step 2, only for scores 4–5: draft a personalised first outreach email
   → independent review score for every company, loaded into SQL and compared with the AI
   → accuracy analysis in T-SQL
```

## Tools

n8n (workflow orchestration) · Azure OpenAI (language model) · Azure SQL Database · T-SQL · SSMS · Git

## Data

`data/companies.csv` contains 50 **fictional** German companies in logistics, manufacturing, food production, wholesale and automotive supply, each with size, industry and a short business description. Any resemblance to real companies is coincidental.

The list includes clear fits, clear non-fits, and deliberately tricky cases, such as companies whose marketing sounds more digital than their operations are, to test whether the AI judges substance over self-description.

## Ideal customer profile

| Criterion | Target |
|---|---|
| Size | 100–2,000 employees |
| Industry | Logistics, manufacturing, metal processing, food production, wholesale, automotive supply |
| Digital maturity | Low: paper or spreadsheet processes, outdated or disconnected systems |
| Trigger | Growth, new management, customer or regulatory pressure, cost pressure, acquisition |
| Disqualifiers | Already digitally mature, under 50 employees or a large group with its own transformation unit, insolvency or project freeze |

The full prompts and the output schema are in [`workflow/prompts.md`](workflow/prompts.md).

## Workflow design

| Node | Purpose |
|---|---|
| Get unscored companies | SQL query with `LEFT JOIN ... IS NULL`, so the workflow only processes companies without a score and can be rerun safely |
| Loop Over Items | One company at a time, to stay within API rate limits |
| Assess company | LLM step with a scoring rubric, low temperature (0.2) and a JSON schema for consistent, structured output |
| Save score | Parameterised insert into `lead_scores` |
| Hot lead? | Branches on fit score ≥ 4 |
| Draft outreach | Second LLM step (temperature 0.7), only for hot leads |
| Save draft | Update of the same row |
| Pause | 2-second wait between companies |

Reliability measures: a scoring rubric in the prompt, a JSON schema for the output, retry on failure, and check constraints in the database that reject invalid scores.

## Database

| Object | Type | Purpose |
|---|---|---|
| `companies` | table | Imported company list |
| `lead_scores` | table | AI assessment, outreach draft and human review per company |
| `v_lead_pipeline` | view | Companies joined with scores, size bands, lead temperature and AI-vs-human comparison |
| `v_ai_accuracy` | view | Agreement rate, false positives and false negatives |

## Review and accuracy check

All 50 companies were scored a second time, independently of the AI and against the same rubric, with a note for each decision ([`data/human_review.csv`](data/human_review.csv)). I checked these reference scores and loaded them into `lead_scores` with one `UPDATE ... JOIN` ([`sql/04_import_human_review.sql`](sql/04_import_human_review.sql)). Scores of 4–5 count as approved, 1–3 as rejected.

Comparing the two scores shows how far the AI can be trusted, and which leads would have been contacted by mistake.

## Results

| Metric | Value |
|---|---|
| Companies assessed | 50 |
| Hot leads (AI score 4–5) | 34 (68%) |
| Approved after review | 23 (68% of hot leads) |
| Exact score match | 48% |
| Within 1 point | 84% |
| Average score difference | 0.68 points |
| Clear false positives (AI hot, review 1–2) | 5 |
| False negatives (AI cold, review 4–5) | 0 |
| AI cost for the full run | [€x.xx] |

**Main finding:** the AI is a reliable first filter but too optimistic. It did not miss a single good lead, but 11 of its 34 hot leads did not hold up (5 clear misses, 6 borderline). In 25 of 26 disagreements the AI scored higher than the review. It also almost never used the middle score: only 3 companies got a 3.

### Where the AI was wrong

- **It treats past events as triggers.** Steinmann Getränke (AI 5, review 3) got a "clear trigger" for a filling line installed in 2024, and Bartels Großhandel (5 vs. 3) for an online shop launched in 2023. Neither is a reason to act now.
- **It gives a 4 even when it says the trigger is missing.** For Kowalski Feinmechanik and Lorenz Schrauben (both 4 vs. 2), its own reasoning says "lacks a clear urgency trigger", yet the rubric reserves 4 for companies where only one signal is weaker.
- **It reads cost cutting as urgency.** Neuhaus Druckguss (4 vs. 2) is cutting costs instead of starting projects, which means no budget for consultants; the AI saw "cost pressure" and rated it a good fit.
- **It overlooked a size limit.** Albrecht Transport (4 vs. 2) has 85 employees, below the 100 minimum, but the AI wrote "fits the size well".
- **The outreach drafts need checking too.** The email to Fischer Transporte praises its "AI route optimisation pilot", although the scoring step had correctly judged this as marketing. Several drafts still contain placeholders such as "[Last Name]".

What worked: the deliberately misleading cases were handled correctly. Companies calling themselves a "digital pioneer" or advertising "AI-based" features while planning on paper (Quast Logistik, Fischer Transporte) and the medical manufacturer with regulatory documentation gaps (Wilke Medizintechnik) received the same scores as in the review. Every disqualifier (insolvency, project freeze, sale in progress, too small) was recognised.

### Improvements for the next prompt version

- A trigger must be current or upcoming; completed projects do not count.
- Without a trigger the score is at most 3.
- A disqualifier always means score 1 (the current rubric allows 1 or 2, which explains most one-point differences at the bottom).
- Check the employee count against the 100–2,000 range before scoring.
- Cost cutting or a spending freeze counts against the ability to buy, not as urgency.

## Data protection

The companies are fictional and only business information is used, no personal data. The drafts are for demonstration and were never sent; unsolicited marketing emails are restricted in Germany. Azure OpenAI runs within the project's own Azure subscription.

## Repository structure

```
├── README.md
├── data/
│   ├── companies.csv
│   └── human_review.csv
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_create_views.sql
│   ├── 03_review_and_analysis.sql
│   └── 04_import_human_review.sql
└── workflow/
    ├── prompts.md
    └── lead_qualification_workflow.json
```

## How to run

1. Import `data/companies.csv` into Azure SQL as `dbo.companies` (`company_id` as int primary key).
2. Run `sql/01_create_tables.sql` and `sql/02_create_views.sql`.
3. Deploy a chat model in Azure OpenAI.
4. Import `workflow/lead_qualification_workflow.json` into n8n, add your own Microsoft SQL and Azure OpenAI credentials, and execute.
5. Import `data/human_review.csv` as `dbo.human_review` and run `sql/04_import_human_review.sql`.
6. Run `sql/03_review_and_analysis.sql` for the accuracy analysis.

## Author

Md Abdur Rahim · [LinkedIn](https://linkedin.com/in/rahimthi)
