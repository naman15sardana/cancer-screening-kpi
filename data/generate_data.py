from pathlib import Path
import pandas as pd
import numpy as np


rng = np.random.default_rng(42) #fixed random data
N_PATIENTS = 20_000
START_DATE = pd.Timestamp("2024-01-01")
DAYS_IN_WINDOW = 730

OUT = Path(__file__).parent / "raw"

health_authority = pd.DataFrame({
    "health_authority_id": [1, 2, 3, 4, 5],
    "health_authority_name": ["Fraser Health", "Vancouver Coastal Health", "Interior Health", "Island Health", "Northern Health"]
})

health_authority.to_csv(OUT / "health_authority.csv", index=False)
print("health_authority:", len(health_authority))

program = pd.DataFrame({
    "program_id": [1, 2, 3],
    "program_name": ["Breast Screening", "Cervix Screening", "Colon Screening"],
    "min_age": [40, 25, 50],
    "max_age": [74, 69, 74],
    "sex_eligible": ["F", "F", "A"],
    "followup_target_days": [30, 60, 60],
})
program.to_csv(OUT / "program.csv", index=False)
print("program:", len(program))

# ---- PATIENTS ----
patient = pd.DataFrame({
    "patient_id": np.arange(100_001, 100_001 + N_PATIENTS),
    "sex": rng.choice(["F", "M"],
N_PATIENTS, p=[0.52, 0.48]),
    "birth_year": rng.integers(1950,2000,N_PATIENTS),
    "health_authority_id": rng.choice(health_authority["health_authority_id"],
N_PATIENTS,
p=[0.38, 0.24, 0.16, 0.16, 0.06])
})


print("patient:", len(patient))
print(patient.head())

# ---- PROGRAM ELIGIBILITY ----
#chance a person gets screened by region ( rural=lower)
screen_rate = {1: 0.58, 2: 0.61, 3: 0.52, 4: 0.55, 5: 0.43}

exam_rows = []
exam_id = 1

for p in patient.itertuples():
    age = 2025 - p.birth_year
    for prog in program.itertuples():
            #1 eligible?
        if (age < prog.min_age or age > prog.max_age) :
            continue
        if (prog.sex_eligible == "F" and p.sex != "F"):
            continue
                # got screened?
        if rng.random() > screen_rate[p.health_authority_id]:
            continue
    # when and what was the result
        exam_date = START_DATE + pd.Timedelta(days=int(rng.integers(0, DAYS_IN_WINDOW)))
        result = "Abnormal" if rng.random() < 0.07 else "Normal"

        exam_rows.append((exam_id,p.patient_id, prog.program_id, exam_date.date(), result))
        exam_id += 1

screening_exam = pd.DataFrame(exam_rows, columns=["exam_id", "patient_id", "program_id", "exam_date", "result"])

print("screening_exam:", len(screening_exam))
print(screening_exam["result"].value_counts(normalize=True))

abnormal = screening_exam[screening_exam["result"] == "Abnormal"]

abnormal = abnormal.merge(patient[["patient_id", "health_authority_id"]], on="patient_id")

# (shortest, longest) wait in days, by region
wait_range = {1: (7, 45), 2: (5, 35), 3: (10, 60), 4: (8, 50), 5: (15, 90)}

followup_rows = []
followup_id = 1
for e in abnormal.itertuples():
    if rng.random() < 0.06:
        followup_rows.append((followup_id, e.exam_id, None, None))
    else:
        low,high = wait_range[e.health_authority_id]
        wait_days = int(rng.integers(low, high))
        followup_date = pd.Timestamp(e.exam_date) + pd.Timedelta(days=wait_days) 
        outcome = rng.choice(["No Cancer", "Benign", "Cancer Detected"], p=[0.62, 0.30, 0.08])
        followup_rows.append((followup_id, e.exam_id, followup_date.date(), outcome))
    followup_id += 1
                                                             
                                                             
followup = pd.DataFrame(followup_rows, columns=["followup_id", "exam_id", "followup_date", "outcome"])

print("followup:", len(followup))
print(followup["outcome"].value_counts(dropna=False, normalize=True))

# ----BREAK THE DATA ON PURPOSE ----
#1.Missing Region(completeness)
missing = patient.sample(30, random_state=1).index
patient.loc[missing, "health_authority_id"] = None
#2. Duplicate Exams (uniqueness)
dupes = screening_exam.sample(20, random_state=2).copy()
dupes["exam_id"] = range(exam_id, exam_id + 20)
screening_exam = pd.concat([screening_exam, dupes], ignore_index=True)
#3. Future Dates (validity)
future = screening_exam.sample(8, random_state=3).index
screening_exam.loc[future, "exam_date"] = pd.Timestamp("2027-03-15").date()
#4. Followup before Exam (logical consistency)
has_date = followup.dropna(subset=["followup_date"]).sample(10, random_state=4)
for i, row in has_date.iterrows():
    exam_day = screening_exam.loc[screening_exam["exam_id"] == row["exam_id"], "exam_date"].iloc[0]
    followup.loc[i, "followup_date"] = (pd.Timestamp(exam_day) - pd.Timedelta(days=5)).date()


# ---- SAVE ----
patient["health_authority_id"] = patient["health_authority_id"].astype("Int64")
patient.to_csv(OUT / "patient.csv", index=False)
screening_exam.to_csv(OUT / "screening_exam.csv", index=False)
followup.to_csv(OUT / "followup.csv", index=False)
print("\nInjected problems: 30 missing regions, 20 duplicate exams, 8 future dates, 10 follow-ups before exam")