-- ============================================================
-- RETAIL DATA ENGINEERING - REAL DATA LOAD
-- PostgreSQL
-- ============================================================

-- ------------------------------------------------------------
-- 1. STAGING TABLE
-- Raw CSV data is retained here, including duplicates/invalid
-- records so that data-quality checks can be demonstrated.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_transactions;

CREATE TABLE stg_transactions (
    transaction_id       VARCHAR(50),
    customer_id          VARCHAR(50),
    transaction_date     VARCHAR(50),
    transaction_amount   VARCHAR(50),
    region_id            VARCHAR(50),
    product_id           VARCHAR(50),
    quantity             VARCHAR(50),
    payment_method       VARCHAR(30)
);

-- transactions_postgres.csv is a normalized copy of the source CSV with LF line endings for PostgreSQL COPY compatibility.
\copy stg_transactions FROM './data/transactions_postgres.csv' WITH (FORMAT csv, HEADER true);

-- ------------------------------------------------------------
-- 2. CLEAR PREVIOUS ASSESSMENT DATA
-- ------------------------------------------------------------

TRUNCATE TABLE
    fact_region_daily_sales,
    fact_transactions,
    dim_customer,
    dim_product,
    dim_region,
    dim_date
CASCADE;


-- ------------------------------------------------------------
-- 3. CUSTOMER DIMENSION
-- ------------------------------------------------------------

INSERT INTO dim_customer (
    customer_key,
    customer_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id),
    customer_id
FROM (
    SELECT DISTINCT customer_id
    FROM stg_transactions
    WHERE customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''
) x;


-- ------------------------------------------------------------
-- 4. PRODUCT DIMENSION
-- ------------------------------------------------------------

INSERT INTO dim_product (
    product_key,
    product_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id),
    product_id
FROM (
    SELECT DISTINCT product_id
    FROM stg_transactions
    WHERE product_id IS NOT NULL
      AND TRIM(product_id) <> ''
) x;


-- ------------------------------------------------------------
-- 5. REGION DIMENSION
-- ------------------------------------------------------------

INSERT INTO dim_region (
    region_key,
    region_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY region_id),
    region_id
FROM (
    SELECT DISTINCT region_id
    FROM stg_transactions
    WHERE region_id IS NOT NULL
      AND TRIM(region_id) <> ''
) x;


-- ------------------------------------------------------------
-- 6. DATE DIMENSION
-- ------------------------------------------------------------

INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    month,
    day
)
SELECT DISTINCT
    CAST(REPLACE(transaction_date, '-', '') AS INTEGER),
    transaction_date::DATE,
    EXTRACT(YEAR FROM transaction_date::DATE)::INTEGER,
    EXTRACT(MONTH FROM transaction_date::DATE)::INTEGER,
    EXTRACT(DAY FROM transaction_date::DATE)::INTEGER
FROM stg_transactions
WHERE transaction_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';


-- ------------------------------------------------------------
-- 7. FACT TRANSACTIONS
--
-- Validations:
--   transaction_id required
--   customer_id required
--   valid transaction date
--   valid amount
--   amount >= 0
--   region required
--   product required
--   quantity > 0
--   valid payment method
--
-- Duplicate transaction IDs are removed with ROW_NUMBER().
-- ------------------------------------------------------------

WITH validated AS (
    SELECT
        transaction_id,
        customer_id,
        transaction_date,
        transaction_amount::NUMERIC(18,2) AS transaction_amount,
        region_id,
        product_id,
        quantity::INTEGER AS quantity,
        payment_method
    FROM stg_transactions
    WHERE transaction_id IS NOT NULL
      AND TRIM(transaction_id) <> ''

      AND customer_id IS NOT NULL
      AND TRIM(customer_id) <> ''

      AND transaction_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

      AND transaction_amount ~ '^-?[0-9]+(\.[0-9]+)?$'
      AND transaction_amount::NUMERIC >= 0

      AND region_id IS NOT NULL
      AND TRIM(region_id) <> ''

      AND product_id IS NOT NULL
      AND TRIM(product_id) <> ''

      AND quantity ~ '^[0-9]+$'
      AND quantity::INTEGER > 0

      AND payment_method IN (
          'Credit Card',
          'Debit Card',
          'UPI',
          'Cash'
      )
),
deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY transaction_id
        ) AS rn
    FROM validated
)
INSERT INTO fact_transactions (
    transaction_key,
    transaction_id,
    date_key,
    customer_key,
    product_key,
    region_key,
    transaction_amount,
    quantity,
    payment_method,
    transaction_count
)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.transaction_id),
    d.transaction_id,
    dd.date_key,
    dc.customer_key,
    dp.product_key,
    dr.region_key,
    d.transaction_amount,
    d.quantity,
    d.payment_method,
    1
FROM deduplicated d
JOIN dim_date dd
    ON dd.full_date = d.transaction_date::DATE
JOIN dim_customer dc
    ON dc.customer_id = d.customer_id
JOIN dim_product dp
    ON dp.product_id = d.product_id
JOIN dim_region dr
    ON dr.region_id = d.region_id
WHERE d.rn = 1;


-- ------------------------------------------------------------
-- 8. REGION + DAILY AGGREGATION
-- ------------------------------------------------------------

INSERT INTO fact_region_daily_sales (
    date_key,
    region_key,
    transaction_count,
    total_quantity,
    total_sales
)
SELECT
    date_key,
    region_key,
    COUNT(*)::INTEGER,
    SUM(quantity)::INTEGER,
    SUM(transaction_amount)::NUMERIC(18,2)
FROM fact_transactions
GROUP BY
    date_key,
    region_key;


-- ------------------------------------------------------------
-- 9. REAL LOAD VALIDATION
-- ------------------------------------------------------------

SELECT 'STAGING_ROWS' AS metric, COUNT(*) AS value
FROM stg_transactions

UNION ALL

SELECT 'FACT_ROWS', COUNT(*)
FROM fact_transactions

UNION ALL

SELECT 'CUSTOMERS', COUNT(*)
FROM dim_customer

UNION ALL

SELECT 'PRODUCTS', COUNT(*)
FROM dim_product

UNION ALL

SELECT 'REGIONS', COUNT(*)
FROM dim_region

UNION ALL

SELECT 'DATES', COUNT(*)
FROM dim_date

UNION ALL

SELECT 'DAILY_REGION_ROWS', COUNT(*)
FROM fact_region_daily_sales

ORDER BY metric;