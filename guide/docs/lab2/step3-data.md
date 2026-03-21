# Step 3: Store Labeled Data

We need a data store where each item has both a payload and DCS labels. DynamoDB is a good fit because each item can have arbitrary attributes that serve as our labels.

## Create the DynamoDB table

1. Go to **DynamoDB Console**: [https://console.aws.amazon.com/dynamodb](https://console.aws.amazon.com/dynamodb)
2. Click **Create table**
3. **Table name**: `dcs-level2-data`
4. **Partition key**: `dataId` (String)
5. **Table settings**: Default settings (on-demand capacity)
6. Click **Create table**

## Add test data items

Go to **Explore items** for your new table, then click **Create item**. Switch to **JSON view** and add these three items:

### Item 1: Coalition intelligence report

```json
{
  "dataId": {"S": "intel-report-001"},
  "classification": {"S": "SECRET"},
  "classificationLevel": {"N": "2"},
  "releasableTo": {"SS": ["GBR", "USA", "POL"]},
  "requiredSap": {"S": ""},
  "originator": {"S": "POL"},
  "created": {"S": "2025-03-15T10:30:00Z"},
  "payload": {"S": "Enemy forces observed moving through northern sector. Estimated 200 personnel with armoured vehicles. Movement pattern suggests preparation for offensive operations."}
}
```

### Item 2: WALL SAP report

```json
{
  "dataId": {"S": "wall-report-003"},
  "classification": {"S": "SECRET"},
  "classificationLevel": {"N": "2"},
  "releasableTo": {"SS": ["GBR", "USA", "POL"]},
  "requiredSap": {"S": "WALL"},
  "originator": {"S": "GBR"},
  "created": {"S": "2025-03-16T08:15:00Z"},
  "payload": {"S": "UK enriched intelligence: HUMINT sources confirm enemy command restructuring in northern sector. New command post identified."}
}
```

### Item 3: UK-eyes-only report

```json
{
  "dataId": {"S": "uk-eyes-only-002"},
  "classification": {"S": "SECRET"},
  "classificationLevel": {"N": "2"},
  "releasableTo": {"SS": ["GBR"]},
  "requiredSap": {"S": ""},
  "originator": {"S": "GBR"},
  "created": {"S": "2025-03-16T14:00:00Z"},
  "payload": {"S": "UK-only assessment of partner nation capabilities and intelligence sharing effectiveness."}
}
```

### Item 4: Unclassified logistics

```json
{
  "dataId": {"S": "logistics-004"},
  "classification": {"S": "UNCLASSIFIED"},
  "classificationLevel": {"N": "0"},
  "releasableTo": {"SS": ["ALL"]},
  "requiredSap": {"S": ""},
  "originator": {"S": "USA"},
  "created": {"S": "2025-03-17T09:00:00Z"},
  "payload": {"S": "Standard logistics summary. Supply levels normal across all locations."}
}
```

## Understand the label structure

Each DynamoDB item has two kinds of attributes:

**Label attributes** (DCS metadata):

- `classification` / `classificationLevel` - How sensitive the data is
- `releasableTo` - Which nationalities can access it (string set)
- `requiredSap` - Special Access Program required (empty string = none)
- `originator` - Which nation created the data

**Content attributes**:

- `dataId` - Unique identifier
- `created` - Timestamp
- `payload` - The actual data content

In a real system, labels might be stored separately or in a standard format. Here we keep them alongside the data for simplicity.

## Expected access matrix

Based on our Cedar policies and these data items:

| Data Item | UK (SECRET, GBR, WALL) | Poland (NS, POL, no SAPs) | US (IL-6, USA, WALL) |
|-----------|:---:|:---:|:---:|
| intel-report-001 | ALLOW | ALLOW | ALLOW |
| wall-report-003 | ALLOW | DENY (no WALL) | ALLOW |
| uk-eyes-only-002 | ALLOW | ALLOW (originator rule - POL is not GBR, but...) | DENY (nationality) |
| logistics-004 | ALLOW | ALLOW | ALLOW |

!!! note "Tricky case: uk-eyes-only-002"
    The Polish user can't pass the standard access policy (POL not in releasableTo [GBR]). But the originator policy doesn't help either (originator is GBR, user is POL). So Poland is **DENIED**. The US is also **DENIED** for the same reason. Only UK users can access this item.

Next: **[Step 4: Build the Data Service](step4-service.md)**
