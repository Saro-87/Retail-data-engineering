# Streaming Data Processing

## 1. Overview

This component demonstrates a retail transaction streaming pipeline.

The local implementation simulates transaction events arriving from a streaming
source such as Amazon Kinesis Data Streams or Apache Kafka.

The processing flow is:

Producer
    |
    v
Kinesis / Kafka
    |
    v
Streaming Processor
    |
    +--------------------+
    |                    |
    v                    v
Data Validation       Deduplication
    |                    |
    +---------+----------+
              |
              v
       Region Aggregation
              |
       +------+------+
       |             |
       v             v
   Processed        DLQ
       |
       v
   Checkpoint


## 2. Local Demonstration

The local demonstration contains:

- `producer.py`
- `streaming_processor.py`

The producer generates newline-delimited JSON transaction events.

The processor:

1. Reads streaming events.
2. Validates required fields.
3. Parses event time.
4. Detects duplicate transaction IDs.
5. Sends invalid and duplicate events to the DLQ.
6. Processes valid events.
7. Aggregates transactions by region.
8. Writes processed events.
9. Writes a checkpoint.

Run the producer:

```powershell
py .\pyspark\streaming\producer.py