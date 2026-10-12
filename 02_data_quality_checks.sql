-- =====================================================================
-- 02_data_quality_checks.sql  (problem counts should be 0)
-- =====================================================================
-- @DQ1 Row counts and key uniqueness
SELECT (SELECT COUNT(*) FROM customers) AS customers, (SELECT COUNT(DISTINCT customer_id) FROM customers) AS distinct_ids,
       (SELECT COUNT(*) FROM churn_scores) AS scored_customers;
-- @DQ2 Missing / invalid values
SELECT SUM(CASE WHEN monthly_charges <= 0 THEN 1 ELSE 0 END) AS bad_monthly, SUM(CASE WHEN total_charges < 0 THEN 1 ELSE 0 END) AS bad_total,
       SUM(CASE WHEN tenure_months < 0 THEN 1 ELSE 0 END) AS bad_tenure, SUM(CASE WHEN gender IS NULL OR gender='' THEN 1 ELSE 0 END) AS missing_gender FROM customers;
-- @DQ3 Total charges should be about monthly_charges x tenure (flag rows off by > 10%)
SELECT COUNT(*) AS inconsistent_total_charges FROM customers WHERE tenure_months > 0 AND ABS(total_charges - monthly_charges*tenure_months) > 0.10*monthly_charges*tenure_months;
-- @DQ4 Customers with no internet should have no internet add-ons
SELECT COUNT(*) AS addon_without_internet FROM customers WHERE internet_service='No internet' AND (online_security='Yes' OR tech_support='Yes' OR streaming_tv='Yes');
-- @DQ5 Score coverage and range
SELECT COUNT(*) AS customers_without_score FROM customers c LEFT JOIN churn_scores s USING(customer_id) WHERE s.customer_id IS NULL;
-- @DQ6 Category spelling check: distinct values
SELECT 'contract' AS col, GROUP_CONCAT(DISTINCT contract) AS vals FROM customers UNION ALL SELECT 'payment_method', GROUP_CONCAT(DISTINCT payment_method) FROM customers UNION ALL SELECT 'internet_service', GROUP_CONCAT(DISTINCT internet_service) FROM customers;
