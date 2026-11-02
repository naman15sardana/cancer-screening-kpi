USE CancerScreening;

SELECT 'health_authority' AS table_name, COUNT(*) AS row_count FROM stg.health_authority
UNION ALL SELECT 'program',        COUNT(*) FROM stg.program
UNION ALL SELECT 'patient',        COUNT(*) FROM stg.patient
UNION ALL SELECT 'screening_exam', COUNT(*) FROM stg.screening_exam
UNION ALL SELECT 'followup',       COUNT(*) FROM stg.followup;