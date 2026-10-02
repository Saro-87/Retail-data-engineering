import os
import sys
from decimal import Decimal

import psycopg2


DB_CONFIG = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5432")),
    "database": os.getenv("PGDATABASE", "retail_data_engineering"),
    "user": os.getenv("PGUSER", "postgres"),
    "password": os.getenv("PGPASSWORD"),
}


def check_test(results, name, actual, expected):
    if actual == expected:
        print(f"[PASS] {name}: {actual}")
        results.append(True)
    else:
        print(f"[FAIL] {name}: expected {expected}, got {actual}")
        results.append(False)


def run_tests():
    print("=" * 60)
    print("RETAIL DATA ENGINEERING - AUTOMATED SQL TESTS")
    print("=" * 60)

    results = []

    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()

        # ======================================================
        # DATA QUALITY TESTS
        # ======================================================

        print()
        print("DATA QUALITY")
        print("-" * 60)

        # 1. Fact transaction count
        cursor.execute("""
            SELECT COUNT(*)
            FROM fact_transactions;
        """)
        check_test(
            results,
            "Fact transaction count",
            cursor.fetchone()[0],
            30,
        )

        # 2. No duplicate transaction IDs in fact
        cursor.execute("""
            SELECT COUNT(*)
            FROM (
                SELECT transaction_id
                FROM fact_transactions
                GROUP BY transaction_id
                HAVING COUNT(*) > 1
            ) duplicates;
        """)
        check_test(
            results,
            "No duplicate transaction IDs in fact",
            cursor.fetchone()[0],
            0,
        )

        # 3. Staging duplicate
        cursor.execute("""
            SELECT COUNT(*)
            FROM (
                SELECT transaction_id
                FROM stg_transactions
                WHERE transaction_id = 'TXN1005'
                GROUP BY transaction_id
                HAVING COUNT(*) = 2
            ) duplicates;
        """)
        check_test(
            results,
            "Staging duplicate TXN1005 detected",
            cursor.fetchone()[0],
            1,
        )

        # 4. Aggregation row count
        cursor.execute("""
            SELECT COUNT(*)
            FROM fact_region_daily_sales;
        """)
        check_test(
            results,
            "Region aggregation row count",
            cursor.fetchone()[0],
            30,
        )

        # 5. September sales
        cursor.execute("""
            SELECT ROUND(SUM(transaction_amount), 2)
            FROM fact_transactions f
            JOIN dim_date d
                ON f.date_key = d.date_key
            WHERE d.year = 2026
              AND d.month = 9;
        """)
        actual = cursor.fetchone()[0]
        expected = Decimal("55078.26")
        check_test(
            results,
            "September 2026 total sales",
            actual,
            expected,
        )

        # ======================================================
        # ASSESSMENT H1-H5
        # ======================================================

        print()
        print("ASSESSMENT H1-H5")
        print("-" * 60)

        # ------------------------------------------------------
        # H1 - Top 10 customers
        # ------------------------------------------------------

        cursor.execute("""
            SELECT COUNT(*)
            FROM (
                SELECT
                    c.customer_id,
                    SUM(f.transaction_amount) AS total_sales
                FROM fact_transactions f
                JOIN dim_customer c
                    ON f.customer_key = c.customer_key
                GROUP BY c.customer_id
                ORDER BY total_sales DESC
                LIMIT 10
            ) top_customers;
        """)

        check_test(
            results,
            "H1 Top 10 customers returns 10 rows",
            cursor.fetchone()[0],
            10,
        )

        # ------------------------------------------------------
        # H2 - Region sales last 30 days
        # ------------------------------------------------------

        cursor.execute("""
            SELECT COUNT(*)
            FROM (
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
            ) region_sales;
        """)

        check_test(
            results,
            "H2 Region sales last 30 days returns 4 regions",
            cursor.fetchone()[0],
            4,
        )

        # ------------------------------------------------------
        # H3 - Month-over-month sales
        # ------------------------------------------------------

        cursor.execute("""
            WITH monthly_sales AS (
                SELECT
                    d.year,
                    d.month,
                    SUM(f.transaction_amount) AS total_sales
                FROM fact_transactions f
                JOIN dim_date d
                    ON f.date_key = d.date_key
                GROUP BY d.year, d.month
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
            SELECT COUNT(*)
            FROM sales_with_previous_month;
        """)

        check_test(
            results,
            "H3 Month-over-month query returns monthly data",
            cursor.fetchone()[0],
            1,
        )

        # ------------------------------------------------------
        # H4 - Duplicate transactions
        #
        # The final fact table must contain zero duplicates.
        # ------------------------------------------------------

        cursor.execute("""
            SELECT COUNT(*)
            FROM (
                SELECT transaction_id
                FROM fact_transactions
                GROUP BY transaction_id
                HAVING COUNT(*) > 1
            ) duplicates;
        """)

        check_test(
            results,
            "H4 Duplicate transactions in fact",
            cursor.fetchone()[0],
            0,
        )

        # ------------------------------------------------------
        # H5 - Customers with no transactions in last 90 days
        # ------------------------------------------------------

        cursor.execute("""
            SELECT COUNT(*)
            FROM (
                SELECT c.customer_id
                FROM dim_customer c
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM fact_transactions f
                    JOIN dim_date d
                        ON f.date_key = d.date_key
                    WHERE f.customer_key = c.customer_key
                      AND d.full_date >= CURRENT_DATE - INTERVAL '90 days'
                )
            ) inactive_customers;
        """)

        check_test(
            results,
            "H5 Customers with no transactions in last 90 days",
            cursor.fetchone()[0],
            10,
        )

        cursor.close()
        conn.close()

    except Exception as exc:
        print()
        print("[ERROR] SQL test execution failed")
        print(str(exc))
        sys.exit(1)

    # ==========================================================
    # FINAL RESULT
    # ==========================================================

    passed = sum(results)
    total = len(results)
    failed = total - passed

    print()
    print("=" * 60)
    print(f"RESULT: {passed}/{total} TESTS PASSED")
    print("=" * 60)

    if failed:
        print(f"[ERROR] {failed} test(s) failed.")
        sys.exit(1)

    print("[SUCCESS] All automated SQL tests passed.")


if __name__ == "__main__":
    run_tests()