USE CancerScreening;
GO

-- Check 1: patients with no health authority
SELECT COUNT(*) AS missing_region
FROM stg.patient
WHERE health_authority_id IS NULL;

SELECT COUNT(*) AS future_dates
FROM stg.screening_exam
WHERE exam_date > GETDATE();

-- Check 3: same patient + program + date = duplicate
SELECT patient_id, program_id, exam_date, COUNT(*) AS copies
FROM stg.screening_exam
GROUP BY patient_id, program_id, exam_date
HAVING COUNT(*) > 1;

-- Check 4: follow-up dated before the exam that triggered it
SELECT COUNT(*) AS followup_before_exam
FROM stg.followup f
JOIN stg.screening_exam e ON e.exam_id = f.exam_id
WHERE f.followup_date < e.exam_date;

-- Check 5: abnormal results where the patient never got a follow-up
SELECT COUNT(*) AS lost_to_followup
FROM stg.screening_exam e
LEFT JOIN stg.followup f ON f.exam_id = e.exam_id
WHERE e.result = 'Abnormal'
AND f.followup_date IS NULL;