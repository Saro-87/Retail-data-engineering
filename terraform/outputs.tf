output "data_lake_bucket_name" {
  description = "S3 data lake bucket name"
  value       = aws_s3_bucket.data_lake.bucket
}

output "data_lake_bucket_arn" {
  description = "S3 data lake bucket ARN"
  value       = aws_s3_bucket.data_lake.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt the data lake"
  value       = aws_kms_key.data_lake.arn
}

output "glue_role_arn" {
  description = "IAM role ARN used by AWS Glue"
  value       = aws_iam_role.glue_role.arn
}

output "glue_job_name" {
  description = "AWS Glue ETL job name"
  value       = aws_glue_job.retail_transaction_etl.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for the Glue ETL job"
  value       = aws_cloudwatch_log_group.glue_etl.name
}

output "glue_failure_alarm_name" {
  description = "CloudWatch alarm for Glue job failures"
  value       = aws_cloudwatch_metric_alarm.glue_job_failure.alarm_name
}