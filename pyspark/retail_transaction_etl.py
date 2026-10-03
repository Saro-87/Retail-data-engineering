import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    DoubleType,
    IntegerType
)

# =========================================================
# 1. Spark Session and Dynamic Arguments
# =========================================================

def get_argument(name, default):
    """Read --NAME value from command-line arguments."""
    argument = f"--{name}"

    if argument in sys.argv:
        index = sys.argv.index(argument)

        if index + 1 < len(sys.argv):
            return sys.argv[index + 1]

    return default


SOURCE_FILE = get_argument(
    "SOURCE_PATH",
    "./data/transactions.csv"
)

OUTPUT_PATH = get_argument(
    "OUTPUT_PATH",
    "./data/output/region_daily_sales"
)


spark = (
    SparkSession.builder
    .appName("RetailTransactionETL")
    .getOrCreate()
)

print("=" * 60)
print("RETAIL TRANSACTION ETL STARTED")
print("=" * 60)

print(f"Source path : {SOURCE_FILE}")
print(f"Output path : {OUTPUT_PATH}")


# =========================================================
# 2. Define Expected Schema
# =========================================================

schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("customer_id", StringType(), True),
    StructField("transaction_date", StringType(), True),
    StructField("transaction_amount", DoubleType(), True),
    StructField("region_id", StringType(), True),
    StructField("product_id", StringType(), True),
    StructField("quantity", IntegerType(), True),
    StructField("payment_method", StringType(), True)
])


# =========================================================
# 3. Read CSV
# =========================================================

df = (
    spark.read
    .option("header", "true")
    .schema(schema)
    .csv(SOURCE_FILE)
)

print("\nSTEP 1 - CSV READ")
print(f"Records read: {df.count()}")


# =========================================================
# 4. Schema Validation
# =========================================================

print("\nSTEP 2 - SCHEMA VALIDATION")

df.printSchema()

required_columns = [
    "transaction_id",
    "customer_id",
    "transaction_date",
    "transaction_amount",
    "region_id",
    "product_id",
    "quantity",
    "payment_method"
]

missing_columns = [
    column for column in required_columns
    if column not in df.columns
]

if missing_columns:
    raise ValueError(
        f"Missing required columns: {missing_columns}"
    )

print("Schema validation: PASSED")


# =========================================================
# 5. Null Handling
# =========================================================

print("\nSTEP 3 - NULL HANDLING")

null_condition = (
    F.col("transaction_id").isNull()
    | F.col("customer_id").isNull()
    | F.col("transaction_date").isNull()
    | F.col("transaction_amount").isNull()
    | F.col("region_id").isNull()
    | F.col("product_id").isNull()
    | F.col("quantity").isNull()
    | F.col("payment_method").isNull()
)

null_records = df.filter(null_condition)

print(f"Records containing NULL values: {null_records.count()}")


# =========================================================
# 6. Data Quality Checks
# =========================================================

print("\nSTEP 4 - DATA QUALITY CHECKS")

df = (
    df
    .withColumn(
        "normalized_timestamp",
        F.coalesce(
            F.to_timestamp(
                F.col("transaction_date"),
                "yyyy-MM-dd HH:mm:ss"
            ),
            F.to_timestamp(
                F.col("transaction_date"),
                "yyyy-MM-dd"
            )
        )
    )
    .withColumn(
        "normalized_date",
        F.to_date("normalized_timestamp")
    )
)

valid_payment_methods = [
    "Credit Card",
    "Debit Card",
    "UPI",
    "Cash"
]

quality_condition = (
    F.col("transaction_id").isNotNull()
    & F.col("customer_id").isNotNull()
    & F.col("normalized_date").isNotNull()
    & F.col("transaction_amount").isNotNull()
    & (F.col("transaction_amount") > 0)
    & F.col("region_id").isNotNull()
    & F.col("product_id").isNotNull()
    & F.col("quantity").isNotNull()
    & (F.col("quantity") > 0)
    & F.col("payment_method").isin(valid_payment_methods)
)

valid_quality_df = df.filter(quality_condition)

rejected_quality_df = df.filter(~quality_condition)

print(
    f"Valid records before deduplication: "
    f"{valid_quality_df.count()}"
)

print(
    f"Rejected records: "
    f"{rejected_quality_df.count()}"
)


# =========================================================
# 7. Deduplication
# =========================================================

print("\nSTEP 5 - DEDUPLICATION")

before_dedup = valid_quality_df.count()

deduplicated_df = valid_quality_df.dropDuplicates(
    ["transaction_id"]
)

after_dedup = deduplicated_df.count()

duplicates_removed = before_dedup - after_dedup

print(f"Records before deduplication: {before_dedup}")
print(f"Records after deduplication : {after_dedup}")
print(f"Duplicates removed          : {duplicates_removed}")


# =========================================================
# 8. Date Normalization
# =========================================================

print("\nSTEP 6 - DATE NORMALIZATION")

normalized_df = (
    deduplicated_df
    .withColumnRenamed(
        "normalized_date",
        "transaction_date_normalized"
    )
)


# =========================================================
# 9. Year / Month / Day
# =========================================================

print("\nSTEP 7 - YEAR / MONTH / DAY")

calendar_df = (
    normalized_df
    .withColumn(
        "year",
        F.year("transaction_date_normalized")
    )
    .withColumn(
        "month",
        F.month("transaction_date_normalized")
    )
    .withColumn(
        "day",
        F.dayofmonth("transaction_date_normalized")
    )
)

calendar_df.select(
    "transaction_id",
    "transaction_date_normalized",
    "year",
    "month",
    "day"
).show(10, truncate=False)


# =========================================================
# 10. Region + Day Aggregation
# =========================================================

print("\nSTEP 8 - REGION + DAY AGGREGATION")

aggregated_df = (
    calendar_df
    .groupBy(
        "region_id",
        "transaction_date_normalized",
        "year",
        "month",
        "day"
    )
    .agg(
        F.countDistinct("transaction_id")
        .alias("transaction_count"),

        F.sum("quantity")
        .alias("total_quantity"),

        F.round(
            F.sum("transaction_amount"),
            2
        )
        .alias("total_sales")
    )
    .orderBy(
        "transaction_date_normalized",
        "region_id"
    )
)

aggregated_df.show(
    100,
    truncate=False
)


# =========================================================
# 11. Write Parquet
# =========================================================

print("\nSTEP 9 - WRITE PARQUET")

(
    aggregated_df
    .write
    .mode("overwrite")
    .partitionBy(
        "year",
        "month",
        "day"
    )
    .parquet(OUTPUT_PATH)
)

print(f"Parquet output written to: {OUTPUT_PATH}")


# =========================================================
# 12. Final Summary
# =========================================================

print("\n" + "=" * 60)
print("ETL SUMMARY")
print("=" * 60)

print(f"Input records             : {df.count()}")
print(f"Rejected records          : {rejected_quality_df.count()}")
print(f"Valid records             : {valid_quality_df.count()}")
print(f"Duplicates removed       : {duplicates_removed}")
print(f"Final records             : {deduplicated_df.count()}")
print(f"Aggregated records        : {aggregated_df.count()}")
print(f"Parquet output            : {OUTPUT_PATH}")

print("=" * 60)
print("RETAIL TRANSACTION ETL COMPLETED")
print("=" * 60)


# =========================================================
# 13. Stop Spark
# =========================================================

spark.stop()
