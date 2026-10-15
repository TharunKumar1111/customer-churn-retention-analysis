"""
Customer Churn Analysis - Step 1: DATA CLEANING
------------------------------------------------
Input : 01_telecom_churn_raw_data.csv      (7,260 rows, with data-quality problems)
Output: 04_telecom_churn_cleaned_data.csv  (7,200 rows, one row per customer)
        cleaning_log.csv                   (what was fixed and how many rows)
Run   : python 03_data_cleaning.py         (needs: pip install pandas)
"""
import pandas as pd

RAW, CLEAN, LOG = "01_telecom_churn_raw_data.csv", "04_telecom_churn_cleaned_data.csv", "cleaning_log.csv"

# ---------------------------------------------------------------- 1. LOAD & PROFILE
df = pd.read_csv(RAW)
log = [("Rows in raw file", len(df))]
print("Shape:", df.shape)
print("\nMissing values per column:\n", df.isna().sum()[df.isna().sum() > 0])
print("Duplicate customer_id rows:", df.duplicated("customer_id").sum())
print("Negative monthly_charges  :", (df.monthly_charges < 0).sum())
print("Contract spellings        :", df.contract.unique().tolist())

# ---------------------------------------------------------------- 2. CLEAN
# 2.1 Duplicate customers: the analysis grain is ONE ROW PER CUSTOMER -> keep the first occurrence
n = len(df)
df = df.drop_duplicates("customer_id", keep="first")
log.append(("Duplicate customers removed", n - len(df)))

# 2.2 Standardise text: 'month-to-month' / 'Month-to-month' must be one category; remove stray spaces
df["contract"] = df["contract"].str.strip().str.capitalize()           # -> Month-to-month, One year, Two year
df["payment_method"] = df["payment_method"].str.strip()
log.append(("Text columns standardised (contract, payment_method)", 2))

# 2.3 Negative monthly charges are sign-entry errors (a bill cannot be negative) -> absolute value
neg = df["monthly_charges"] < 0
df.loc[neg, "monthly_charges"] = df.loc[neg, "monthly_charges"].abs()
log.append(("Negative monthly_charges corrected", int(neg.sum())))

# 2.4 Missing total_charges: total = monthly charge x months of tenure (how the column is built)
miss = df["total_charges"].isna()
df.loc[miss, "total_charges"] = (df["monthly_charges"] * df["tenure_months"]).round(2)[miss]
log.append(("Missing total_charges imputed (monthly x tenure)", int(miss.sum())))

# 2.5 Missing gender: keep the customer, label as Unknown (gender is not a churn driver; deleting loses data)
g = df["gender"].isna()
df["gender"] = df["gender"].fillna("Unknown")
log.append(("Missing gender labelled 'Unknown'", int(g.sum())))

# 2.6 Correct data types
df["signup_date"] = pd.to_datetime(df["signup_date"]).dt.strftime("%Y-%m-%d")

# ---------------------------------------------------------------- 3. VALIDATE (script stops if any rule fails)
assert df["customer_id"].is_unique,            "duplicate customers remain"
assert df.isna().sum().sum() == 0,             "missing values remain"
assert (df["monthly_charges"] > 0).all(),      "non-positive monthly charges remain"
assert set(df["contract"]) == {"Month-to-month", "One year", "Two year"}, "contract categories wrong"
assert set(df["churn"]) == {"Yes", "No"},      "churn values wrong"
log.append(("Rows in cleaned file", len(df)))

# ---------------------------------------------------------------- 4. SAVE
df = df.sort_values("customer_id").reset_index(drop=True)
df.to_csv(CLEAN, index=False)
pd.DataFrame(log, columns=["step", "rows"]).to_csv(LOG, index=False)
print("\nCLEANING LOG"); [print(f"  {s:55s}{r:>7,}") for s, r in log]
print(f"\nChurn rate after cleaning: {(df.churn == 'Yes').mean():.1%}  ->  saved {CLEAN}")
