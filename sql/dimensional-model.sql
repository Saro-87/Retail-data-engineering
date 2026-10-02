-- ============================================================
-- RETAIL DATA ENGINEERING - DIMENSIONAL MODEL
-- ============================================================
--
-- Fact grain:
--   One row per valid, deduplicated transaction.
--
-- Reporting grain:
--   Region + Transaction Date aggregation can be generated
--   from fact_transactions.
--
-- ============================================================


-- ============================================================
-- 1. DATE DIMENSION
-- ============================================================

CREATE TABLE dim_date (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE NOT NULL UNIQUE,
    year            INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    day             INTEGER NOT NULL
);


-- ============================================================
-- 2. CUSTOMER DIMENSION
-- ============================================================

CREATE TABLE dim_customer (
    customer_key    BIGINT PRIMARY KEY,
    customer_id     VARCHAR(50) NOT NULL UNIQUE
);


-- ============================================================
-- 3. PRODUCT DIMENSION
-- ============================================================

CREATE TABLE dim_product (
    product_key     BIGINT PRIMARY KEY,
    product_id      VARCHAR(50) NOT NULL UNIQUE
);


-- ============================================================
-- 4. REGION DIMENSION
-- ============================================================

CREATE TABLE dim_region (
    region_key      BIGINT PRIMARY KEY,
    region_id       VARCHAR(50) NOT NULL UNIQUE
);


-- ============================================================
-- 5. TRANSACTION FACT TABLE
-- ============================================================

CREATE TABLE fact_transactions (
    transaction_key             BIGINT PRIMARY KEY,

    transaction_id              VARCHAR(50) NOT NULL UNIQUE,

    date_key                    INTEGER NOT NULL,
    customer_key                BIGINT NOT NULL,
    product_key                 BIGINT NOT NULL,
    region_key                  BIGINT NOT NULL,

    transaction_amount          DECIMAL(18,2) NOT NULL,
    quantity                    INTEGER NOT NULL,

    payment_method              VARCHAR(30) NOT NULL,

    transaction_count           INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT fk_fact_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),

    CONSTRAINT fk_fact_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),

    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_key)
        REFERENCES dim_product(product_key),

    CONSTRAINT fk_fact_region
        FOREIGN KEY (region_key)
        REFERENCES dim_region(region_key)
);


-- ============================================================
-- 6. DAILY REGION SALES AGGREGATION
-- ============================================================
--
-- This table represents the reporting output produced
-- by the PySpark ETL.
--
-- Grain:
--   One row per Region + Transaction Date.
--
-- ============================================================

CREATE TABLE fact_region_daily_sales (
    date_key                    INTEGER NOT NULL,
    region_key                  BIGINT NOT NULL,

    transaction_count           INTEGER NOT NULL,
    total_quantity              INTEGER NOT NULL,
    total_sales                 DECIMAL(18,2) NOT NULL,

    CONSTRAINT pk_region_daily_sales
        PRIMARY KEY (date_key, region_key),

    CONSTRAINT fk_daily_sales_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),

    CONSTRAINT fk_daily_sales_region
        FOREIGN KEY (region_key)
        REFERENCES dim_region(region_key)
);


-- ============================================================
-- DATA MODEL NOTES
-- ============================================================
--
-- Dimension Tables:
--
-- dim_date
-- dim_customer
-- dim_product
-- dim_region
--
-- Fact Tables:
--
-- fact_transactions
--     Transaction-level fact table.
--
-- fact_region_daily_sales
--     Aggregated reporting fact table.
--
-- ============================================================