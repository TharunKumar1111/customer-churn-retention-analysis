-- =====================================================================
-- 03_churn_analysis.sql : 15 queries. Concepts: CASE pivots, CTEs, window functions (SUM OVER, RANK, NTILE, ROW_NUMBER), joins, HAVING
-- =====================================================================
-- @Q1 Executive summary: churn rate and revenue impact
SELECT COUNT(*) AS customers, SUM(churned) AS churned, ROUND(100.0*SUM(churned)/COUNT(*),1) AS churn_rate_pct,
       ROUND(SUM(monthly_charges),0) AS monthly_revenue, ROUND(SUM(CASE WHEN churned=1 THEN monthly_charges END),0) AS churned_monthly_revenue,
       ROUND(100.0*SUM(CASE WHEN churned=1 THEN monthly_charges END)/SUM(monthly_charges),1) AS pct_revenue_churned, ROUND(AVG(tenure_months),1) AS avg_tenure
FROM v_customers;

-- @Q2 Churn by contract + each contract's share of ALL churners (window function over aggregate)
SELECT contract, COUNT(*) AS customers, SUM(churned) AS churned, ROUND(100.0*AVG(churned),1) AS churn_rate_pct,
       ROUND(100.0*SUM(churned)/SUM(SUM(churned)) OVER (),1) AS share_of_all_churners_pct, ROUND(AVG(monthly_charges),0) AS avg_monthly_charge
FROM v_customers GROUP BY contract ORDER BY churn_rate_pct DESC;

-- @Q3 Churn by tenure band - the early-life risk
SELECT tenure_band, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(AVG(monthly_charges),0) AS avg_charge
FROM v_customers GROUP BY tenure_band ORDER BY tenure_band;

-- @Q4 Contract x internet service matrix (conditional aggregation = pivot in plain SQL)
SELECT contract,
  ROUND(100.0*AVG(CASE WHEN internet_service='Fiber optic' THEN churned END),1) AS fiber_churn_pct,
  ROUND(100.0*AVG(CASE WHEN internet_service='DSL' THEN churned END),1) AS dsl_churn_pct,
  ROUND(100.0*AVG(CASE WHEN internet_service='No internet' THEN churned END),1) AS no_internet_churn_pct,
  SUM(CASE WHEN internet_service='Fiber optic' THEN 1 ELSE 0 END) AS fiber_customers
FROM v_customers GROUP BY contract ORDER BY fiber_churn_pct DESC;

-- @Q5 Do add-on services protect against churn? (internet customers only)
SELECT n_addons, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(AVG(monthly_charges),0) AS avg_charge
FROM v_customers WHERE internet_service <> 'No internet' GROUP BY n_addons ORDER BY n_addons;

-- @Q6 Payment method and paperless billing
SELECT payment_method, paperless_billing, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct
FROM v_customers GROUP BY payment_method, paperless_billing ORDER BY churn_rate_pct DESC LIMIT 6;

-- @Q7 Support-ticket intensity (last 6 months) vs churn
SELECT CASE WHEN support_tickets_6m=0 THEN '0' WHEN support_tickets_6m=1 THEN '1' WHEN support_tickets_6m=2 THEN '2' ELSE '3+' END AS tickets,
       COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct
FROM v_customers GROUP BY 1 ORDER BY 1;

-- @Q8 Signup-year cohorts: churn rate and average tenure by year of signup
SELECT substr(signup_date,1,4) AS signup_year, COUNT(*) AS customers, ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(AVG(tenure_months),1) AS avg_tenure_months
FROM v_customers GROUP BY 1 ORDER BY 1;

-- @Q9 Cities whose churn is above their region's average (CTE + join + RANK)
WITH city AS (SELECT region, city, COUNT(*) AS customers, AVG(churned) AS rate FROM v_customers GROUP BY region, city),
reg AS (SELECT region, AVG(churned) AS region_rate FROM v_customers GROUP BY region)
SELECT c.region, c.city, c.customers, ROUND(100*c.rate,1) AS city_churn_pct, ROUND(100*r.region_rate,1) AS region_churn_pct,
       ROUND(100*(c.rate-r.region_rate),1) AS gap_pts, RANK() OVER (PARTITION BY c.region ORDER BY c.rate DESC) AS rank_in_region
FROM city c JOIN reg r USING(region) WHERE c.rate > r.region_rate ORDER BY gap_pts DESC LIMIT 8;

-- @Q10 Revenue at risk: ACTIVE customers by model risk tier
SELECT s.risk_tier, COUNT(*) AS active_customers, ROUND(SUM(c.monthly_charges),0) AS monthly_revenue, ROUND(12*SUM(c.monthly_charges),0) AS annual_revenue,
       ROUND(AVG(s.churn_probability),3) AS avg_churn_probability
FROM v_customers c JOIN churn_scores s USING(customer_id) WHERE c.churned=0
GROUP BY s.risk_tier ORDER BY CASE s.risk_tier WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 ELSE 4 END;

-- @Q11 Call list: top 10 active customers by expected revenue loss = probability x annual charges (ROW_NUMBER)
SELECT ROW_NUMBER() OVER (ORDER BY s.churn_probability*c.monthly_charges*12 DESC) AS priority, c.customer_id, c.region, c.contract, c.internet_service,
       c.tenure_months, c.monthly_charges, ROUND(s.churn_probability,2) AS churn_prob, ROUND(s.churn_probability*c.monthly_charges*12,0) AS expected_annual_loss, s.playbook
FROM v_customers c JOIN churn_scores s USING(customer_id) WHERE c.churned=0 ORDER BY priority LIMIT 10;

-- @Q12 Model validation in SQL: actual churn rate by predicted-risk decile (NTILE)
WITH d AS (SELECT c.churned, s.churn_probability, NTILE(10) OVER (ORDER BY s.churn_probability DESC) AS decile FROM v_customers c JOIN churn_scores s USING(customer_id))
SELECT decile, COUNT(*) AS customers, ROUND(AVG(churn_probability),3) AS avg_predicted, ROUND(AVG(churned),3) AS actual_churn_rate,
       ROUND(100.0*SUM(SUM(churned)) OVER (ORDER BY decile)/SUM(SUM(churned)) OVER (),1) AS cumulative_churners_captured_pct
FROM d GROUP BY decile ORDER BY decile;

-- @Q13 Retention playbook summary for the high-risk active customers
SELECT s.playbook, COUNT(*) AS customers, ROUND(SUM(c.monthly_charges),0) AS monthly_revenue, ROUND(AVG(s.churn_probability),2) AS avg_prob
FROM v_customers c JOIN churn_scores s USING(customer_id) WHERE c.churned=0 AND s.playbook <> '' GROUP BY s.playbook ORDER BY customers DESC;

-- @Q14 Lifetime revenue: churned vs retained customers
SELECT churn, COUNT(*) AS customers, ROUND(AVG(tenure_months),1) AS avg_tenure, ROUND(AVG(total_charges),0) AS avg_lifetime_revenue, ROUND(AVG(monthly_charges),0) AS avg_monthly
FROM v_customers GROUP BY churn;

-- @Q15 Concentration: which small segments produce most churners? (contract x internet x tenure<=12)
SELECT contract, internet_service, CASE WHEN tenure_months<=12 THEN 'first year' ELSE 'after 1st year' END AS stage, COUNT(*) AS customers,
       ROUND(100.0*AVG(churned),1) AS churn_rate_pct, ROUND(100.0*SUM(churned)/(SELECT SUM(churned) FROM v_customers),1) AS pct_of_all_churners
FROM v_customers GROUP BY 1,2,3 HAVING COUNT(*) >= 100 ORDER BY pct_of_all_churners DESC LIMIT 6;
