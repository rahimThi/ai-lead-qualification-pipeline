# Power BI Dashboard: Lead Pipeline and AI Accuracy

![Dashboard](dashboard.png)

A one-page dashboard showing the qualified lead pipeline and how well the AI's scores matched the human review.

## Data connection

| Setting | Value |
|---|---|
| Source | Azure SQL Database |
| Object | View `dbo.v_lead_pipeline` |
| Mode | Import |
| Authentication | SQL Server (database) login |
| Table name in Power BI | `Pipeline` |

Only the company-level view is loaded; all KPIs are DAX measures, so they react to the slicers. **Home → Refresh** pulls the latest scores and review decisions from the database.

## DAX measures

```dax
Companies Assessed = CALCULATE(COUNTROWS(Pipeline), NOT ISBLANK(Pipeline[ai_fit_score]))

Hot Leads = CALCULATE(COUNTROWS(Pipeline), Pipeline[ai_fit_score] >= 4)

Approved Leads = CALCULATE(COUNTROWS(Pipeline), Pipeline[review_status] = "approved")

Avg AI Score = AVERAGE(Pipeline[ai_fit_score])

AI Agreement =
DIVIDE(
    CALCULATE(COUNTROWS(Pipeline), Pipeline[ai_vs_human] IN {"exact match", "off by 1"}),
    CALCULATE(COUNTROWS(Pipeline), NOT ISBLANK(Pipeline[human_fit_score]))
)

Hot Lead Approval Rate =
DIVIDE(
    CALCULATE(COUNTROWS(Pipeline), Pipeline[ai_fit_score] >= 4, Pipeline[review_status] = "approved"),
    [Hot Leads]
)
```

| Measure | Purpose |
|---|---|
| Companies Assessed | Companies the workflow has scored |
| Hot Leads | AI score 4 or 5 |
| Approved Leads | Leads confirmed in the human review |
| Avg AI Score | Average fit of the current selection |
| AI Agreement | Share of reviewed companies where AI and human scores differ by at most 1 point |
| Hot Lead Approval Rate | Share of AI hot leads that the review confirmed |

## Visuals

| Visual | Fields | What it shows |
|---|---|---|
| 4 KPI cards | Companies Assessed, Hot Leads, Approved Leads, AI Agreement | Headline numbers |
| Column chart | ai_fit_score, Companies Assessed | Distribution of AI scores |
| Stacked bar chart | industry, count, Legend: lead_temperature | Hot, warm and cold leads per industry |
| Matrix (confusion matrix) | Rows: ai_fit_score, Columns: human_fit_score, Values: count | Agreement on the diagonal, disagreements off it |
| Table | Approved prospects with industry, size, score and key signal | The final prospect list |
| Slicers | industry, size_band | Interactive filtering |

## Files

| File | Description |
|---|---|
| `lead_pipeline.pbix` | Power BI Desktop file |
| `lead_pipeline.pdf` | PDF export, viewable without Power BI |
| `dashboard.png` | Screenshot used above |

To open the `.pbix` with your own database: **Transform data → Data source settings → Change source**, enter your server and database, then refresh.
