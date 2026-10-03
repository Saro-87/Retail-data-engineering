# ============================================================
# KMS ENCRYPTION KEY
# ============================================================

resource "aws_kms_key" "data_lake" {
  description             = "KMS key for Retail Data Engineering data lake"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name = "${var.project_name}-data-lake-kms"
  }
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/${var.project_name}-${var.environment}-data-lake"
  target_key_id = aws_kms_key.data_lake.key_id
}

# ============================================================
# S3 DATA LAKE
# ============================================================

resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name

  tags = {
    Name = "${var.project_name}-data-lake"
  }
}


# ============================================================
# S3 VERSIONING
# ============================================================

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}


# ============================================================
# S3 SERVER-SIDE ENCRYPTION
# ============================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data_lake.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

# ============================================================
# S3 PUBLIC ACCESS BLOCK
# ============================================================

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# S3 LIFECYCLE MANAGEMENT
# ============================================================

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "retail-data-lifecycle"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}


# ============================================================
# S3 DATA LAKE PREFIXES
# ============================================================

resource "aws_s3_object" "raw_prefix" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/"
}

resource "aws_s3_object" "processed_prefix" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "processed/"
}

resource "aws_s3_object" "curated_prefix" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "curated/region_daily_sales/"
}

resource "aws_s3_object" "quarantine_prefix" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "quarantine/"
}


# ============================================================
# IAM ROLE FOR AWS GLUE
# ============================================================

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-${var.environment}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "glue.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-glue-role"
  }
}


# ============================================================
# AWS GLUE SERVICE ROLE
# ============================================================

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
# ============================================================
# LEAST-PRIVILEGE S3 ACCESS FOR GLUE
# ============================================================

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project_name}-${var.environment}-glue-s3-access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListDataLakeBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = aws_s3_bucket.data_lake.arn
      },

      {
        Sid    = "ReadRawData"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.data_lake.arn}/raw/*"
      },

      {
        Sid    = "ReadGlueScript"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.data_lake.arn}/scripts/retail_transaction_etl.py"
      },

      {
        Sid    = "WriteProcessedData"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.data_lake.arn}/processed/*"
      },

      {
        Sid    = "WriteCuratedData"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.data_lake.arn}/curated/*"
      },

      {
        Sid    = "WriteQuarantineData"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.data_lake.arn}/quarantine/*"
      }
    ]
  })
}
# ============================================================
# KMS ACCESS FOR AWS GLUE
# ============================================================

resource "aws_iam_role_policy" "glue_kms_access" {
  name = "${var.project_name}-${var.environment}-glue-kms-access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "UseDataLakeKmsKey"
        Effect = "Allow"

        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]

        Resource = aws_kms_key.data_lake.arn
      }
    ]
  })
}
# ============================================================
# GLUE ETL SCRIPT
# ============================================================

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/retail_transaction_etl.py"
  source = "${path.module}/../pyspark/retail_transaction_etl.py"

  source_hash = filemd5("${path.module}/../pyspark/retail_transaction_etl.py")

  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data_lake.arn
}
# ============================================================
# AWS GLUE ETL JOB
# ============================================================

resource "aws_glue_job" "retail_transaction_etl" {
  name     = var.glue_job_name
  role_arn = aws_iam_role.glue_role.arn

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.data_lake.bucket}/scripts/retail_transaction_etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--SOURCE_PATH"                      = "s3://${aws_s3_bucket.data_lake.bucket}/raw/transactions/"
    "--OUTPUT_PATH"                      = "s3://${aws_s3_bucket.data_lake.bucket}/processed/region_daily_sales/"


    "--TempDir" = "s3://${aws_s3_bucket.data_lake.bucket}/glue-temp/"

  }

  execution_property {
    max_concurrent_runs = 1
  }

  depends_on = [
    aws_s3_object.glue_script
  ]

  tags = {
    Name = "${var.project_name}-glue-etl"
  }
}
# ============================================================
# CLOUDWATCH LOG GROUP FOR GLUE
# ============================================================

resource "aws_cloudwatch_log_group" "glue_etl" {
  name              = "/aws-glue/jobs/${var.glue_job_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-glue-logs"
  }
}
# ============================================================
# CLOUDWATCH ALARM - GLUE JOB FAILURE
# ============================================================

resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  alarm_name          = "${var.project_name}-${var.environment}-glue-job-failure"
  alarm_description   = "Alarm when the retail transaction Glue ETL job fails"
  namespace           = "Glue"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    JobName = aws_glue_job.retail_transaction_etl.name
  }

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-glue-failure-alarm"
  }
}
