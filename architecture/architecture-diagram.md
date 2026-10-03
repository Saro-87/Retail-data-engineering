
# Retail Data Engineering Platform — Architecture Diagram

> **Implementation note:** This diagram represents the target/reference
> architecture for the assessment. The hands-on AWS implementation deployed
> S3, KMS, IAM, AWS Glue, CloudWatch, Athena and Terraform-managed resources.
> The Kinesis, ECS/ALB, Secrets Manager and CloudTrail components shown in this
> diagram represent the production/reference design unless explicitly stated
> otherwise in the repository documentation.

```mermaid
flowchart TB

    %% =====================================================
    %% SOURCE LAYER
    %% =====================================================

    subgraph SOURCES["Source Systems"]
        CSV["CSV / Batch Files"]
        API["Retail Applications / APIs"]
        DB["Operational Databases"]
        STREAM["Real-Time Transaction Events"]
    end

    %% =====================================================
    %% INGESTION
    %% =====================================================

    subgraph INGESTION["Ingestion Layer"]
        S3RAW["Amazon S3<br/>Raw Zone"]
        KINESIS["Amazon Kinesis<br/>Data Streams"]
    end

    CSV --> S3RAW
    DB --> S3RAW
    API --> S3RAW
    STREAM --> KINESIS

    %% =====================================================
    %% PROCESSING
    %% =====================================================

    subgraph PROCESSING["Processing Layer"]
        GLUE["AWS Glue"]
        SPARK["Apache Spark"]
        QUALITY["Data Quality<br/>Validation"]
        DEDUP["Deduplication"]
        TRANSFORM["Transformation"]
        AGG["Region + Day<br/>Aggregation"]
    end

    S3RAW --> GLUE
    KINESIS --> GLUE
    GLUE --> SPARK
    SPARK --> QUALITY
    QUALITY --> DEDUP
    DEDUP --> TRANSFORM
    TRANSFORM --> AGG

    %% =====================================================
    %% ERROR / QUARANTINE
    %% =====================================================

    subgraph ERROR["Error Handling"]
        QUARANTINE["S3 Quarantine<br/>Rejected Records"]
        RETRY["Retry / Exponential<br/>Backoff"]
        DLQ["Dead Letter / Failed<br/>Event Handling"]
    end

    QUALITY -->|Invalid Records| QUARANTINE
    KINESIS -->|Failed Events| DLQ
    GLUE -->|Transient Failure| RETRY
    RETRY --> GLUE

    %% =====================================================
    %% DATA LAKE
    %% =====================================================

    subgraph LAKE["Amazon S3 Data Lake"]
        PROCESSED["Processed Zone<br/>Parquet + Snappy"]
        CURATED["Curated Zone<br/>Region Daily Sales"]
    end

    TRANSFORM --> PROCESSED
    AGG --> CURATED

    %% =====================================================
    %% ANALYTICS
    %% =====================================================

    subgraph ANALYTICS["Analytics / Consumption"]
        ATHENA["Amazon Athena"]
        BI["BI / Reporting"]
        ML["ML / Data Science"]
    end

    CURATED --> ATHENA
    ATHENA --> BI
    CURATED --> ML

    %% =====================================================
    %% APPLICATION LAYER
    %% =====================================================

    subgraph APPLICATION["Application Layer"]
        ALB["Application Load Balancer"]
        ECS["Amazon ECS"]
        APP["Retail API / Application"]
    end

    API --> ALB
    ALB --> ECS
    ECS --> APP

    %% =====================================================
    %% SECURITY
    %% =====================================================

    subgraph SECURITY["Security & Governance"]
        IAM["AWS IAM<br/>Least Privilege"]
        KMS["AWS KMS<br/>Encryption"]
        SECRETS["AWS Secrets Manager"]
        CLOUDTRAIL["AWS CloudTrail<br/>Audit"]
    end

    IAM -.-> S3RAW
    IAM -.-> GLUE
    IAM -.-> KINESIS
    IAM -.-> ECS

    KMS -.-> S3RAW
    KMS -.-> PROCESSED
    KMS -.-> CURATED

    SECRETS -.-> ECS
    SECRETS -.-> GLUE

    CLOUDTRAIL -.-> IAM
    CLOUDTRAIL -.-> S3RAW
    CLOUDTRAIL -.-> GLUE

    %% =====================================================
    %% MONITORING
    %% =====================================================

    subgraph MONITORING["Monitoring & Operations"]
        CW["Amazon CloudWatch"]
        ALARMS["CloudWatch Alarms"]
        LOGS["CloudWatch Logs"]
        CHECKPOINT["Spark Checkpoints"]
        BOOKMARK["Glue Job Bookmarks"]
    end

    GLUE -.-> LOGS
    ECS -.-> LOGS
    KINESIS -.-> LOGS

    LOGS --> CW
    CW --> ALARMS

    SPARK -.-> CHECKPOINT
    GLUE -.-> BOOKMARK

    %% =====================================================
    %% SCALABILITY
    %% =====================================================

    subgraph SCALE["Scalability"]
        GLUESCALE["Glue Worker Scaling"]
        KINESISSCALE["Kinesis Shard / Capacity Scaling"]
        ECSSCALE["ECS Horizontal Scaling"]
        S3SCALE["S3 Elastic Storage"]
    end

    GLUESCALE -.-> GLUE
    KINESISSCALE -.-> KINESIS
    ECSSCALE -.-> ECS
    S3SCALE -.-> S3RAW
