USE CancerScreening;
GO
IF SCHEMA_ID('rpt') IS NULL EXEC('CREATE SCHEMA rpt');
GO

CREATE OR ALTER VIEW rpt.v_participation AS
WITH eligible AS (
    SELECT p.patient_id,
           pr.program_id,
           pr.program_name,
           ISNULL(ha.health_authority_name, 'Unknown') AS region
    FROM dbo.patient p
    JOIN dbo.program pr
      ON (2025 - p.birth_year) BETWEEN pr.min_age AND pr.max_age
     AND (pr.sex_eligible = 'A' OR pr.sex_eligible = p.sex)
    LEFT JOIN dbo.health_authority ha
      ON ha.health_authority_id = p.health_authority_id
),
screened AS (
    SELECT DISTINCT patient_id, program_id
    FROM dbo.screening_exam
)
SELECT el.program_name,
       el.region,
       COUNT(*)             AS eligible_people,
       COUNT(s.patient_id)  AS screened_people,
       CAST(100.0 * COUNT(s.patient_id) / COUNT(*) AS DECIMAL(5,1)) AS participation_pct
FROM eligible el
LEFT JOIN screened s
  ON s.patient_id = el.patient_id AND s.program_id = el.program_id
GROUP BY el.program_name, el.region;
GO

CREATE OR ALTER VIEW rpt.v_followup_wait AS
WITH waits AS (
    SELECT pr.program_name,
           pr.followup_target_days,
           ISNULL(ha.health_authority_name, 'Unknown') AS region,
           DATEDIFF(DAY, e.exam_date, f.followup_date) AS wait_days
    FROM dbo.screening_exam e
    JOIN dbo.program pr ON pr.program_id = e.program_id
    JOIN dbo.patient p  ON p.patient_id  = e.patient_id
    LEFT JOIN dbo.health_authority ha ON ha.health_authority_id = p.health_authority_id
    LEFT JOIN dbo.followup f ON f.exam_id = e.exam_id
    WHERE e.result = 'Abnormal'
),
medians AS (
    SELECT DISTINCT program_name, region,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY wait_days)
               OVER (PARTITION BY program_name, region) AS median_wait_days
    FROM waits
    WHERE wait_days IS NOT NULL
)
SELECT w.program_name,
       w.region,
       COUNT(*) AS abnormal_results,
       MAX(m.median_wait_days) AS median_wait_days,
       CAST(100.0 * SUM(CASE WHEN w.wait_days <= w.followup_target_days THEN 1 ELSE 0 END)
            / COUNT(*) AS DECIMAL(5,1)) AS pct_within_target,
       CAST(100.0 * SUM(CASE WHEN w.wait_days IS NULL THEN 1 ELSE 0 END)
            / COUNT(*) AS DECIMAL(5,1)) AS pct_no_followup
FROM waits w
LEFT JOIN medians m ON m.program_name = w.program_name AND m.region = w.region
GROUP BY w.program_name, w.region;
GO