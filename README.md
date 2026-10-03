# Retail Data Engineering - AWS Technical Assessment

## Overview

This repository implements a practical AWS-based retail data engineering
solution covering batch processing, data lake design, analytics, streaming
design, infrastructure as code, CI/CD, security and governance.

The implementation contains both locally tested components and AWS-deployed
components. AWS services that were designed but not deployed as part of the
assessment are explicitly identified as production/reference architecture.

## Assessment Coverage

| Area | Implementation | Status |
|---|---|---|
| Solution Architecture | AWS data lake + batch/streaming architecture | Complete |
| Data Lake Design | S3 Raw / Processed / Curated / Quarantine | Complete |
| PySpark ETL | Validation, deduplication, date normalization, aggregation | Tested |
| Data Modeling | Fact and dimension model | Tested |
| Advanced SQL | H1-H5 assessment queries | 10/10 tests passed |
| Streaming | Local streaming demonstration + AWS design | Tested |
| Terraform | S3, KMS, IAM, Glue, CloudWatch | Deployed |
| Terraform Remote State | S3 backend | Configured |
| CI/CD | GitHub + Jenkins + Terraform | Tested |
| Security | IAM, KMS, S3 security, lifecycle, monitoring | Documented |
| Governance | Logging, retention, access controls and audit design | Documented |

---

## Architecture

The solution follows a layered data lake architecture:

```text
Source Systems
      |
      +---------------- Batch ----------------+
      |                                       |
      v                                       v
   Amazon S3 Raw                         Kinesis
      |                                       |
      v                                       v
 AWS Glue / Spark                    Streaming Processing
      |                                       |
      +---------------+-----------------------+
                      |
                      v
              Data Quality / Dedup
                      |
             +--------+--------+
             |                 |
             v                 v
       Processed Data      Quarantine / DLQ
             |
             v
       Curated Data
             |
             v
          Athena
             |
             v
      Reporting / Analytics