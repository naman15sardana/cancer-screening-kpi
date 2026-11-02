USE CancerScreening;
GO

-- Drop in reverse order: children before parents (foreign keys block otherwise)
DROP TABLE IF EXISTS dbo.followup, dbo.screening_exam, dbo.patient,
                     dbo.program, dbo.health_authority;
GO

CREATE TABLE dbo.health_authority (
    health_authority_id   INT PRIMARY KEY,
    health_authority_name NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.program (
    program_id           INT PRIMARY KEY,
    program_name         NVARCHAR(50) NOT NULL,
    min_age              INT NOT NULL,
    max_age              INT NOT NULL,
    sex_eligible         CHAR(1) NOT NULL CHECK (sex_eligible IN ('F', 'M', 'A')),
    followup_target_days INT NOT NULL
);

CREATE TABLE dbo.patient (
    patient_id          INT PRIMARY KEY,
    sex                 CHAR(1) NOT NULL CHECK (sex IN ('F', 'M')),
    birth_year          INT NOT NULL,
    health_authority_id INT NULL REFERENCES dbo.health_authority(health_authority_id)
);

CREATE TABLE dbo.screening_exam (
    exam_id    INT PRIMARY KEY,
    patient_id INT  NOT NULL REFERENCES dbo.patient(patient_id),
    program_id INT  NOT NULL REFERENCES dbo.program(program_id),
    exam_date  DATE NOT NULL,
    result     NVARCHAR(20) NOT NULL CHECK (result IN ('Normal', 'Abnormal'))
);

CREATE TABLE dbo.followup (
    followup_id   INT PRIMARY KEY,
    exam_id       INT NOT NULL REFERENCES dbo.screening_exam(exam_id),
    followup_date DATE NULL,
    outcome       NVARCHAR(50) NULL,
    needs_review  BIT NOT NULL DEFAULT 0
);
GO

-- Regions, programs, patients: no rows to remove
INSERT INTO dbo.health_authority SELECT * FROM stg.health_authority;
INSERT INTO dbo.program          SELECT * FROM stg.program;
INSERT INTO dbo.patient          SELECT * FROM stg.patient;

WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY patient_id, program_id, exam_date
               ORDER BY exam_id
           ) AS copy_number
    FROM stg.screening_exam
    WHERE exam_date <= GETDATE()          -- drop future dates
      AND result IS NOT NULL
)
INSERT INTO dbo.screening_exam (exam_id, patient_id, program_id, exam_date, result)
SELECT exam_id, patient_id, program_id, exam_date, result
FROM ranked
WHERE copy_number = 1;                    -- keep only the first copy

INSERT INTO dbo.followup (followup_id, exam_id, followup_date, outcome, needs_review)
SELECT f.followup_id,
       f.exam_id,
       CASE WHEN f.followup_date < e.exam_date THEN NULL ELSE f.followup_date END,
       f.outcome,
       CASE WHEN f.followup_date < e.exam_date THEN 1 ELSE 0 END
FROM stg.followup f
JOIN dbo.screening_exam e ON e.exam_id = f.exam_id;
GO

SELECT 'staging' AS layer, COUNT(*) AS exams FROM stg.screening_exam
UNION ALL
SELECT 'clean', COUNT(*) FROM dbo.screening_exam;

SELECT SUM(CAST(needs_review AS INT)) AS flagged_followups FROM dbo.followup;