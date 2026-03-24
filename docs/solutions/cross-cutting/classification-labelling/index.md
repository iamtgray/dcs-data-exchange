# Cross-cutting: data classification and labelling

Nothing in DCS works without labels. Access control (Level 2) needs labels to decide who sees what. Encryption (Level 3) needs labels to decide who gets keys. If the labels are wrong or missing, the rest of the stack is theatre.

Every scenario in this project hits the classification problem, whether it's a greenfield coalition system or a 20-year-old COBOL application. This section treats classification as a cross-cutting concern rather than tying it to any one system.

## Why this is cross-cutting

The classification challenge shows up everywhere, but the shape of the problem changes:

| Scenario | Classification challenge |
|---|---|
| New system (greenfield) | Define classification rules at design time, enforce at data entry |
| Legacy retrofit | Retroactively classify existing unlabeled data |
| Coalition sharing | Reconcile different national classification schemes |
| Tactical/edge | Classify data with limited compute and no connectivity |
| Cross-domain transfer | Validate and potentially re-classify data crossing security boundaries |

The questions are always the same: what sensitivity level does this data have, what caveats apply, and how confident are we?

## Classification dimensions

A classification decision has several moving parts:

- Sensitivity level -- the NATO classification (NU, NR, NC, NS, CTS) or national equivalent
- Caveats and releasability -- REL TO, NOFORN, Eyes Only, national caveats
- Special access programs -- compartmented access beyond clearance level
- Temporal sensitivity -- how classification changes over time (declassification schedules)
- Aggregation sensitivity -- data that becomes more sensitive in combination than individually

## Granularity

Classification can happen at different levels. Each has trade-offs:

| Granularity | Accuracy | Complexity | Use case |
|---|---|---|---|
| System/database level | Low | Minimal | Coarse isolation between enclaves |
| Table/collection level | Low-Medium | Low | Default classification for data categories |
| Row/document level | Medium | Medium | Per-record access control |
| Field/attribute level | High | High | Granular redaction and filtering |
| Derived/composite | Highest | Highest | Context-dependent classification |

Most real systems need a mix: field-level as ground truth, row-level effective classification derived from the fields, and table-level defaults as a baseline.

## Integration approaches

However the classification engine determines labels, it needs to integrate with the data it's classifying.

### Why not inline classification?

The obvious question: why not classify data in real-time as users request it, using an inline proxy?

In practice, this doesn't work for defence and operational systems. If you put a classification engine in the critical path of a logistics or C2 system and it goes down, the system goes down. Even if it stays up, it adds latency to every request. And if it can't classify a record, you're stuck choosing between blocking access (operationally disruptive) and allowing unfiltered access (security failure). Neither option is acceptable.

The realistic approach is always batch-based: classify data independently of user requests, store the labels, and use them for enforcement at query time. The question is whether you classify only in batch, or also classify new data as it's written.

### The two viable patterns

- [Option 1: Batch classification pipeline](option-1-batch-pipeline.md) -- classify data offline in bulk, store labels for later enforcement. All data (existing and new) is classified by the pipeline on a schedule or via change detection.
- [Option 2: Hybrid batch + classify-on-write](option-2-hybrid.md) -- batch for existing data, classify-on-write for new data entering the system. New records get a provisional label immediately using fast rules; the batch pipeline handles re-classification and the hard cases.

## Classification methods

Separate from the integration pattern, the actual classification logic can use different methods:

| Method | Strengths | Weaknesses | Best for |
|---|---|---|---|
| Schema-based rules | Fast, deterministic, auditable | Brittle, can't handle free text | Structured data with known schemas |
| Pattern matching | Catches known sensitive patterns | High false positive rate, maintenance burden | Grid refs, unit designators, stock numbers |
| Context/combination rules | Handles aggregation sensitivity | Complex to author, hard to maintain | Derived classifications |
| ML/NLP models | Handles free text, learns patterns | Needs training data, black box | Free-text fields, remarks, descriptions |
| LLM-assisted | Understands context and jargon | Hallucination risk, data sovereignty | Ambiguous cases, military terminology |
| Human review | Most accurate | Doesn't scale | Validation layer, edge cases |

In practice you layer these: schema rules as the base, pattern matching for known indicators, ML/LLM for ambiguous content, human review for validation.

## Related documents

- [Context: JLTS classification engine](../../03-legacy-retrofit/context-classification-engine.md) -- the classification problem applied to a specific legacy COBOL/DB2 system
- [Offline key management options](../offline-key-management-options.md) -- how classification interacts with encryption in disconnected environments
