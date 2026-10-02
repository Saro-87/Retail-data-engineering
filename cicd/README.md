# Retail Data Engineering - AWS Technical Assessment

## CI/CD Overview

This project uses Jenkins to automate Terraform validation, planning and controlled deployment.

The pipeline is defined in:

cicd/Jenkinsfile

## Pipeline Flow

Git Checkout
    |
    v
Terraform Format Check
    |
    v
Terraform Init
    |
    v
Terraform Validate
    |
    v
Terraform Plan
    |
    v
Production Approval
    |
    v
Terraform Apply

## Environments

The Jenkins pipeline supports:

- dev
- test
- prod

The target environment is selected using the ENVIRONMENT parameter.

## Apply Control

Terraform deployment is controlled by the APPLY parameter.

Default:

APPLY = false

This means the pipeline performs validation and planning without automatically provisioning infrastructure.

## Production Approval

When:

ENVIRONMENT = prod
APPLY = true

Jenkins pauses for explicit approval before Terraform Apply.

## Terraform Variables

The pipeline passes:

- environment
- bucket_name

to Terraform.

The S3 bucket name must be globally unique.

## Security

AWS credentials should be provided through Jenkins credentials or an appropriate IAM role.

Credentials must not be:

- Hard-coded in the Jenkinsfile
- Stored in Git
- Stored in Terraform variables committed to the repository
- Printed in pipeline logs

## Validation

The pipeline performs:

terraform -chdir=terraform fmt -check
terraform -chdir=terraform init -input=false
terraform -chdir=terraform validate
terraform -chdir=terraform plan

## Deployment

Terraform Apply runs only when:

APPLY = true

For production, an additional manual approval is required.

## Failure Handling

If a pipeline stage fails:

- Jenkins marks the build as failed.
- The failure is visible in Jenkins console logs.
- Terraform changes are not automatically retried.
- The failed stage can be investigated and corrected before another deployment.

## Rollback Approach

Infrastructure changes should be rolled back through version-controlled Terraform changes.

Rollback workflow:

Identify problematic commit
        |
        v
Revert or fix Terraform configuration
        |
        v
Terraform fmt
        |
        v
Terraform validate
        |
        v
Terraform plan
        |
        v
Review
        |
        v
Approved Terraform apply

## Auditability

Git provides version history for:

- Terraform configuration
- Jenkins pipeline
- Architecture documentation
- SQL
- PySpark code

Jenkins provides build and deployment history.

Terraform plan output provides visibility into infrastructure changes before deployment.
