# Retail Data Lake Design

## 1. Overview

The Retail Data Lake uses Amazon S3 as the central storage layer.

The data lake follows a three-layer architecture:

- Raw
- Processed
- Curated

The design supports scalable batch and streaming ingestion and enables
downstream analytics using AWS Glue, Spark, Athena, and other AWS services.

---

## 2. S3 Data Lake Structure

```text
s3://retail-data-lake/

├── raw/
│   └── transactions/
│       └── ingestion_date=YYYY-MM-DD/
│           └── source files

├── processed/
│   └── transactions/
│       └── year=YYYY/
│           └── month=MM/
│               └── day=DD/
│                   └── transaction files

└── curated/
    └── region_daily_sales/
        └── year=YYYY/
            └── month=MM/
                └── day=DD/
                    └── parquet files