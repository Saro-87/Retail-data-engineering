# Retail Data Engineering Platform
# Streaming Design

## 1. Overview

The streaming architecture supports near-real-time retail transaction
processing.

Amazon Kinesis Data Streams is used as the primary streaming ingestion
service.

The streaming pipeline is:

Application
    |
    v
Amazon Kinesis Data Streams
    |
    v
Spark Structured Streaming
    |
    v
Data Quality Validation
    |
    +---- Invalid Events ----> Dead Letter / Quarantine
    |
    v
Deduplication
    |
    v
Transformation
    |
    v
Amazon S3 Processed
    |
    v
Amazon S3 Curated
    |
    v
Analytics / BI


## 2. Streaming Ingestion

Retail applications publish transaction events to Amazon Kinesis Data
Streams.

Example event:

```json
{
  "transaction_id": "TXN1001",
  "customer_id": "CUST001",
  "transaction_date": "2026-09-15 10:30:00",
  "transaction_amount": 799.00,
  "region_id": "IN-N",
  "product_id": "PROD001",
  "quantity": 1,
  "payment_method": "UPI"
}