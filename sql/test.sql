USE CancerScreening;

-- Chart 2: median days from abnormal result to follow-up
SELECT region,
       MAX(CASE WHEN program_name = 'Breast Screening' THEN median_wait_days END) AS Breast,
       MAX(CASE WHEN program_name = 'Cervix Screening' THEN median_wait_days END) AS Cervix,
       MAX(CASE WHEN program_name = 'Colon Screening'  THEN median_wait_days END) AS Colon
FROM rpt.v_followup_wait
WHERE region <> 'Unknown'
GROUP BY region
ORDER BY region;