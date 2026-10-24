/* =====================================================================
   AI-Assisted Lead Qualification Pipeline
   Step 3: Human review and analysis
   Run AFTER the n8n workflow has scored the companies.
   Highlight one block and press F5 to run only that block.
   ===================================================================== */


-- 1. Did the workflow score every company? Should return 50 and 0.
SELECT COUNT(*)                                              AS total_companies,
       SUM(CASE WHEN ai_fit_score IS NULL THEN 1 ELSE 0 END) AS not_scored
FROM dbo.v_lead_pipeline;


-- 2. Review list: read each company and the AI's reasoning
SELECT company_id,
       company_name,
       industry,
       employees,
       ai_fit_score,
       digital_maturity,
       key_signal,
       ai_reason
FROM dbo.v_lead_pipeline
WHERE review_status = 'pending'
ORDER BY ai_fit_score DESC, company_id;


-- 3. The review scores are loaded in one step with
--    04_import_human_review.sql (import of data/human_review.csv).


-- 4. Read the outreach drafts of the hot leads
SELECT company_id,
       company_name,
       ai_fit_score,
       human_fit_score,
       outreach_draft
FROM dbo.v_lead_pipeline
WHERE ai_fit_score >= 4
ORDER BY ai_fit_score DESC, company_id;


-- 5. AI accuracy compared with your review
SELECT *
FROM dbo.v_ai_accuracy;


-- 6. Where the AI was wrong: largest disagreements first
SELECT company_id,
       company_name,
       ai_fit_score,
       human_fit_score,
       human_fit_score - ai_fit_score AS difference,
       ai_reason,
       reviewer_note
FROM dbo.v_lead_pipeline
WHERE human_fit_score IS NOT NULL
  AND human_fit_score <> ai_fit_score
ORDER BY ABS(human_fit_score - ai_fit_score) DESC, company_id;


-- 7. Pipeline by lead temperature
SELECT lead_temperature,
       COUNT(*) AS companies,
       CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS share_pct
FROM dbo.v_lead_pipeline
GROUP BY lead_temperature
ORDER BY companies DESC;


-- 8. Average fit score and hot leads per industry
SELECT industry,
       COUNT(*)                                             AS companies,
       CAST(AVG(ai_fit_score * 1.0) AS DECIMAL(3,1))        AS avg_ai_score,
       SUM(CASE WHEN ai_fit_score >= 4 THEN 1 ELSE 0 END)   AS hot_leads,
       SUM(CASE WHEN review_status = 'approved' THEN 1 ELSE 0 END) AS approved_leads
FROM dbo.v_lead_pipeline
GROUP BY industry
ORDER BY hot_leads DESC;


-- 9. Final prospect list: approved leads, ranked by your score, then the AI's
SELECT RANK() OVER (ORDER BY human_fit_score DESC, ai_fit_score DESC) AS priority,
       company_name,
       city,
       industry,
       employees,
       human_fit_score,
       ai_fit_score,
       key_signal
FROM dbo.v_lead_pipeline
WHERE review_status = 'approved'
ORDER BY priority, company_name;
