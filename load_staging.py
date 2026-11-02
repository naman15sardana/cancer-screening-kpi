from pathlib import Path
import pandas as pd
import pymssql

ROOT = Path(__file__).parent

conn = pymssql.connect(
    server="localhost",
    port=1433,
    user="sa",
    password="Screening#Dev2026",
    database="CancerScreening",
    autocommit=True
)

cursor = conn.cursor()

TABLES = ["health_authority", "program", "patient", "screening_exam", "followup"]

for table in TABLES:
    df = pd.read_csv(ROOT /"data"/ "raw" / f"{table}.csv")

    df = df.astype(object).where(df.notna(), None)  # Convert NaN to None for SQL insertion
    cols = ', '.join(df.columns)
    placeholders = ', '.join(['%s'] * len(df.columns))
    sql = f"INSERT INTO stg.{table} ({cols}) VALUES ({placeholders})"
    rows = [tuple(r) for r in df.itertuples(index=False)]
    cursor.execute(f"TRUNCATE TABLE stg.{table}")
    cursor.executemany(sql, rows)
    print(f"loaded stg.{table}: {len(rows):,} rows")

conn.close()
print("done")