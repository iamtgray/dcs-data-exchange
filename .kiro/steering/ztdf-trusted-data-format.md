---
inclusion: auto
description: Comprehensive guide to Zero Trust Data Format (ZTDF) and Trusted Data Format (TDF) for data-centric security, federated key management, and secure multi-party data sharing
---

# Zero Trust Data Format (ZTDF) and Trusted Data Format (TDF)

## Overview

ZTDF (Zero Trust Data Format) is an interoperable data security wrapper built on the open TDF (Trusted Data Format) standard. It implements data-centric security principles where protection travels with the data itself, regardless of where it moves.

**Key Facts:**
- ZTDF was standardized by NATO in March 2024
- Built on OpenTDF specification (JSON-based, modern evolution of IC-TDF XML format)
- Enables secure cross-border and cross-classification data sharing
- Provides persistent, auto-enforcing access controls

## Core Concepts

### Data-Centric Security
Unlike perimeter-based security, TDF embeds protection directly into data objects (files, messages, documents). The data carries its own security policy wherever it travels - across organizational boundaries, cloud storage, or partner systems.

### TDF Structure
A TDF object is typically a ZIP archive (.tdf extension) containing:
- **payload**: The encrypted data
- **manifest.json**: Metadata including:
  - Encryption details
  - Key access information (where to get decryption keys)
  - Access control policy (ABAC rules)
  - Optional cryptographic assertions

### Key Access Server (KAS)
The KAS is the central component that:
- Manages Key Encryption Keys (KEK) that protect Data Encryption Keys (DEK)
- Acts as a Policy Enforcement Point (PEP)
- Evaluates Attribute-Based Access Control (ABAC) rules via Policy Decision Point (PDP)
- Provides audit trails of all key access requests

## Encryption Workflows

### Symmetric Mode (Online)
1. SDK generates DEK to encrypt data
2. DEK is sent to KMaaS/KAS for wrapping with KEK
3. Wrapped DEK stored in manifest alongside encrypted data
4. Decryption requires online policy evaluation and key unwrapping

### Asymmetric Mode (Offline Encryption)
1. SDK encrypts data with DEK locally
2. DEK wrapped using public KEK (no KAS communication needed)
3. Decryption still requires online KAS access for policy evaluation
4. Enables disconnected/offline encryption scenarios

## Federated Key Management

**Critical Feature:** TDF supports multiple KAS servers in a single TDF object.

- A manifest can contain multiple `keyAccess` objects
- Each can reference different KAS instances (different organizations)
- Supports "AnyOf" access patterns - any participating KAS can unlock data
- Each KAS can use different cryptographic algorithms independently
- Enables secure cross-domain collaboration in zero-trust environments

**Use Cases:**
- Multi-organization data sharing with independent policy enforcement
- Cross-border intelligence sharing
- Coalition operations where each party maintains sovereignty
- Gradual migration to post-quantum cryptography

## Access Control

### Attribute-Based Access Control (ABAC)
- Policies based on attributes of users, data, and environment
- Highly scalable and flexible
- Attributes evaluated at decryption time by policy server
- Enables dynamic access decisions

### Policy Binding
- Policies cryptographically bound to key access information
- Prevents policy tampering after TDF creation
- Ensures data owner maintains control even after sharing

## Security Principles (C.I.A. Triad)

- **Confidentiality**: Strong encryption + ABAC ensures only authorized access
- **Integrity**: Cryptographic binding prevents unauthorized modifications
- **Availability**: Distributed key management + offline creation maintains accessibility

## Reference Implementation

**Official Specification:** https://github.com/opentdf/spec

**OpenTDF Platform:** https://github.com/opentdf/platform
- Client SDKs: Java, JavaScript, Go
- Server components including KAS reference implementation
- Active open-source development

**Key Documentation:**
- Schema: JSON schemas for manifest structure
- Protocol: Architecture, workflows, KAS interactions
- Concepts: Access control and security principles

## Thinking About TDF for Data Sharing

### Design Principles

1. **Data Travels with Protection**: Don't think about securing networks or storage - secure the data object itself

2. **Policy Persistence**: Access decisions happen at consumption time, not sharing time. Policies can be updated even after data is shared.

3. **Federation-First**: Design for multi-party scenarios from the start. Each organization can maintain its own KAS while participating in shared data ecosystems.

4. **Attribute Standardization**: Success in federated environments requires agreement on attribute schemas and semantics across organizations.

5. **Audit by Design**: Every key access attempt is logged, providing comprehensive audit trails across organizational boundaries.

### Architecture Considerations

**For Single Organization:**
- One KAS instance with centralized policy management
- Focus on ABAC attribute design for internal use cases
- Consider symmetric mode for simplicity

**For Multi-Organization Federation:**
- Each party operates independent KAS
- Agree on common attribute vocabulary and policy patterns
- Use multiple `keyAccess` entries in TDF manifests
- Design for eventual consistency in policy updates
- Plan for cross-organization audit aggregation

**For Disconnected Operations:**
- Use asymmetric mode for offline encryption
- Pre-distribute public KEKs to field operators
- Ensure KAS availability for decryption operations
- Consider policy caching strategies for degraded connectivity

### Common Patterns

**Coalition Data Sharing:**
- Each nation/organization runs their own KAS
- TDF objects include keyAccess for all participating KAS instances
- Shared attribute schema defines common security markings
- Each party maintains audit logs of their citizens' access

**Secure Supply Chain:**
- Data encrypted at origin with supplier's KAS
- Additional keyAccess entries added for downstream partners
- Policies enforce "need to know" based on supply chain role
- Audit trail tracks data flow through supply chain

**Cross-Domain Solutions:**
- Bridge between classification levels or security domains
- KAS instances in each domain enforce domain-specific policies
- TDF enables controlled data flow with persistent protection
- Guards can inspect policies without decrypting payloads

## Integration Guidelines

When implementing TDF-based solutions:

1. **Start with Attributes**: Design your attribute schema before writing code
2. **Policy as Code**: Treat policy definitions as versioned, tested code
3. **Test Federation Early**: Don't wait until production to test multi-KAS scenarios
4. **Monitor Key Access**: KAS access patterns reveal usage and potential security issues
5. **Plan for Crypto Agility**: Use TDF's multi-KAS support to enable algorithm transitions

## Standards Compliance

- **OpenTDF Specification**: Follow semantic versioning, JSON schema definitions
- **ZTDF (NATO)**: Includes additional cryptographic assertions for NATO use cases
- **IC-TDF**: Legacy XML format, contact OpenTDF for interoperability details

---

*Content rephrased for compliance with licensing restrictions. Sources: [OpenTDF Specification](https://github.com/opentdf/spec), [Stormshield ZTDF Documentation](https://documentation.stormshield.com/SEP/en/Content/SDK_doc/ztdf.html)*
