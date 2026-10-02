# Retail Data Engineering Platform
# Solution Architecture

## 1. Architecture Overview

The solution uses AWS services to build a scalable retail data platform
supporting both batch and streaming transaction ingestion.

The architecture follows:

Source Systems
      |
      +--------------------+
      |                    |
      v                    v
 Batch Ingestion      Streaming Ingestion
      |                    |
      v                    v
     Amazon S3          Amazon Kinesis
      |                    |
      +---------+----------+
                |
                v
        AWS Glue / Spark
                |
       +--------+--------+
       |                 |
       v                 v
  Processed S3       Quarantine
       |
       v
  Curated S3
       |
       +-------------------+
       |                   |
       v                   v
   Athena / BI       Data Consumers