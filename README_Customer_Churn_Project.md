# Customer Churn Analysis & Retention Insights
**Python | SQL | Power BI** - why telecom customers leave and where to focus retention effort

> **Summary:** About **24% of customers churned**, taking **27% of monthly revenue** with them. Contract type is the strongest driver: month-to-month customers churn at **41%** versus **8%** on two-year contracts. Month-to-month Fiber optic customers are only 18% of the base but make up 43% of all churners. This project cleans the data with Python, analyses it with SQL and presents it in Power BI.

![Power BI dashboard](images/powerbi_dashboard.png)
*(add your own Power BI screenshot here after building the dashboard)*

---

## 1. Business problem
A telecom operator selling broadband and mobile plans across four regions of India loses roughly one customer in four. Retention effort is untargeted. The business needs to know **why customers leave, which segments are most at risk, and where to act first**. Full brief: `02_Business_Problem_Statement.pdf`.

## 2. Dataset
- **Synthetic** customer data (not from a real company), currency INR.
- Raw file: **7,260 rows, 26 columns**. Cleaned file: **7,200 customers** (one row per customer).

| Group | Columns |
|---|---|
| Profile | customer_id, signup_date, gender, senior_citizen, partner, dependents, region, city |
| Account | tenure_months, contract, payment_method, paperless_billing |
| Services | phone_service, internet_service, online_security, online_backup, device_protection, tech_support, streaming_tv, streaming_movies |
| Billing and behaviour | monthly_charges, total_charges, avg_monthly_data_gb, support_tickets_6m, late_payments_12m |
| Target | churn (Yes / No) |

## 3. Files in this repository
| # | File | Purpose |
|---|---|---|
| 1 | `01_telecom_churn_raw_data.csv` | Raw data as received |
| 2 | `02_Business_Problem_Statement.pdf` | Business problem, objectives, questions, approach |
| 3 | `03_data_cleaning.py` | Python script that cleans the raw file |
| 4 | `04_telecom_churn_cleaned_data.csv` | Cleaned data produced by the script |
| 5 | `05_churn_analysis_queries.sql` | Schema, data-quality check and 12 analysis queries |
| 6 | `06_SQL_Queries_with_Output_Screenshots.pdf` | Every query with its output screenshot and insight |
| 7 | `07_PowerBI_Dashboard_Kit.zip` | Dashboard data CSVs, Power BI build guide with DAX, layout reference |
| - | `churn_dashboard.pbix` | **Your Power BI file** (build it with the guide and add it here) |

## 4. Tools & skills
| Tool | What I did |
|---|---|
| **Python (pandas)** | Profiled the raw data, cleaned it with a logged, validated script (assertions stop the script if a rule fails) |
| **SQL** | Data-quality checks, a helper view, 12 queries using `CASE` pivots, `GROUP BY`/`HAVING`, CTEs and window functions (`SUM OVER`, `RANK`, `ROW_NUMBER`) |
| **Power BI** | Data model, DAX measures (churn rate, revenue churned, ARPU), multi-page dashboard with slicers and drill-through |

## 5. Data cleaning (Python)
| Problem found | Rows | Fix |
|---|---|---|
| Duplicate customer_id | 60 | keep first occurrence |
| Contract / payment text in mixed case or with spaces | ~360 | `str.strip()` and `str.capitalize()` |
| Negative monthly_charges | 40 | absolute value (sign-entry error) |
| Missing total_charges | 144 | monthly_charges x tenure_months |
| Missing gender | 108 | labelled "Unknown" |

**Result:** 7,260 raw rows -> 7,200 clean customers. The script ends with checks (unique customers, no missing values, valid categories) and writes a cleaning log.

## 6. SQL analysis
Questions answered: overall churn and revenue impact, churn by contract, tenure, internet service, add-on count, payment method, support tickets, signup year and city; lifetime revenue of churned vs retained customers; the small segments that produce most churners; and a retention call list. Outputs and insights: `06_SQL_Queries_with_Output_Screenshots.pdf`.

## 7. Key findings
| # | Finding |
|---|---|
| 1 | Churn rate **24.2%** (1,741 of 7,200); churned customers carried **27.3% of monthly revenue** (about INR 16.3 M a year) |
| 2 | **Contract:** month-to-month 40.9%, one-year 15.9%, two-year 7.6%; month-to-month customers are 73% of all churners |
| 3 | **Month-to-month + Fiber optic:** 56% churn; 18% of customers but 43% of all churners (72% churn in their first year) |
| 4 | **Tenure:** 43.9% churn in the first 6 months vs 11.7% after 4+ years |
| 5 | **Service quality:** 15.2% churn with no support tickets vs 41.3% with 3 or more in six months |
| 6 | **Payment:** electronic-check customers on paperless billing churn the most (30.1%) |
| 7 | Add-on services alone make little difference (about 30% to 26%), so contract and service quality matter more |

## 8. Recommendations
1. **Move month-to-month customers onto 12-month contracts** with a price lock - the largest and most winnable group.
2. **Protect the first year:** onboarding call in months 1-2 and a first-year contract offer for new Fiber customers.
3. **Act on service pain:** trigger a technical visit when a customer reaches 3 tickets in six months.
4. **Reduce payment friction:** move electronic-check payers to auto-pay with a small bill credit.
5. **Measure before scaling:** pilot offers with a control group to learn the real success rate.

## 9. How to reproduce
```bash
pip install pandas
python 03_data_cleaning.py      # reads 01_..., writes 04_... and cleaning_log.csv
```
Then create a table in SQLite/MySQL/PostgreSQL using the `CREATE TABLE` in `05_churn_analysis_queries.sql`, import `04_telecom_churn_cleaned_data.csv`, and run the queries. For the dashboard, follow `PowerBI_Build_Guide.md` inside `07_PowerBI_Dashboard_Kit.zip`.

## 10. Limitations
- Synthetic data: findings demonstrate the method, not a real company.
- The churn label is a snapshot (left / stayed), so segment differences show association, not proof that changing a feature keeps customers.
- Signup-year cohorts are not directly comparable because newer customers have had less time.

## 11. Possible extension
Add a predictive model (logistic regression / gradient boosting) to score active customers by churn risk and choose whom to contact based on expected campaign profit.

## 12. Author
*Your name* | [LinkedIn] | [Email]
