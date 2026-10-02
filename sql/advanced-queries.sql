-- ============================================================
-- RETAIL DATA ENGINEERING - ADVANCED SQL
-- ============================================================
--
-- Assumptions:
--   fact_transactions = transaction-level fact
--   dim_customer      = customer dimension
--   dim_date          = date dimension
--   dim_region        = region dimension
--
-- SQL dialect: PostgreSQL
-- ============================================================


-- ============================================================
-- 1. TOP 10 CUSTOMERS BY TOTAL SALES
-- ============================================================

SELECT
    c.customer_id,
    SUM(f.transaction_amount) AS total_sales
FROM fact_transactions f
JOIN dim_customer c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_id
ORDER BY total_sales DESC
LIMIT 10;


-- ============================================================
-- 2. REGION-WISE SALES FOR THE LAST 30 DAYS
-- ============================================================

SELECT
    r.region_id,
    SUM(f.transaction_amount) AS total_sales
FROM fact_transactions f
JOIN dim_region r
    ON f.region_key = r.region_key
JOIN dim_date d
    ON f.date_key = d.date_key
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY r.region_id
ORDER BY total_sales DESC;


-- ============================================================
-- 3. MONTH-OVER-MONTH SALES GROWTH
-- ============================================================

WITH monthly_sales AS (
    SELECT
        d.year,
        d.month,
        SUM(f.transaction_amount) AS total_sales
    FROM fact_transactions f
    JOIN dim_date d
        ON f.date_key = d.date_key
    GROUP BY
        d.year,
        d.month
),
sales_with_previous_month AS (
    SELECT
        year,
        month,
        total_sales,
        LAG(total_sales) OVER (
            ORDER BY year, month
        ) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    year,
    month,
    total_sales,
    previous_month_sales,
    CASE
        WHEN previous_month_sales IS NULL
             OR previous_month_sales = 0
        THEN NULL
        ELSE ROUND(
            (
                (total_sales - previous_month_sales)
                / previous_month_sales
            ) * 100,
            2
        )
    END AS mom_growth_percentage
FROM sales_with_previous_month
ORDER BY year, month;


-- ============================================================
-- 4. DUPLICATE TRANSACTIONS
-- ============================================================
--
-- Identifies transaction IDs occurring more than once.
-- This is useful for data-quality validation before
-- transaction-level deduplication.
-- ============================================================

SELECT
    transaction_id,
    COUNT(*) AS occurrence_count
FROM fact_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC, transaction_id;


-- ============================================================
-- 5. CUSTOMERS WITH NO TRANSACTIONS IN THE LAST 90 DAYS
-- ============================================================

SELECT
    c.customer_id
FROM dim_customer c
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_transactions f
    JOIN dim_date d
        ON f.date_key = d.date_key
    WHERE f.customer_key = c.customer_key
      AND d.full_date >= CURRENT_DATE - INTERVAL '90 days'
)
ORDER BY c.customer_id;


-- ============================================================
-- END OF ADVANCED SQL
-- ============================================================
