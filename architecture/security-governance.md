# Security and Governance

## 1. Security Approach

The retail data engineering platform follows a layered security model covering:

- Identity and access management
- Encryption at rest
- Encryption in transit
- S3 public access protection
- Least-privilege IAM
- Data retention and lifecycle
- Logging and monitoring
- Infrastructure auditability
- Controlled data access

The implementation separates raw, processed, curated and quarantine data
within the S3 data lake.

---

## 2. IAM Least Privilege

AWS Glue uses a dedicated IAM role:

`retail-data-engineering-dev-glue-role`

The role is assumed by the AWS Glue service.

The Glue role has access only to the required data lake resources.

### S3 permissions

The implementation allows:

- `s3:ListBucket` on the data lake bucket
- `s3:GetObject` on raw transaction data
- `s3:GetObject` on the Glue ETL script
- `s3:GetObject` and `s3:PutObject` on processed data
- `s3:GetObject` and `s3:PutObject` on curated data
- `s3:GetObject` and `s3:PutObject` on quarantine data

The policy does not provide unrestricted access to all S3 buckets.

---

## 3. Encryption at Rest

The S3 data lake uses server-side encryption with AWS KMS:

```text
SSE Algorithm: aws:kms