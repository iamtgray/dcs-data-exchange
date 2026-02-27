# LLM-Based Cross-Domain Sanitisation Solution

## Solution Overview

This solution uses Large Language Models (LLMs) with Model Context Protocol (MCP) servers to provide context-aware, intelligent sanitisation for cross-domain transfers. The LLM operates on the high-side with access to project documentation, classification guides, and operational context through MCP servers, enabling it to understand what information is sensitive and make informed sanitisation decisions.

## Scenario Reference

**Addresses**: Scenario 04 - Cross-Domain Automated Sanitisation

## Solution Principles

1. **LLM on High-Side**: LLM operates in the high-classification domain with full context
2. **MCP for Context**: MCP servers provide project documentation, classification guides, and operational knowledge
3. **Reasoning-Based Sanitisation**: LLM uses reasoning to determine what's sensitive based on context
4. **Human-in-the-Loop**: LLM recommendations reviewed by human before release
5. **Audit Trail**: All LLM reasoning and decisions logged for accountability
6. **Defence in Depth**: LLM sanitisation + traditional CDS controls

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        HIGH-SIDE (TS).                          │
│                                                                 │
│  ┌──────────────┐         ┌─────────────────────────────────┐ │
│  │  Document    │────────>│   LLM Sanitisation Engine       │ │
│  │  to Transfer │         │   (GPT-4, Claude, Llama, etc.)  │ │
│  └──────────────┘         │                                 │ │
│                           │   - Content analysis            │ │
│                           │   - Classification reasoning    │ │
│                           │   - Redaction recommendations   │ │
│                           └─────────┬───────────────────────┘ │
│                                     │                          │
│                                     │ MCP Protocol             │
│                                     │                          │
│                    ┌────────────────┴────────────────┐        │
│                    │                                  │        │
│         ┌──────────▼──────────┐         ┌───────────▼────────┐│
│         │  MCP Server:        │         │  MCP Server:       ││
│         │  Project Context    │         │  Classification    ││
│         │                     │         │  Guides            ││
│         │  - Project docs     │         │                    ││
│         │  - Codewords        │         │  - Classification  ││
│         │  - Capabilities     │         │    rules           ││
│         │  - Operations       │         │  - Downgrade       ││
│         │  - Personnel        │         │    procedures      ││
│         └─────────────────────┘         │  - Releasability   ││
│                                         └────────────────────┘│
│                                                                 │
│         ┌─────────────────────────────────────────────┐       │
│         │  MCP Server: Historical Sanitisations       │       │
│         │                                              │       │
│         │  - Previous sanitisation decisions          │       │
│         │  - Reviewer feedback                         │       │
│         │  - Common patterns                           │       │
│         └──────────────────────────────────────────────┘      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │           Human Review Interface                         │ │
│  │                                                          │ │
│  │  - Original document (TS)                               │ │
│  │  - LLM-sanitised version (proposed SECRET)             │ │
│  │  - LLM reasoning explanation                            │ │
│  │  - Approve / Modify / Reject                            │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                     │                          │
└─────────────────────────────────────┼──────────────────────────┘
                                      │
                                      │ Approved Sanitised Doc
                                      │
┌─────────────────────────────────────▼──────────────────────────┐
│                    CROSS-DOMAIN SOLUTION                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Traditional CDS Controls                                │ │
│  │  - Format validation                                     │ │
│  │  - Malware scanning                                      │ │
│  │  - Dirty word check (backup)                             │ │
│  │  - Metadata stripping                                    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                     │                          │
└─────────────────────────────────────┼──────────────────────────┘
                                      │
                                      │ Sanitised Document
                                      │
┌─────────────────────────────────────▼──────────────────────────┐
│                        LOW-SIDE (SECRET)                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Sanitised Document + Metadata                           │ │
│  │  - Classification: SECRET                                │ │
│  │  - Derived from: [TS document ID]                        │ │
│  │  - Sanitisation date: [timestamp]                        │ │
│  │  - Reviewer: [name]                                      │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. LLM Sanitisation Engine (High-Side)

**Purpose**: Analyse documents and generate sanitised versions using context-aware reasoning

**Capabilities**:
- Natural language understanding of document content
- Context-aware classification determination
- Reasoning about what information is sensitive
- Generation of sanitised versions with explanations
- Learning from reviewer feedback

**LLM Selection Criteria**:
- **On-Premise Deployment**: Must run on high-side infrastructure (no cloud APIs)
- **Context Window**: Large enough for full documents + MCP context (100k+ tokens)
- **Reasoning Capability**: Strong reasoning for classification decisions
- **Fine-Tuning**: Ability to fine-tune on classification examples

**Candidate LLMs**:
- **GPT-4** (cloud or on-premise deployment)
- **Claude 4.5 Opus** (cloud or on-premise)
- **Llama 3 70B+** (fully on-premise, open weights)
- **Mistral Large** (on-premise deployment)

**Prompt Structure**:
```
You are a classification expert helping sanitise a TOP SECRET document 
for release at SECRET level.

CONTEXT (from MCP servers):
- Project: OPERATION WALL
- Codewords: WALL, GRIFFIN
- Sensitive capabilities: [list from MCP]
- Classification guide: [rules from MCP]
- Previous sanitisations: [examples from MCP]

DOCUMENT TO SANITISE:
[Original TS document]

TASK:
1. Identify all sensitive elements that must be removed or generalised
2. Explain WHY each element is sensitive (reference classification guide)
3. Propose sanitised version suitable for SECRET release
4. Maintain operational value whilst protecting sources/methods

OUTPUT FORMAT:
{
  "sensitive_elements": [
    {
      "text": "SIGINT platform BLACKBIRD",
      "reason": "Reveals collection capability (Classification Guide 3.2.1)",
      "action": "replace",
      "replacement": "intelligence sources"
    },
    ...
  ],
  "sanitised_document": "[full sanitised text]",
  "classification_reasoning": "[explanation of final classification]",
  "confidence": "high|medium|low"
}
```

### 2. MCP Server: Project Context

**Purpose**: Provide LLM with operational context about high-side projects

**Data Sources**:
- Project documentation repositories
- Operational plans and orders
- Personnel rosters (who's involved)
- Capability descriptions
- Codeword definitions
- Ongoing operations

**MCP Tools Exposed**:
```typescript
{
  "get_project_info": {
    "description": "Get information about a specific project/operation",
    "parameters": {
      "project_name": "string",
      "info_type": "codewords|capabilities|personnel|operations"
    }
  },
  "search_capabilities": {
    "description": "Search for sensitive capabilities mentioned in text",
    "parameters": {
      "text": "string"
    }
  },
  "check_codeword": {
    "description": "Check if a codeword is sensitive and its classification",
    "parameters": {
      "codeword": "string"
    }
  }
}
```

**Example MCP Response**:
```json
{
  "project": "OPERATION WALL",
  "classification": "TS/SCI",
  "codewords": ["WALL", "GRIFFIN"],
  "sensitive_capabilities": [
    "SIGINT platform BLACKBIRD",
    "Satellite constellation KEYHOLE",
    "HUMINT network NIGHTINGALE"
  ],
  "releasability": "UK, US only",
  "downgrade_to_secret": {
    "allowed": true,
    "restrictions": "Remove all source/method details"
  }
}
```

### 3. MCP Server: Classification Guides

**Purpose**: Provide LLM with authoritative classification rules

**Data Sources**:
- National classification guides
- NATO classification standards
- Organisational classification policies
- Downgrade procedures
- Declassification schedules

**MCP Tools Exposed**:
```typescript
{
  "get_classification_rule": {
    "description": "Get classification rule for specific information type",
    "parameters": {
      "info_type": "location|capability|source|method|personnel"
    }
  },
  "check_downgrade_allowed": {
    "description": "Check if information can be downgraded to lower classification",
    "parameters": {
      "current_classification": "string",
      "target_classification": "string",
      "info_type": "string"
    }
  },
  "get_sanitisation_rules": {
    "description": "Get rules for sanitising specific information types",
    "parameters": {
      "info_type": "string"
    }
  }
}
```

**Example MCP Response**:
```json
{
  "rule_id": "CG-3.2.1",
  "info_type": "SIGINT collection capability",
  "classification": "TS/SCI",
  "downgrade_to_secret": {
    "allowed": true,
    "method": "generalise",
    "example": "SIGINT platform BLACKBIRD → intelligence sources"
  },
  "rationale": "Specific platform names reveal collection capabilities"
}
```

### 4. MCP Server: Historical Sanitisations

**Purpose**: Provide LLM with examples of previous sanitisation decisions

**Data Sources**:
- Previous sanitisation operations
- Reviewer feedback and corrections
- Common patterns and edge cases
- Successful and failed sanitisations

**MCP Tools Exposed**:
```typescript
{
  "get_similar_sanitisations": {
    "description": "Find similar previous sanitisation decisions",
    "parameters": {
      "text": "string",
      "similarity_threshold": "number"
    }
  },
  "get_reviewer_feedback": {
    "description": "Get feedback on previous LLM sanitisation decisions",
    "parameters": {
      "time_range": "string"
    }
  },
  "get_common_patterns": {
    "description": "Get common sanitisation patterns for specific info types",
    "parameters": {
      "info_type": "string"
    }
  }
}
```

**Example MCP Response**:
```json
{
  "similar_cases": [
    {
      "original": "SIGINT intercept from platform RAVEN",
      "sanitised": "intelligence sources indicate",
      "reviewer_feedback": "Approved - good generalisation",
      "date": "2026-01-10"
    },
    {
      "original": "HUMINT source NIGHTINGALE reports",
      "sanitised": "human intelligence sources report",
      "reviewer_feedback": "Approved",
      "date": "2026-01-08"
    }
  ],
  "pattern": "Replace specific source names with generic 'intelligence sources'"
}
```

### 5. Human Review Interface

**Purpose**: Enable human reviewers to verify and approve LLM sanitisation decisions

**Features**:
- Side-by-side comparison (original TS vs proposed SECRET)
- Highlighted changes with explanations
- LLM reasoning display
- Edit capability (modify LLM suggestions)
- Approve/Reject workflow
- Feedback mechanism (improve LLM over time)

**Interface Layout**:
```
┌─────────────────────────────────────────────────────────────────┐
│  Document Sanitisation Review                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Original (TS/SCI)              │  Sanitised (SECRET - Proposed)│
│  ─────────────────              │  ───────────────────────────  │
│                                 │                               │
│  Enemy forces observed          │  Enemy forces observed        │
│  moving through                 │  moving through               │
│  [GRID 12345678]                │  [NORTHERN SECTOR]            │
│  ▲ Specific location (TS)       │  ▲ Generalised location       │
│                                 │                               │
│  Movement detected by           │  Movement detected by         │
│  [SIGINT platform BLACKBIRD]    │  [intelligence sources]       │
│  ▲ Source/method (TS/SCI)       │  ▲ Generalised source         │
│                                 │                               │
├─────────────────────────────────────────────────────────────────┤
│  LLM Reasoning:                                                 │
│  - GRID 12345678: Specific location reveals operational area   │
│    (Classification Guide 2.1.3). Replaced with general area.   │
│  - SIGINT platform BLACKBIRD: Reveals collection capability    │
│    (Classification Guide 3.2.1). Replaced with generic source. │
│                                                                 │
│  Confidence: HIGH                                               │
│  Recommended Classification: SECRET                             │
├─────────────────────────────────────────────────────────────────┤
│  [Approve]  [Modify]  [Reject]  [Request Re-sanitisation]      │
└─────────────────────────────────────────────────────────────────┘
```

### 6. Traditional CDS (Defence in Depth)

**Purpose**: Provide backup controls even after LLM sanitisation

**Controls**:
- **Format Validation**: Ensure sanitised document is valid format
- **Malware Scanning**: Scan for malicious content
- **Dirty Word Check**: Backup keyword blocking for known sensitive terms
- **Metadata Stripping**: Remove hidden metadata
- **Audit Logging**: Log all transfers

**Rationale**: LLM may miss something; traditional CDS provides safety net

## Workflow

### Sanitisation Request Flow

```
1. User submits TS document for sanitisation to SECRET
   ↓
2. LLM Sanitisation Engine receives document
   ↓
3. LLM queries MCP servers for context:
   - Project context (what operation is this?)
   - Classification rules (what's sensitive?)
   - Historical examples (how have we done this before?)
   ↓
4. LLM analyses document:
   - Identifies sensitive elements
   - Determines classification reasoning
   - Generates sanitised version
   - Provides confidence score
   ↓
5. Human reviewer sees:
   - Original (TS) and sanitised (SECRET) side-by-side
   - LLM reasoning for each change
   - Confidence score
   ↓
6. Reviewer decision:
   - APPROVE → Continue to CDS
   - MODIFY → Edit sanitisation, then approve
   - REJECT → Return to LLM with feedback
   ↓
7. Approved document passes through traditional CDS:
   - Format validation
   - Malware scan
   - Dirty word check
   - Metadata stripping
   ↓
8. Sanitised document released to LOW-SIDE (SECRET)
   ↓
9. Audit trail created:
   - Original document ID
   - Sanitised document ID
   - LLM reasoning
   - Reviewer decision
   - Timestamp
```

### Feedback Loop for LLM Improvement

```
1. Reviewer provides feedback on LLM sanitisation:
   - "Too aggressive" (removed too much)
   - "Not aggressive enough" (left sensitive info)
   - "Correct" (approved as-is)
   ↓
2. Feedback stored in Historical Sanitisations MCP server
   ↓
3. LLM learns from feedback:
   - Fine-tuning on approved examples
   - Adjusting confidence thresholds
   - Improving reasoning patterns
   ↓
4. Future sanitisations benefit from past decisions
```

## Security Considerations

### LLM Security

**Threat**: LLM could be manipulated to leak sensitive information

**Mitigations**:
- LLM operates entirely on high-side (no external API calls)
- LLM output reviewed by human before release
- Traditional CDS provides backup controls
- Audit trail of all LLM decisions
- Regular security testing of LLM prompts

### MCP Server Security

**Threat**: Compromised MCP server could provide false context

**Mitigations**:
- MCP servers operate on high-side infrastructure
- Access controls on MCP server data sources
- Audit logging of all MCP queries
- Integrity checks on classification guides
- Version control for all MCP server data

### Human Review Bypass

**Threat**: Reviewer could approve without proper review

**Mitigations**:
- Mandatory review time (cannot approve instantly)
- Random spot checks by senior reviewers
- Audit trail of review decisions
- Reviewer training and certification
- Consequences for improper approvals

### Prompt Injection

**Threat**: Malicious content in document could manipulate LLM

**Mitigations**:
- Structured prompts with clear role separation
- Input sanitisation before LLM processing
- Output validation (ensure proper format)
- Human review catches manipulation attempts
- Regular testing with adversarial examples

## Performance Considerations

### LLM Inference Time

**Challenge**: Large documents may take time to process

**Optimisations**:
- Batch processing for multiple documents
- Parallel processing for document sections
- Caching of MCP server responses
- GPU acceleration for inference

**Expected Performance**:
- Small documents: Under a minute
- Medium documents: A few minutes
- Large documents: Tens of minutes

### MCP Server Response Time

**Challenge**: MCP queries add latency

**Optimisations**:
- Caching of frequently accessed data
- Pre-loading of common classification rules
- Indexed search for historical sanitisations
- Parallel MCP queries where possible

**Expected Performance**:
- Context queries: Sub-second to a few seconds
- Complex searches: A few seconds

## Deployment Model

### High-Side Infrastructure

**Requirements**:
- GPU-capable servers for LLM inference
- Application servers for MCP server hosting
- Database servers for context storage
- Workstations for human review
- Secure network isolation (air-gapped or SCIF)

**Deployment Options**:
1. **On-Premise**: Fully air-gapped deployment in SCIF
2. **Government Cloud**: Azure Government or AWS GovCloud (if approved for classification level)
3. **Hybrid**: LLM on-premise, some MCP servers in gov cloud

### Scaling

**Small Deployment**: 10-20 documents/day, minimal infrastructure
**Medium Deployment**: 50-100 documents/day, redundant systems
**Large Deployment**: 200+ documents/day, load-balanced clusters

## Advantages

1. **Context-Aware**: LLM understands operational context, not just keywords
2. **Reasoning**: LLM explains WHY something is sensitive
3. **Adaptive**: LLM learns from feedback, improves over time
4. **Consistent**: Same reasoning applied across all documents
5. **Scalable**: Can process large volumes with human review
6. **Explainable**: LLM provides reasoning for audit trail

## Disadvantages

1. **LLM Errors**: LLM may miss sensitive information or over-redact
2. **Context Dependency**: Quality depends on MCP server data quality
3. **Computational Cost**: Requires significant GPU resources (expensive)
4. **Human Review Required**: Cannot fully automate (security requirement)
5. **Novel Situations**: LLM may struggle with unprecedented scenarios
6. **Adversarial Attacks**: Prompt injection or manipulation attempts
7. **Deployment Complexity**: Requires on-premise LLM infrastructure on high-side

## Acceptance Criteria Coverage

### From Scenario 04

✅ **AC1: Automated Content Analysis** - LLM identifies sensitive elements using NLP
✅ **AC2: Intelligent Redaction** - LLM maintains coherence whilst removing sensitive content
✅ **AC3: Classification Determination** - LLM determines appropriate output classification
✅ **AC4: Human Review Workflow** - Side-by-side interface with LLM reasoning
✅ **AC5: Cross-Domain Transfer** - Integrates with traditional CDS
✅ **AC6: Derivative Work Tracking** - Audit trail links originals to sanitised versions
✅ **AC7: Audit Trail** - Comprehensive logging of LLM decisions and reasoning
✅ **AC8: Rule Management** - MCP servers provide classification rules
✅ **AC9: Multi-Format Support** - LLM can handle text (images/video future enhancement)
✅ **AC10: Error Handling and Safety** - Human review + traditional CDS provide safety net
⚠️ **AC11: Performance** - Depends on LLM size and hardware (minutes per document)
✅ **AC12: Standards Compliance** - MCP servers enforce classification standards

## Technology Stack

**LLM Options**:
- Open-weight models (Llama, Mistral) for on-premise deployment
- Commercial models (GPT-4, Claude) via government cloud APIs
- Requires large context windows and strong reasoning capability

**MCP Infrastructure**:
- MCP servers (Python or TypeScript implementations)
- Document repositories (SharePoint, Confluence, or similar)
- Classification guide databases
- Historical sanitisation storage

**Traditional CDS**:
- Certified cross-domain solutions (Owl, General Dynamics, Forcepoint, or similar)
- Format validation and malware scanning
- Backup keyword filtering

**Infrastructure**:
- GPU-capable servers for LLM inference
- Application servers for MCP hosting
- Database servers for context storage
- Secure networking (air-gapped or SCIF)

## Implementation Complexity

**Complexity**: High

**Key Challenges**:
1. Security accreditation for LLM on high-side
2. MCP server data quality and completeness
3. LLM fine-tuning on classification examples
4. Integration with existing CDS infrastructure
5. Human reviewer training and workflow
6. Ongoing maintenance and model updates

**Effort Considerations**:
- Significant infrastructure investment required
- Long security accreditation process
- Custom MCP server development
- Integration with existing systems
- Extensive testing and validation
- Operational training and procedures

## Operational Fit

**Excellent for**:
- High-volume sanitisation requirements
- Organisations with mature classification guides
- Scenarios requiring consistent reasoning
- Environments with GPU infrastructure available

**Poor for**:
- Low-volume, ad-hoc sanitisation (overhead too high)
- Organisations without clear classification rules
- Environments without GPU infrastructure
- Time-critical sanitisation (minutes per document)

## Comparison to Alternatives

**vs Manual Review**:
- ✅ Faster for high volumes
- ✅ More consistent reasoning
- ❌ Requires significant infrastructure investment
- ❌ Still requires human review

**vs Keyword Blocking (Dirty Word Lists)**:
- ✅ Context-aware (understands meaning, not just words)
- ✅ Explains reasoning
- ❌ More complex to deploy
- ❌ Higher computational cost

**vs Rule-Based Systems**:
- ✅ Handles novel situations better
- ✅ Learns from feedback
- ❌ Less predictable
- ❌ Harder to audit (black box)

## Future Enhancements

1. **Multi-Modal**: Support images, videos, audio (not just text)
2. **Real-Time**: Faster inference for time-sensitive transfers
3. **Automated Tearlines**: Generate multiple classification levels automatically
4. **Cross-Domain LLM**: Specialised LLM trained on classification examples
5. **Active Learning**: LLM requests clarification when uncertain
6. **Integration**: Direct integration with document management systems

## Future Enhancements

1. **Multi-Modal**: Support images, videos, audio (not just text)
2. **Real-Time**: Faster inference for time-sensitive transfers
3. **Automated Tearlines**: Generate multiple classification levels automatically
4. **Cross-Domain LLM**: Specialised LLM trained on classification examples
5. **Active Learning**: LLM requests clarification when uncertain
6. **Integration**: Direct integration with document management systems

---

*This solution leverages modern LLM capabilities with MCP for context-aware, intelligent sanitisation whilst maintaining human oversight and traditional CDS controls for defence in depth.*

