variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "retail-data-engineering"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "glue_job_name" {
  description = "AWS Glue ETL job name"
  type        = string
  default     = "retail-transaction-etl"
}