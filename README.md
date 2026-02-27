# Data-Centric Security: Coalition Data Exchange

This repository explores architectural patterns for secure, multi-party data sharing in coalition environments using Data-Centric Security (DCS) principles, Zero Trust Data Format (ZTDF), and Trusted Data Format (TDF).

## Purpose

Design and document practical architectures for intelligence and operational data sharing between allied nations, with focus on:
- Persistent data protection that travels with the data
- Attribute-Based Access Control (ABAC) across organizational boundaries
- Federated key management with national sovereignty
- Offline and degraded connectivity scenarios
- Real-world operational constraints

## Repository Structure

```
dcs-data-exchange/
├── scenarios/              # Problem definitions with acceptance criteria
│   ├── 01-coalition-strategic-sharing.md
│   └── 02-tactical-unit-to-unit.md
├── solutions/              # Solution options for scenarios
│   ├── 01-strategic/       # Solutions for strategic sharing
│   ├── 02-tactical/        # Solutions for tactical operations
│   └── cross-cutting/      # Solutions spanning multiple scenarios
│       └── offline-key-management-options.md
├── architectures/          # Detailed technical architectures
│   ├── 01-strategic-tdf-federation/
│   └── 02-tactical-pki/
└── .kiro/steering/         # AI assistant knowledge base
    ├── data-centric-security.md
    ├── ztdf-trusted-data-format.md
    └── scenario-development.md
```

### Scenarios

**Problem definitions** describing operational requirements and challenges. Each scenario includes:
- Actors and their constraints
- Operational flow and data sharing needs
- Technical challenges
- **Acceptance criteria** (measurable, testable success criteria)
- Success metrics

Scenarios are **solution-agnostic** - they describe problems, not solutions.

**Current Scenarios**:
- **01: Coalition Strategic Intelligence Sharing** - Multi-nation intelligence sharing with reliable connectivity
- **02: Tactical Unit-to-Unit Communications** - Forward units in DDIL (Denied, Degraded, Intermittent, Limited) environments

### Solutions

**Approach options** to solve scenario challenges. Multiple solutions can address the same scenario. Each solution includes:
- How it works
- Advantages and disadvantages
- Which acceptance criteria it meets
- Technology stack and complexity
- Operational fit

Solutions are organized by scenario with comparison documents analyzing trade-offs.

**Current Solutions**:
- **Offline Key Management Options** - Six approaches for tactical/strategic key management (cross-cutting)

### Architectures

**Detailed technical designs** implementing solutions. Each architecture includes:
- Component specifications
- Sequence diagrams and data flows
- Deployment models
- Security analysis
- Implementation and testing guides

Architectures map directly to acceptance criteria for verification.

**Status**: In development - awaiting solution selection.

## Knowledge Base

### `.kiro/steering/` - AI Assistant Context

Domain knowledge files automatically included in AI assistant context:

#### `data-centric-security.md`
Data-Centric Security (DCS) principles, three DCS levels, implementation guidance for defense and NATO contexts.

#### `ztdf-trusted-data-format.md`
Comprehensive ZTDF/TDF guide: core concepts, federated key management, encryption workflows, access control patterns, design principles, integration guidelines.

#### `scenario-development.md`
Guide for developing scenarios, solutions, and architectures. Explains repository structure, format requirements, workflow from scenario to architecture, and best practices for working with AI assistants.

These files ensure consistent understanding across AI sessions.

## Current Work

### Scenario 01: Coalition Strategic Intelligence Sharing

Three NATO nations (Poland, UK, US) sharing sensor data with progressive enrichment. Each nation operates independent Key Access Server (KAS) with federated key management.

**Status**: Acceptance criteria defined, ready for solution development

**Key Acceptance Criteria**:
- Cross-border data sharing with single encryption
- Classification system interoperability (NS ↔ S ↔ IL-6)
- Granular access control (clearance + SAP combinations)
- Federated key management with national sovereignty
- Dynamic recipient addition without payload re-encryption
- Comprehensive audit trails

### Scenario 02: Tactical Unit-to-Unit Communications

Forward-deployed units (Polish, UK, US) sharing operational data in DDIL environments without strategic infrastructure connectivity.

**Status**: Acceptance criteria defined, ready for solution development

**Key Acceptance Criteria**:
- Offline encryption/decryption (no KAS connectivity)
- Certificate validation with stale CRL (48+ hours)
- Rapid distribution (< 15 minutes end-to-end)
- Bandwidth efficiency (< 10% overhead)
- Tactical-to-strategic transition when connectivity restored
- Local audit logging with sync when online

### Cross-Cutting Solution: Offline Key Management

Six solution options analyzed for handling offline/tactical scenarios:
1. Asymmetric mode with pre-distributed public keys
2. Pre-shared wrapped DEK bundles
3. Cached KAS authorization tokens
4. Federated key escrow service
5. Hybrid tiered access (planned vs ad-hoc)
6. **Dual-mode encryption** (PKI tactical + TDF strategic) ← Recommended

**Next Step**: Design architectures for Scenario 01 (TDF-based) and Scenario 02 (PKI-based)

## Key Concepts

### Data-Centric Security (DCS)
Security embedded in the data itself, not the perimeter. Protection persists wherever data travels.

### Zero Trust Data Format (ZTDF)
NATO-standardized (March 2024) data wrapper built on OpenTDF. Enables secure cross-border data sharing with persistent access controls.

### Federated Key Management
Multiple organizations operate independent Key Access Servers (KAS) that collaboratively manage access to shared data while maintaining sovereignty.

### AnyOf vs AllOf Key Access
- **AnyOf**: Any participating KAS can independently grant access (flexible, faster)
- **AllOf**: All participating KAS must approve (more secure, requires key splitting)

## References

- [OpenTDF Specification](https://github.com/opentdf/spec) - Official TDF standard
- [OpenTDF Platform](https://github.com/opentdf/platform) - Reference implementation
- ACP-240 

## Workflow

### From Problem to Solution to Architecture

1. **Define Scenario**: Operational requirements + acceptance criteria
2. **Explore Solutions**: Multiple approaches with trade-off analysis
3. **Design Architecture**: Detailed technical design for selected solution
4. **Validate**: Verify architecture meets acceptance criteria

See `.kiro/steering/scenario-development.md` for detailed workflow guidance.

## Contributing

When adding scenarios:
- Use solution-agnostic problem descriptions
- Include measurable acceptance criteria
- Document operational constraints
- Define success metrics

When proposing solutions:
- Address specific scenario challenges
- Document advantages and disadvantages
- Map to acceptance criteria
- Analyze operational fit

When designing architectures:
- Include component diagrams and sequences
- Document deployment models
- Analyze security and performance
- Provide implementation guidance
- Verify against acceptance criteria

## Future Work

- Design TDF federation architecture for Scenario 01
- Design PKI-based architecture for Scenario 02
- Design gateway architecture for tactical-to-strategic transition
- Explore additional scenarios:
  - Cross-domain transfers (classification level transitions)
  - Maritime operations (ship-to-ship, ship-to-shore)
  - Air operations (aircraft-to-ground, air-to-air)
  - Multi-level security (simultaneous classification levels)
- Integrate unreleased NATO standard (when available)
- Prototype and test against acceptance criteria

## License

[To be determined]

## Contact

[To be determined]

---

*This is a living repository. Scenarios, solutions, and architectures will evolve as we explore the design space for coalition data sharing.*
