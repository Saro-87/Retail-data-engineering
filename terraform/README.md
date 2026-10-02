# Terraform Infrastructure

## Overview

This directory contains the Infrastructure as Code implementation for the Retail Data Engineering assessment.

Terraform provisions a representative AWS data lake and AWS Glue processing environment.

## AWS Resources

The configuration provisions:

- Amazon S3 data lake bucket
- S3 versioning
- S3 public access blocking
- S3 lifecycle configuration
- S3 SSE-KMS encryption
- AWS KMS key
- KMS key rotation
- AWS Glue IAM role
- IAM policies for Glue S3 access
- IAM policy for KMS access
- AWS Glue ETL job
- Glue ETL script uploaded to S3
- CloudWatch log group
- CloudWatch Glue failure alarm

## S3 Data Lake Prefixes

raw/
processed/
curated/
curated/region_daily_sales/
quarantine/
scripts/
glue-temp/

## Glue ETL Script

Terraform uploads the canonical PySpark script:

../pyspark/retail_transaction_etl.py

to:

scripts/retail_transaction_etl.py

in the S3 data lake bucket.

## Configuration

Use the example variables file:

terraform.tfvars.example

Create a local terraform.tfvars file with a globally unique S3 bucket name.

The real terraform.tfvars file is intentionally excluded from Git.

## Terraform Files

main.tf
    AWS resources and infrastructure

variables.tf
    Input variables

outputs.tf
    Terraform outputs

versions.tf
    Terraform and AWS provider requirements

terraform.tfvars.example
    Example local configuration

## Validation

Initialize Terraform:

terraform -chdir=terraform init

Format:

terraform -chdir=terraform fmt

Validate:

terraform -chdir=terraform validate

Create a plan:

terraform -chdir=terraform plan

## Current Validation Result

The configuration has been successfully validated.

The current plan reports:

Plan: 19 to add, 0 to change, 0 to destroy.

## Deployment

Apply infrastructure only when AWS provisioning is intentionally required:

terraform -chdir=terraform apply

No AWS resources are created simply by cloning this repository.

## Security

The Terraform configuration demonstrates:

- S3 public access blocking
- KMS encryption
- KMS key rotation
- IAM least privilege
- Environment-based naming
- Default resource tagging
- No credentials stored in Terraform source

## Production Considerations

For a production deployment, Terraform state should be stored in a controlled remote backend with appropriate access control, encryption and state locking.

AWS credentials should be supplied through an approved CI/CD identity mechanism rather than stored in source code.
