-- =====================================================================
-- PROJECT 2 : Customer Churn Analysis | 01_schema.sql   (SQLite; MySQL/PostgreSQL notes inline)
-- customers  = cleaned customer master/billing (one row per customer)
-- churn_scores = model output (out-of-fold churn probability, risk tier, retention playbook) from the Python notebook
-- =====================================================================
DROP VIEW IF EXISTS v_customers; DROP TABLE IF EXISTS churn_scores; DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  customer_id TEXT PRIMARY KEY, signup_date TEXT NOT NULL, gender TEXT, senior_citizen INTEGER CHECK (senior_citizen IN (0,1)),
  partner TEXT, dependents TEXT, region TEXT NOT NULL, city TEXT, tenure_months INTEGER NOT NULL CHECK (tenure_months >= 0),
  contract TEXT NOT NULL CHECK (contract IN ('Month-to-month','One year','Two year')), payment_method TEXT, paperless_billing TEXT,
  phone_service TEXT, internet_service TEXT, online_security TEXT, online_backup TEXT, device_protection TEXT, tech_support TEXT,
  streaming_tv TEXT, streaming_movies TEXT, monthly_charges REAL NOT NULL CHECK (monthly_charges > 0), total_charges REAL NOT NULL,
  avg_monthly_data_gb REAL, support_tickets_6m INTEGER, late_payments_12m INTEGER, churn TEXT NOT NULL CHECK (churn IN ('Yes','No')));
CREATE TABLE churn_scores (
  customer_id TEXT PRIMARY KEY REFERENCES customers(customer_id), churn_probability REAL NOT NULL CHECK (churn_probability BETWEEN 0 AND 1),
  risk_tier TEXT NOT NULL, playbook TEXT);
CREATE INDEX idx_cust_contract ON customers(contract); CREATE INDEX idx_cust_churn ON customers(churn);

-- Convenience view: derived fields used by many queries
CREATE VIEW v_customers AS
SELECT c.*, CASE WHEN churn='Yes' THEN 1 ELSE 0 END AS churned,
       CASE WHEN tenure_months <= 6 THEN '1. 0-6 m' WHEN tenure_months <= 12 THEN '2. 7-12 m' WHEN tenure_months <= 24 THEN '3. 13-24 m'
            WHEN tenure_months <= 48 THEN '4. 25-48 m' ELSE '5. 49+ m' END AS tenure_band,
       (CASE WHEN online_security='Yes' THEN 1 ELSE 0 END + CASE WHEN online_backup='Yes' THEN 1 ELSE 0 END + CASE WHEN device_protection='Yes' THEN 1 ELSE 0 END
        + CASE WHEN tech_support='Yes' THEN 1 ELSE 0 END + CASE WHEN streaming_tv='Yes' THEN 1 ELSE 0 END + CASE WHEN streaming_movies='Yes' THEN 1 ELSE 0 END) AS n_addons
FROM customers c;
