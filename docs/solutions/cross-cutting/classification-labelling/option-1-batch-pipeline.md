# Option 1: batch classification pipeline

## Concept

Classify data offline in bulk, storing labels in a separate label store. The classification engine runs as a scheduled or triggered pipeline, processing records independently of user requests. At query time, the system looks up pre-computed labels rather than classifying on the fly.

```
Data Store → [Batch Pipeline] → Label Store
                                      ↑
User → [Auth] → Query Engine ─────────┘
```

## How it works

1. A batch pipeline reads records from the data store (all records, or only records changed since the last run)
2. The classification engine processes each record through whatever methods are configured (rules, patterns, ML, LLM, etc.)
3. Generated labels are written to a label store -- a separate database or table that maps record IDs to labels
4. At query time, the application joins data with labels from the label store
5. If access control is being enforced (DCS Level 2), the pre-computed labels are used to filter responses

For new or changed data:

1. Change data capture (CDC) or a trigger detects new or modified records
2. New records are queued for classification
3. The pipeline processes the queue (near-real-time or on a schedule)
4. Labels are written to the label store

## What works well

Classification happens offline, so reads are just label lookups with no added latency. Because nothing is time-constrained, you can use expensive methods: LLM-assisted classification, multi-pass analysis, human-in-the-loop review. The pipeline can chew through millions of existing records at its own pace. Each batch run produces a classification report (what was classified, what changed, confidence scores), which gives you an audit trail for free. Failed classifications can be retried or queued for human review without blocking anyone.

Pipeline compute also scales independently of query load, which matters when you're processing a backlog of 15 million archived records.

## What doesn't

Labels are only as current as the last pipeline run. Data that changes between runs has stale labels. More importantly, new data entering the system has no labels at all until the pipeline gets to it. What happens during that gap is the hardest design question.

You also need pipeline infrastructure: orchestration, scheduling, monitoring, a separate label store. And if the pipeline fails or falls behind, data and labels drift out of sync.

## The gap problem

The gap between data entry and label availability is the biggest issue with pure batch classification:

| Gap handling strategy | Behaviour | Risk |
|---|---|---|
| Block access until classified | Secure but operationally disruptive | Users can't see new data |
| Default to highest classification | Secure but over-restrictive | Users with lower clearance see nothing new |
| Default to lowest classification | Operationally smooth but insecure | Sensitive data exposed until classified |
| Show with "unclassified" warning | Transparent but relies on user discipline | Users may ignore warnings |
| Classify synchronously on first access | Secure and available but adds latency for new data | Inconsistent user experience |

There's no clean answer. The right choice depends on the operational context and how much risk you're willing to accept. For most NATO systems, defaulting to the highest classification (over-restrict rather than under-restrict) is the safest option, even though it frustrates users.

## Pipeline architecture

### Full scan

```
Schedule (nightly) → Read all records → Classify → Write all labels
```

Simple but expensive. Reclassifies everything every run. Works for small datasets or when classification rules change frequently enough that you want to re-evaluate everything.

### Incremental (CDC-based)

```
CDC stream → Queue (SQS/Kinesis) → Classify changed records → Update labels
```

Only processes new and changed records. Much more efficient, but requires change data capture from the source system. For legacy systems, CDC might mean polling for changes or reading database transaction logs.

### Tiered

```
Tier 1: Rule-based classification (runs every 15 minutes, fast)
Tier 2: ML classification (runs hourly, moderate)  
Tier 3: LLM classification (runs daily, expensive)
Tier 4: Human review queue (continuous, for flagged records)
```

Different classification methods run at different frequencies. Rules handle the easy cases quickly. ML and LLM take on the harder cases with more time. Humans deal with the edge cases. This is probably the most practical architecture for a real deployment.

## Label store design

The label store maps records to their classifications:

```
┌─────────────────────────────────────────────────────┐
│ Label Store                                         │
├──────────┬──────────┬───────────┬──────┬────────────┤
│ table_id │ row_id   │ field_id  │ label│ confidence │
├──────────┼──────────┼───────────┼──────┼────────────┤
│ UNIT_MVT │ 00012345 │ DEST_UNT  │ NS   │ 0.95       │
│ UNIT_MVT │ 00012345 │ ITEM_DESC │ NU   │ 0.99       │
│ UNIT_MVT │ 00012345 │ _ROW_     │ NS   │ 0.95       │
│ SUPPLY   │ 00098765 │ GRID_REF  │ NS   │ 0.98       │
└──────────┴──────────┴───────────┴──────┴────────────┘
```

Design decisions worth thinking about:

- Field-level vs row-level: store labels per field for granular filtering, or per row for simplicity?
- Confidence scores: storing the engine's confidence lets you trigger human review for low-confidence labels downstream
- Versioning: tracking label history matters for audit (what was the label before the last pipeline run?)
- Caveats: releasability and SAP requirements need to live alongside the sensitivity level

## When this fits

- Legacy systems with large volumes of unclassified data that need retroactive classification
- Systems where classification requires expensive methods (LLM, human review)
- Environments where query latency can't tolerate any classification overhead
- Systems where data changes infrequently relative to read volume

## When it doesn't

- Systems where data changes rapidly and stale labels are unacceptable
- Environments where the gap between data entry and classification is a security risk you can't accept
- Systems without a reliable change data capture mechanism (full scans get expensive fast)

## AWS implementation sketch

- Step Functions or MWAA (Airflow) for pipeline orchestration
- Lambda or ECS/Fargate for classification compute
- SQS or Kinesis for CDC event streaming
- DynamoDB or Aurora for the label store
- SageMaker for ML model inference
- Bedrock for LLM-assisted classification (within the security boundary)
- CloudWatch + SNS for pipeline monitoring and alerting
- S3 for classification audit logs and reports
