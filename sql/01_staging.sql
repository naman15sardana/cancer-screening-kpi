IF DB_ID('CancerScreening') IS NULL CREATE DATABASE CancerScreening;
GO
USE CancerScreening;
GO
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
GO
DROP TABLE IF EXISTS stg.health_authority, stg.program, stg.patient, stg.screening_exam, stg.followup;
GO

CREATE TABLE stg.health_authority (
    health_authority_id     INT,
    health_authority_name NVARCHAR(100)
);


CREATE TABLE stg.program (
    program_id INT,
    program_name NVARCHAR(50),
    min_age INT,
    max_age INT,
    sex_eligible CHAR(1),
    followup_target_days INT
);

CREATE TABLE stg.patient (
    patient_id INT,
    sex CHAR(1),
    birth_year INT,
    health_authority_id INT,
);

CREATE TABLE stg.screening_exam (
    exam_id INT,
    patient_id INT,
    program_id INT,
    exam_date DATE,
    result NVARCHAR(20)
);

CREATE TABLE stg.followup (
    followup_id INT,
    exam_id INT,
    followup_date DATE,
    outcome NVARCHAR(50)
);

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'stg'