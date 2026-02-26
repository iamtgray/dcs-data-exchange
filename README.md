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

### Scenarios (`scenario.md`, future: `scenario-*.md`)

Detailed use cases describing multi-party data sharing requirements. Each scenario includes:
- Participating organizations/nations
- Data flows and enrichment processes
- Classification and access control requirements
- Operational constraints and challenges

**Current Scenario**: Three-nation coalition (Poland, UK, US) sharing sensor data with progressive enrichment and complex cross-border access policies.

### Technical Solutions (`next.md`, future: `solution-*.md`)

Analysis of technical approaches to solve challenges identified in scenarios. Includes:
- Problem statements
- Solution options with trade-offs
- Recommendations
- Implementation considerations

**Current Focus**: Offline key management and dual-mode encryption (PKI for tactical, TDF for strategic).

### Architectures (future: `architecture-*.md`)

Detailed technical architectures implementing the solutions, including:
- System components and interactions
- Sequence diagrams
- API specifications
- Deployment models
- Security considerations

**Status**: In development - awaiting decision on offline key management approach.

## Knowledge Base

### `.kiro/steering/` - AI Assistant Context

These files provide domain knowledge to AI assistants working on this repository:

#### `data-centric-security.md`
Overview of Data-Centric Security (DCS) principles, the three DCS levels, and implementation guidance for defense and NATO contexts.

#### `ztdf-trusted-data-format.md`
Comprehensive guide to ZTDF/TDF including:
- Core concepts and structure
- Federated key management
- Encryption workflows (symmetric and asymmetric modes)
- Access control patterns
- Design principles for multi-party data sharing
- Integration guidelines

These steering files are automatically included in AI assistant context to ensure consistent understanding of DCS, ZTDF, and coalition data sharing patterns.

## Current Work

### Scenario: Multi-National Intelligence Data Sharing

Three NATO nations (Poland, UK, US) sharing sensor data with progressive enrichment:

1. **Phase 1**: Poland produces sensor data (NS classification)
2. **Phase 2**: UK enriches with intelligence sources (S classification + WALL SAP)
3. **Phase 3**: US enriches with intelligence sources (IL-6 + WALL SAP)

Each nation operates independent Key Access Server (KAS) with federated key management.

### Technical Challenges Addressed

✅ **Challenge 1: Attribute Mapping** - Solved via ACP-240 standardized classification mapping  
✅ **Challenge 2: Policy Conflicts** - Solved via AnyOf key access pattern  
✅ **Challenge 3: TDF Extension** - Solved via manifest-only update method  
🔄 **Challenge 4: Offline Key Management** - In progress (see `next.md`)

### Proposed Solution: Dual-Mode Encryption

**Tactical Edge** (unit-to-unit):
- PKI with certificate-based encryption
- CRL/OCSP for offline certificate validation
- Lightweight, fully offline-capable

**Strategic Level** (coalition-wide):
- TDF/ZTDF with federated KAS
- Full ABAC policy enforcement
- Comprehensive audit trails

**Gateways**: Secure transition points between PKI and TDF domains

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

## Contributing

This repository documents architectural exploration and design decisions. Each scenario should:
1. Describe realistic operational requirements
2. Identify technical challenges
3. Propose and analyze solutions
4. Document architectural decisions

## Future Work

- Complete offline key management architecture
- Address remaining challenges (key revocation, time sync, trust establishment)
- Design detailed KAS federation architecture
- Create sequence diagrams for data flows
- Explore additional scenarios (cross-domain, maritime, air operations)
- Integrate unreleased NATO standard (when available)

## License

[To be determined]

## Contact

[To be determined]

---

*This is a living repository. Scenarios, solutions, and architectures will evolve as we explore the design space for coalition data sharing.*
