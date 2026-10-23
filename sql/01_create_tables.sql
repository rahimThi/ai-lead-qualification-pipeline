/* =====================================================================
   AI-Assisted Lead Qualification Pipeline
   Step 1: Tables
   Prerequisite: data/companies.csv is imported as dbo.companies
   (SSMS -> Tasks -> Import Flat File). In "Modify Columns" set
   company_id to int and tick Primary Key, employees and founded to int,
   and description to nvarchar(1000).
   Run this whole script once in SSMS (F5).
   ===================================================================== */


-- Check the import: should return 50
SELECT COUNT(*) AS imported_companies
FROM dbo.companies;
GO


/* ---------------------------------------------------------------------
   lead_scores: one row per assessed company.
   - The n8n workflow writes the AI columns.
   - You fill in the review columns during the human review.
   --------------------------------------------------------------------- */
CREATE TABLE dbo.lead_scores (
    company_id        INT            NOT NULL PRIMARY KEY
                                     REFERENCES dbo.companies (company_id),

    -- written by the AI (n8n workflow)
    ai_fit_score      SMALLINT       NOT NULL CHECK (ai_fit_score BETWEEN 1 AND 5),
    digital_maturity  NVARCHAR(10)   NOT NULL CHECK (digital_maturity IN ('low', 'medium', 'high')),
    key_signal        NVARCHAR(300)  NULL,
    ai_reason         NVARCHAR(1000) NULL,
    outreach_draft    NVARCHAR(2000) NULL,
    scored_at         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),

    -- filled in by you (human-in-the-loop review)
    human_fit_score   SMALLINT       NULL CHECK (human_fit_score BETWEEN 1 AND 5),
    review_status     NVARCHAR(20)   NOT NULL DEFAULT 'pending'
                                     CHECK (review_status IN ('pending', 'approved', 'rejected')),
    reviewer_note     NVARCHAR(500)  NULL,
    reviewed_at       DATETIME2      NULL
);
GO


-- Check: the table exists and is empty
SELECT COUNT(*) AS scored_companies
FROM dbo.lead_scores;
