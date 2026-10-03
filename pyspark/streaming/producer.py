"""
Local streaming event producer for the Retail Data Engineering assessment.

Generates newline-delimited JSON transaction events that simulate
events arriving from Amazon Kinesis.
"""

import json
import time
from datetime import datetime, timezone
from pathlib import Path


OUTPUT_DIR = Path("data/streaming")
EVENT_FILE = OUTPUT_DIR / "transactions.jsonl"

EVENTS = [
    {
        "transaction_id": "TXN2001",
        "customer_id": "CUST001",
        "region_id": "IN-S",
        "quantity": 2,
        "amount": 1250.50,
        "event_time": "2026-10-03T10:00:00Z",
    },
    {
        "transaction_id": "TXN2002",
        "customer_id": "CUST002",
        "region_id": "IN-W",
        "quantity": 1,
        "amount": 850.00,
        "event_time": "2026-10-03T10:01:00Z",
    },
    {
        "transaction_id": "TXN2003",
        "customer_id": "CUST003",
        "region_id": "IN-S",
        "quantity": 3,
        "amount": 2100.75,
        "event_time": "2026-10-03T10:02:00Z",
    },

    # Duplicate event - should be detected by processor.
    {
        "transaction_id": "TXN2003",
        "customer_id": "CUST003",
        "region_id": "IN-S",
        "quantity": 3,
        "amount": 2100.75,
        "event_time": "2026-10-03T10:02:00Z",
    },

    {
        "transaction_id": "TXN2004",
        "customer_id": "CUST004",
        "region_id": "IN-E",
        "quantity": 4,
        "amount": 3200.00,
        "event_time": "2026-10-03T10:03:00Z",
    },

    # Invalid event - missing customer_id.
    {
        "transaction_id": "TXN2005",
        "customer_id": None,
        "region_id": "IN-N",
        "quantity": 1,
        "amount": 500.00,
        "event_time": "2026-10-03T10:04:00Z",
    },

    {
        "transaction_id": "TXN2006",
        "customer_id": "CUST006",
        "region_id": "IN-N",
        "quantity": 2,
        "amount": 1500.00,
        "event_time": "2026-10-03T10:05:00Z",
    },
]


def validate_event(event):
    """Basic producer-side validation."""
    required_fields = [
        "transaction_id",
        "customer_id",
        "region_id",
        "quantity",
        "amount",
        "event_time",
    ]

    return all(
        field in event and event[field] not in (None, "")
        for field in required_fields
    )


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with EVENT_FILE.open("w", encoding="utf-8") as file:
        for event in EVENTS:
            event["ingested_at"] = datetime.now(timezone.utc).isoformat()

            file.write(json.dumps(event) + "\n")
            file.flush()

            print(
                f"PRODUCED | "
                f"{event['transaction_id']} | "
                f"{event['region_id']} | "
                f"{event['amount']}"
            )

            time.sleep(0.2)

    valid_count = sum(validate_event(event) for event in EVENTS)

    print()
    print("========================================")
    print("STREAM PRODUCER SUMMARY")
    print("========================================")
    print(f"Total events generated : {len(EVENTS)}")
    print(f"Valid events           : {valid_count}")
    print(f"Invalid events         : {len(EVENTS) - valid_count}")
    print(f"Output file            : {EVENT_FILE}")
    print("========================================")


if __name__ == "__main__":
    main()