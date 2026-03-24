# Solution options

Solutions propose and analyze different approaches to the challenges identified in [scenarios](../scenarios/index.md). Multiple solutions can address the same scenario, and cross-cutting solutions span multiple scenarios.

Each solution documents how it works, advantages and disadvantages, which acceptance criteria it meets, and its operational fit.

## Cross-cutting solutions

- [Classification and Labelling](cross-cutting/classification-labelling/index.md) -- Batch and hybrid approaches for applying DCS labels to data, plus a comparison of classification methods
- [Offline Key Management Options](cross-cutting/offline-key-management-options.md) -- Six approaches for handling encryption and key management in offline/tactical environments

## Scenario-specific solutions

### Scenario 03: Legacy system DCS retrofit

- [JLTS Legacy Application Profile](03-legacy-retrofit/legacy-app-profile.md) -- Detailed description of a fictional COBOL/DB2 NATO logistics system used as a concrete example for DCS retrofit approaches
- [Option 1: Shadow Label Store](03-legacy-retrofit/option-1-shadow-label-store.md) -- DB2 metadata tables for classification labels (DCS Level 1)
- [Option 2: User Attribute Store](03-legacy-retrofit/option-2-user-attribute-store.md) -- Security attributes mapped to RACF user IDs (DCS Level 2 prerequisite)
- [Option 3: TN3270 Security Proxy](03-legacy-retrofit/option-3-tn3270-security-proxy.md) -- Protocol-aware proxy for interactive access filtering (DCS Level 2)
- [Option 4: Batch Export Gateway](03-legacy-retrofit/option-4-batch-export-gateway.md) -- Filtering and STANAG 4778 labeling for outbound data (DCS Level 1 assured + Level 2)

### Scenario 04: Cross-domain sanitisation

- [LLM-Based Intelligent Sanitisation](04-sanitisation/option-1-llm-mcp-sanitisation.md) -- Using large language models for automated content redaction and cross-domain transfer

!!! note "More solutions coming"
    Solutions for additional scenarios are in development. See the [gap analysis](../NEXT-STEPS.md) for the full list of unresolved challenges.
