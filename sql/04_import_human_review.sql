/* =====================================================================
   AI-Assisted Lead Qualification Pipeline
   Step 4: Load the blind human review into lead_scores
   Prerequisite: human_review.csv is imported as dbo.human_review
   (SSMS -> Tasks -> Import Flat File). In "Modify Columns" set
   human_fit_score to smallint and reviewer_note to nvarchar(500).
   The extra company columns in the file are fine; only three are used.
   ===================================================================== */


-- Check the import: should return 50 rows, 50 scores
SELECT COUNT(*)               AS rows_imported,
       COUNT(human_fit_score) AS rows_with_score
FROM dbo.human_review;
GO


-- Write the review into lead_scores in one statement.
-- Score 4 or 5 = approved as a lead, 1 to 3 = rejected.
UPDATE ls
SET    ls.human_fit_score = hr.human_fit_score,
       ls.reviewer_note   = hr.reviewer_note,
       ls.review_status   = CASE WHEN hr.human_fit_score >= 4
                                 THEN 'approved' ELSE 'rejected' END,
       ls.reviewed_at     = SYSUTCDATETIME()
FROM   dbo.lead_scores  AS ls
JOIN   dbo.human_review AS hr
       ON hr.company_id = ls.company_id
WHERE  hr.human_fit_score IS NOT NULL;
GO


-- Check: nothing should be left pending
SELECT review_status, COUNT(*) AS companies
FROM dbo.lead_scores
GROUP BY review_status;
