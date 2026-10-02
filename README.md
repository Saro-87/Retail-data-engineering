# Retail Data Engineering - AWS Technical Assessment

## Overview

This repository implements a practical AWS-based retail data engineering solution covering:

- AWS data lake architecture
- S3 Raw / Processed / Curated layers
- PySpark ETL and data quality validation
- Transaction deduplication
- Date normalization and partitioning
- Region-wise daily sales aggregation
- Dimensional data modeling
- Streaming architecture using Amazon Kinesis and Spark Structured Streaming
- Terraform infrastructure as code
- Jenkins CI/CD
- Advanced SQL analytics
- Security and governance
- Monitoring, failure handling and operational controls

---

## Repository Structure

```text
retail-data-engineering/
|
+-- architecture/
|   +-- solution-architecture.md
|   +-- data-lake-design.md
|   +-- architecture-diagram.md
|
+-- pyspark/
|   +-- retail_transaction_etl.py
|
|
+-- sql/
|   +-- dimensional-model.sql
|   +-- advanced-queries.sql
|
+-- streaming/
|   +-- streaming-design.md
|
+-- terraform/
|   +-- main.tf
|   +-- variables.tf
|   +-- outputs.tf
|   +-- versions.tf
|   +-- terraform.tfvars.example
|   +-- README.md
|
+-- cicd/
|   +-- Jenkinsfile
|   +-- README.md
|
+-- samples/
|   +-- transactions_sample.csv
|
+-- data/
|   +-- transactions.csv
|   +-- output/
|
+-- README.md