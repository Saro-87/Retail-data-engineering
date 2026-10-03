"""
Local streaming processor for the Retail Data Engineering assessment.

Simulates the processing layer that would consume events from
Amazon Kinesis / Kafka and process them using Spark Structured Streaming.

The local implementation demonstrates:
- Schema validation
- Duplicate detection
- Event-time handling
- Invalid-event quarantine / DLQ
- Checkpoint concept
- Region-level aggregation
"""

import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path


INPUT_FILE = Path("data/streaming/transactions.jsonl")
OUTPUT_DIR = Path("data/streaming/output")
PROCESSED_FILE = OUTPUT_DIR / "processed.jsonl"
DLQ_FILE = OUTPUT_DIR / "dlq.jsonl"
CHECKPOINT_FILE = OUTPUT_DIR / "checkpoint.json"


REQUIRED_FIELDS = {
    "transaction_id",
    "customer_id",
    "region_id",
    "quantity",
    "amount",
    "event_time",
}


def parse_event_time(value):
    """Convert ISO-8601 event time into a datetime."""
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def validate_event(event):
    """Validate required fields and basic data quality."""
    missing = [
        field
        for field in REQUIRED_FIELDS
        if field not in event or event[field] in (None, "")
    ]

    if missing:
        return False, f"Missing required fields: {', '.join(sorted(missing))}"

    try:
        if int(event["quantity"]) <= 0:
            return False, "Quantity must be greater than zero"

        if float(event["amount"]) < 0:
            return False, "Amount cannot be negative"

        parse_event_time(event["event_time"])

    except (ValueError, TypeError):
        return False, "Invalid quantity, amount or event_time"

    return True, None


def load_events():
    """Read newline-delimited JSON events."""
    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Input file not found: {INPUT_FILE}. "
            "Run producer.py first."
        )

    events = []

    with INPUT_FILE.open("r", encoding="utf-8") as file:
        for line in file:
            line = line.strip()

            if line:
                events.append(json.loads(line))

    return events


def write_jsonl(path, records):
    """Write records as newline-delimited JSON."""
    with path.open("w", encoding="utf-8") as file:
        for record in records:
            file.write(json.dumps(record, default=str) + "\n")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    events = load_events()

    processed = []
    dlq = []
    seen_transaction_ids = set()

    region_summary = defaultdict(
        lambda: {
            "transaction_count": 0,
            "total_quantity": 0,
            "total_sales": 0.0,
        }
    )

    duplicate_count = 0

    for event in events:

        # ---------------------------------------------------------
        # 1. Data quality validation
        # ---------------------------------------------------------
        valid, reason = validate_event(event)

        if not valid:
            event["rejection_reason"] = reason
            dlq.append(event)
            continue

        transaction_id = event["transaction_id"]

        # ---------------------------------------------------------
        # 2. Deduplication
        # ---------------------------------------------------------
        if transaction_id in seen_transaction_ids:
            duplicate_count += 1

            duplicate_event = dict(event)
            duplicate_event["rejection_reason"] = (
                "Duplicate transaction_id"
            )

            dlq.append(duplicate_event)
            continue

        seen_transaction_ids.add(transaction_id)

        # ---------------------------------------------------------
        # 3. Event-time processing
        # ---------------------------------------------------------
        event_time = parse_event_time(event["event_time"])

        processed_event = {
            "transaction_id": transaction_id,
            "customer_id": event["customer_id"],
            "region_id": event["region_id"],
            "quantity": int(event["quantity"]),
            "amount": float(event["amount"]),
            "event_time": event_time.isoformat(),
        }

        processed.append(processed_event)

        # ---------------------------------------------------------
        # 4. Aggregation
        # ---------------------------------------------------------
        region = event["region_id"]

        region_summary[region]["transaction_count"] += 1
        region_summary[region]["total_quantity"] += int(
            event["quantity"]
        )
        region_summary[region]["total_sales"] += float(
            event["amount"]
        )

    # -------------------------------------------------------------
    # Write processed stream
    # -------------------------------------------------------------
    write_jsonl(PROCESSED_FILE, processed)

    # -------------------------------------------------------------
    # Write DLQ
    # -------------------------------------------------------------
    write_jsonl(DLQ_FILE, dlq)

    # -------------------------------------------------------------
    # Checkpoint
    # -------------------------------------------------------------
    checkpoint = {
        "last_processed_transaction_id": (
            processed[-1]["transaction_id"]
            if processed
            else None
        ),
        "processed_count": len(processed),
    }

    CHECKPOINT_FILE.write_text(
        json.dumps(checkpoint, indent=2),
        encoding="utf-8",
    )

    # -------------------------------------------------------------
    # Console result
    # -------------------------------------------------------------
    print()
    print("========================================")
    print("STREAM PROCESSING RESULT")
    print("========================================")
    print(f"Input events             : {len(events)}")
    print(f"Processed events         : {len(processed)}")
    print(f"Rejected/DLQ events      : {len(dlq)}")
    print(f"Duplicate events         : {duplicate_count}")
    print()

    print("REGION AGGREGATION")
    print("----------------------------------------")

    for region in sorted(region_summary):
        summary = region_summary[region]

        print(
            f"{region} | "
            f"transactions={summary['transaction_count']} | "
            f"quantity={summary['total_quantity']} | "
            f"sales={summary['total_sales']:.2f}"
        )

    print()
    print("OUTPUT FILES")
    print("----------------------------------------")
    print(f"Processed : {PROCESSED_FILE}")
    print(f"DLQ       : {DLQ_FILE}")
    print(f"Checkpoint: {CHECKPOINT_FILE}")
    print("========================================")


if __name__ == "__main__":
    main()