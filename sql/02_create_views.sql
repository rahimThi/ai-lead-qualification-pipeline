/* =====================================================================
   AI-Assisted Lead Qualification Pipeline
   Step 2: Views for review and for Power BI
   Run the whole script once in SSMS (F5).
   ===================================================================== */


/* ---------------------------------------------------------------------
   v_lead_pipeline: every company with its AI assessment and review.
   LEFT JOIN keeps companies the workflow has not scored yet.
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.v_lead_pipeline AS
SELECT c.company_id,
       c.company_name,
       c.city,
       c.industry,
       c.employees,
       CASE
            WHEN c.employees < 50    THEN '1: under 50'
            WHEN c.employees < 250   THEN '2: 50-249'
            WHEN c.employees < 1000  THEN '3: 250-999'
            WHEN c.employees <= 2000 THEN '4: 1,000-2,000'
            ELSE '5: over 2,000'
       END                                        AS size_band,
       s.ai_fit_score,
       CASE
            WHEN s.ai_fit_score IS NULL THEN 'Not scored'
            WHEN s.ai_fit_score >= 4    THEN 'Hot'
            WHEN s.ai_fit_score = 3     THEN 'Warm'
            ELSE 'Cold'
       END                                        AS lead_temperature,
       s.digital_maturity,
       s.key_signal,
       s.ai_reason,
       s.outreach_draft,
       s.human_fit_score,
       COALESCE(s.review_status, 'not scored')    AS review_status,
       s.reviewer_note,
       CASE
            WHEN s.human_fit_score IS NULL                          THEN NULL
            WHEN s.human_fit_score = s.ai_fit_score                 THEN 'exact match'
            WHEN ABS(s.human_fit_score - s.ai_fit_score) = 1        THEN 'off by 1'
            ELSE 'off by 2+'
       END                                        AS ai_vs_human,
       s.scored_at,
       s.reviewed_at
FROM dbo.companies AS c
LEFT JOIN dbo.lead_scores AS s
       ON s.company_id = c.company_id;
GO


/* ---------------------------------------------------------------------
   v_ai_accuracy: how well the AI matched your judgement.
   Only reviewed companies count.
   - false positive: AI said hot (4-5), you said cold (1-2)
   - false negative: AI said cold (1-2), you said hot (4-5)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.v_ai_accuracy AS
SELECT COUNT(*)                                                             AS reviewed_companies,
       CAST(AVG(CASE WHEN human_fit_score = ai_fit_score THEN 100.0 ELSE 0 END) AS DECIMAL(5,1))
                                                                            AS exact_match_pct,
       CAST(AVG(CASE WHEN ABS(human_fit_score - ai_fit_score) <= 1 THEN 100.0 ELSE 0 END) AS DECIMAL(5,1))
                                                                            AS within_one_point_pct,
       SUM(CASE WHEN ai_fit_score >= 4 AND human_fit_score <= 2 THEN 1 ELSE 0 END) AS false_positives,
       SUM(CASE WHEN ai_fit_score <= 2 AND human_fit_score >= 4 THEN 1 ELSE 0 END) AS false_negatives,
       CAST(AVG(ABS(human_fit_score - ai_fit_score) * 1.0) AS DECIMAL(4,2)) AS avg_score_difference
FROM dbo.lead_scores
WHERE human_fit_score IS NOT NULL;
GO
