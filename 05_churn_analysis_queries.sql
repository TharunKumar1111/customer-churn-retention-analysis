-- =====================================================================
-- CUSTOMER CHURN ANALYSIS - SQL QUERIES   (SQLite syntax; MySQL/PostgreSQL differences noted)
-- Data: 04_telecom_churn_cleaned_data.csv  (7,200 customers)
-- Load in SQLite:   .mode csv   then   .import --skip 1 04_telecom_churn_cleaned_data.csv customers
-- (or use DB Browser for SQLite > File > Import > Table from CSV, or MySQL Workbench Table Data Import Wizard)
-- =====================================================================
CREATE TABLE customers (
  customer_id TEXT PRIMARY KEY, signup_date TEXT, gender TEXT, senior_citizen INTEGER, partner TEXT, dependents TEXT,
  region TEXT, city TEXT, tenure_months INTEGER, contract TEXT, payment_method TEXT, paperless_billing TEXT, phone_service TEXT,
  internet_service TEXT, online_security TEXT, online_backup TEXT, device_protection TEXT, tech_support TEXT, streaming_tv TEXT,
  streaming_movies TEXT, monthly_charges REAL, total_charges REAL, avg_monthly_data_gb REAL, support_tickets_6m INTEGER,
  late_payments_12m INTEGER, churn TEXT);

-- Helper view: churn flag, tenure bands and add-on count used by most queries
CREATE VIEW v_customers AS
SELECT c.*, CASE WHEN churn='Yes' THEN 1 ELSE 0 END AS churned,
  CASE WHEN tenure_months<=6 THEN '1. 0-6 m' WHEN tenure_months<=12 THEN '2. 7-12 m' WHEN tenure_months<=24 THEN '3. 13-24 m'
       WHEN tenure_months<=48 THEN '4. 25-48 m' ELSE '5. 49+ m' END AS tenure_band,
  (CASE WHEN online_security='Yes' THEN 1 ELSE 0 END + CASE WHEN online_backup='Yes' THEN 1 ELSE 0 END + CASE WHEN device_protection='Yes' THEN 1 ELSE 0 END
   + CASE WHEN tech_support='Yes' THEN 1 ELSE 0 END + CASE WHEN streaming_tv='Yes' THEN 1 ELSE 0 END + CASE WHEN streaming_movies='Yes' THEN 1 ELSE 0 END) AS n_addons
FROM customers c;

-- @DQ1 Data quality: row count, unique ids, invalid values (all problem counts must be 0)
SELECT COUNT(*) AS rows_, COUNT(DISTINCT customer_id) AS distinct_customers,
       SUM(CASE WHEN monthly_charges<=0 THEN 1 ELSE 0 END) AS bad_monthly_charges,
       SUM(CASE WHEN total_charges IS NULL OR total_charges=0 AND tenure_months>0 THEN 1 ELSE 0 END) AS bad_total_charges,
       SUM(CASE WHEN contract NOT IN ('Month-to-month','One year','Two year') THEN 1 ELSE 0 END) AS bad_contract FROM customers;

-- @Q1 Executive summary: how big is the churn problem?
SELECT COUNT(*) AS customers, SUM(churned) AS churned, ROUND(100.0*SUM(churned)/COUNT(*),1) AS churn_rate_pct,
       ROUND(SUM(monthly_charges),0) AS monthly_revenue, ROUND(SUM(CASE WHEN churned=1 THEN monthly_charges END),0) AS churned_monthly_revenue,
       ROUND(100.0*SUM(CASE WHEN churned=1 THEN monthly_charges END)/SUM(monthly_charges),1) AS pct_revenue_churned, ROUND(AVG(tenure_months),1) AS avg_tenure_months
FROM v_customers;

-- @Q2 Churn by contract type, with each contract's share of ALL churners (window function over an aggregate)
SELECT contract, COUNT(*) AS customers, SUM(churned) AS churned, ROUND(100.0*AVG(churned),1) AS churn_rate_pct,
       ROUND(100.0*SUM(churned)/SUM(SUM(churned)) OVER (),1) AS share_of_all_churners_pct
FROM v_customers GROUP BY contract ORDER BY churn_rate_pct DESC;

-- @Q3 Churn by tenure band: when do customers leave?
SELECT tenure_band, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(AVG(monthly_charges),0) AS avg_monthly_charge
FROM v_customers GROUP BY tenure_band ORDER BY tenure_band;

-- @Q4 Contract x internet service matrix (conditional aggregation = pivot in plain SQL)
SELECT contract,
  ROUND(100.0*AVG(CASE WHEN internet_service='Fiber optic' THEN churned END),1) AS fiber_churn_pct,
  ROUND(100.0*AVG(CASE WHEN internet_service='DSL' THEN churned END),1) AS dsl_churn_pct,
  ROUND(100.0*AVG(CASE WHEN internet_service='No internet' THEN churned END),1) AS no_internet_churn_pct,
  SUM(CASE WHEN internet_service='Fiber optic' THEN 1 ELSE 0 END) AS fiber_customers
FROM v_customers GROUP BY contract ORDER BY fiber_churn_pct DESC;

-- @Q5 Do add-on services reduce churn? (internet customers only)
SELECT n_addons, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(AVG(monthly_charges),0) AS avg_monthly_charge
FROM v_customers WHERE internet_service <> 'No internet' GROUP BY n_addons ORDER BY n_addons;

-- @Q6 Payment method x paperless billing
SELECT payment_method, paperless_billing, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct
FROM v_customers GROUP BY payment_method, paperless_billing ORDER BY churn_rate_pct DESC LIMIT 6;

-- @Q7 Support tickets in the last 6 months vs churn (service-quality signal)
SELECT CASE WHEN support_tickets_6m=0 THEN '0' WHEN support_tickets_6m=1 THEN '1' WHEN support_tickets_6m=2 THEN '2' ELSE '3+' END AS tickets_6m,
       COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct
FROM v_customers GROUP BY 1 ORDER BY 1;

-- @Q8 Signup-year cohorts: churn rate and average tenure
SELECT substr(signup_date,1,4) AS signup_year, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(AVG(tenure_months),1) AS avg_tenure_months
FROM v_customers GROUP BY 1 ORDER BY 1;

-- @Q9 Cities whose churn is above their region's average (CTE + join + RANK window function)
WITH city AS (SELECT region, city, COUNT(*) AS customers, AVG(churned) AS rate FROM v_customers GROUP BY region, city),
     reg  AS (SELECT region, AVG(churned) AS region_rate FROM v_customers GROUP BY region)
SELECT c.region, c.city, c.customers, ROUND(100*c.rate,1) AS city_churn_pct, ROUND(100*r.region_rate,1) AS region_churn_pct,
       ROUND(100*(c.rate-r.region_rate),1) AS gap_pts, RANK() OVER (PARTITION BY c.region ORDER BY c.rate DESC) AS rank_in_region
FROM city c JOIN reg r USING(region) WHERE c.rate > r.region_rate ORDER BY gap_pts DESC LIMIT 8;

-- @Q10 Lifetime revenue: churned vs retained customers
SELECT churn, COUNT(*) AS customers, ROUND(AVG(tenure_months),1) AS avg_tenure_months, ROUND(AVG(total_charges),0) AS avg_lifetime_revenue, ROUND(AVG(monthly_charges),0) AS avg_monthly_charge
FROM v_customers GROUP BY churn;

-- @Q11 Which small segments produce most churners? (contract x internet x first-year, segments >= 100 customers)
SELECT contract, internet_service, CASE WHEN tenure_months<=12 THEN 'first year' ELSE 'after 1st year' END AS stage, COUNT(*) AS customers,
       ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(100.0*SUM(churned)/(SELECT SUM(churned) FROM v_customers),1) AS pct_of_all_churners
FROM v_customers GROUP BY 1,2,3 HAVING COUNT(*) >= 100 ORDER BY pct_of_all_churners DESC LIMIT 6;

-- @Q12 Revenue-weighted priority: top 10 ACTIVE customers on month-to-month Fiber with 3+ tickets (retention call list)
SELECT ROW_NUMBER() OVER (ORDER BY monthly_charges DESC) AS priority, customer_id, region, tenure_months, monthly_charges, support_tickets_6m, late_payments_12m
FROM v_customers WHERE churned=0 AND contract='Month-to-month' AND internet_service='Fiber optic' AND support_tickets_6m>=3 ORDER BY priority LIMIT 10;
