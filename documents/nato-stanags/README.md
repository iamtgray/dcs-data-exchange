# NATO STANAGs for Data-Centric Security

## Important Note on STANAG Availability

NATO STANAGs are generally **not publicly downloadable**. They are NATO UNCLASSIFIED or NATO RESTRICTED documents distributed through official NATO channels. This document provides reference information about each relevant STANAG based on publicly available summaries, academic papers, and defence industry publications.

To obtain full STANAG documents, contact your national NATO delegation or access via the NATO Standardization Office (NSO) portal at https://nso.nato.int.

## Core DCS STANAGs

### STANAG 4774 - Confidentiality Metadata Label Syntax
- **Allied Data Publication**: ADatP-4774
- **Title**: Confidentiality Metadata Label Syntax
- **Edition**: Edition A, Version 1
- **Status**: Promulgated
- **Classification**: NATO UNCLASSIFIED

**What it covers**:
STANAG 4774 defines a standardized syntax for expressing confidentiality labels as structured metadata. It provides an XML-based format for encoding:
- Classification levels (e.g., NATO UNCLASSIFIED, NATO RESTRICTED, NATO SECRET, COSMIC TOP SECRET)
- Policy identifiers (which classification system applies)
- Category markings (caveats, releasability, special access programs)
- Creation and expiry timestamps for labels

**Structure of a 4774 label**:
```xml
<ConfidentialityLabel xmlns="urn:nato:stanag:4774:confidentialitymetadatalabel:1:0">
  <ConfidentialityInformation>
    <PolicyIdentifier>urn:nato:stanag:4774:confidentialitymetadatalabel:1:0:policy:NATO</PolicyIdentifier>
    <Classification>SECRET</Classification>
    <Category TagName="ReleasableTo" Type="PERMISSIVE">
      <CategoryValue>GBR</CategoryValue>
      <CategoryValue>USA</CategoryValue>
      <CategoryValue>POL</CategoryValue>
    </Category>
  </ConfidentialityInformation>
</ConfidentialityLabel>
```

**Relevance to DCS**: This is the foundation of DCS Level 1 (Control/Labeling). Without standardized labels, systems cannot make consistent access control or protection decisions. Every DCS implementation starts with labeling data according to STANAG 4774.

**Key concepts**:
- Labels are machine-readable metadata, not just human-readable markings
- Labels can express complex policies (multiple categories, compound rules)
- Labels are independent of the data format they describe
- Labels support both NATO and national classification schemes

---

### STANAG 4778 - Metadata Binding Mechanism
- **Allied Data Publication**: ADatP-4778
- **Title**: Metadata Binding Mechanism
- **Edition**: Edition A, Version 1
- **Status**: Promulgated
- **Classification**: NATO UNCLASSIFIED

**What it covers**:
STANAG 4778 defines how to cryptographically bind metadata labels (including STANAG 4774 confidentiality labels) to the data they describe. This uses digital signatures to ensure:
- Labels cannot be removed from data without detection
- Labels cannot be modified without detection
- The binding between label and data is verifiable
- The identity of the entity that created the binding is provable

**Binding mechanism**:
- Uses XML Digital Signatures (XMLDSig) or JSON Web Signatures (JWS)
- Supports both enveloping (signature wraps data) and detached (signature separate) modes
- Requires PKI infrastructure for signing and verification
- Supports multiple simultaneous bindings (multiple labels on same data)

**Relevance to DCS**: This moves DCS Level 1 from basic labeling to **cryptographically assured labeling**. Without binding, labels are just advisory - with binding, labels have cryptographic integrity guarantees. This is what makes labels trustworthy across organizational boundaries.

**Key concepts**:
- Binding creates a trust chain: data -> label -> signature -> certificate -> trust anchor
- Any modification to data or label invalidates the binding
- Bindings support federation (each organization can add their own bindings)
- Gateways at organizational boundaries can verify bindings and re-bind after transformation

---

### STANAG 4778 Extension for ZTDF (Zero Trust Data Format)
- **Status**: Standardized by NATO in March 2024
- **Basis**: Built on OpenTDF specification
- **Classification**: NATO UNCLASSIFIED (specification); implementations may vary

**What it covers**:
The ZTDF extension to STANAG 4778 standardizes a data wrapper format that combines:
- STANAG 4774 confidentiality labels
- STANAG 4778 metadata binding
- Encryption of data payload (AES-256-GCM)
- Key Access Server (KAS) integration for key management
- Attribute-Based Access Control (ABAC) policy embedding
- Federated key management across multiple organizations

**ZTDF Structure**:
```
my-document.tdf (ZIP archive)
  |-- 0.payload           (AES-256-GCM encrypted data)
  |-- 0.manifest.json     (metadata, key access info, ABAC policy)
```

**Manifest includes**:
- `encryptionInformation`: Algorithm, key access objects (one per KAS)
- `payload`: Reference to encrypted payload, MIME type, integrity hash
- `assertions`: Cryptographic assertions (STANAG 4774 labels bound per 4778)

**Relevance to DCS**: ZTDF is the NATO standard that implements DCS Level 3 (Protection via Encryption). It combines all three DCS concepts - Control (labels), Protect (encryption), and Share (federated key management) - into a single interoperable format.

---

### ACP-240 - NATO Cryptographic Interoperability Strategy
- **Title**: NATO Cryptographic Interoperability Strategy
- **Status**: Active
- **Classification**: Varies by section

**What it covers**:
ACP-240 defines NATO's approach to cryptographic interoperability across member nations, including:
- Approved cryptographic algorithms for NATO use
- Key management interoperability requirements
- Cryptographic equipment interoperability standards
- Migration paths for algorithm transitions (including post-quantum)
- Certificate management for cross-national operations

**Relevance to DCS**: ACP-240 governs which cryptographic algorithms can be used in ZTDF implementations for NATO operations. It means that when one nation encrypts data, all other authorized nations can decrypt it using interoperable cryptographic implementations.

---

### STANAG 4406 - Military Message Handling System (MMHS)
- **Title**: Military Message Handling System
- **Status**: Promulgated
- **Classification**: NATO UNCLASSIFIED

**What it covers**:
Defines the military messaging standard that commonly carries DCS-labeled data between NATO systems. MMHS messages can include STANAG 4774 confidentiality labels and STANAG 4778 bindings.

**Relevance to DCS**: MMHS is one of the primary transport mechanisms for DCS-protected data in NATO. Understanding how DCS labels travel within MMHS messages is necessary for implementing end-to-end data protection.

---

### STANAG 5516 - Link 16
- **Relevance**: Tactical data links that carry security-labeled tactical data. DCS principles apply to data shared over Link 16 at the tactical edge.

### STANAG 4559 - NATO Standard for Intelligence, Surveillance, and Reconnaissance (ISR) Library Interface
- **Relevance**: Defines how ISR products are stored and shared, including metadata labeling requirements that align with STANAG 4774.

### STANAG 5500 - NATO Message Text Formatting System (FORMETS)
- **Relevance**: Structured message formats that can carry DCS labels as part of formatted military messages.

---

## NATO Core Metadata Specification (NCMS)
- **Version**: 1.0
- **Status**: Published

**What it covers**:
The NCMS defines a common set of metadata elements for describing NATO information resources. It includes:
- Dublin Core-based metadata elements
- NATO-specific extensions for security marking
- Integration with STANAG 4774 for confidentiality labels
- Support for resource discovery and access control

**Relevance to DCS**: NCMS provides the broader metadata framework within which DCS labels (STANAG 4774) operate. It keeps security metadata part of a complete metadata ecosystem, not isolated from other descriptive metadata.

---

## How These Standards Work Together

```
                     STANAG 4774                    STANAG 4778
                  (Label Syntax)                 (Label Binding)
                        |                              |
                        v                              v
              +------------------+          +---------------------+
              | Classification:  |          | Digital Signature   |
              |   NATO SECRET    |--------->| binds label to data |
              | Releasable To:   |          | using PKI           |
              |   GBR, USA, POL  |          +---------------------+
              +------------------+                    |
                                                      v
                                              +---------------+
                                              | ZTDF Wrapper  |
                                              | (March 2024)  |
                                              |               |
                                              | - Encrypted   |
                                              |   payload     |
                                              | - Labels      |
                                              | - KAS refs    |
                                              | - ABAC policy |
                                              +---------------+
                                                      |
                                    ACP-240            |
                                (Crypto Standards)     |
                                        |              |
                                        v              v
                              +---------------------------+
                              | Interoperable Coalition   |
                              | Data Sharing              |
                              | - Each nation's KAS       |
                              | - Common label vocabulary  |
                              | - Federated key mgmt      |
                              | - Cross-border audit       |
                              +---------------------------+
```

## DCS Maturity Levels Mapped to Standards

| DCS Level | Capability | Primary Standards |
|-----------|-----------|-------------------|
| Level 1 (Basic) | Metadata labels on data (advisory) | STANAG 4774, NCMS |
| Level 1 (Assured) | Cryptographically bound labels | STANAG 4774 + 4778 |
| Level 2 | Access control based on labels | STANAG 4774 + ABAC policies |
| Level 3 | Encrypted data with policy enforcement | ZTDF (4774 + 4778 + encryption + KAS) |

## Academic and Industry References

These publications provide additional context on NATO DCS standards:
1. Nexor - "The Data-Centric Security Interoperability Dilemma" (publicly available whitepaper)
2. Springer - "Towards Data-Centric Security for NATO Operations" (academic paper)
3. NATO Allied Command Transformation - DCS documentation
4. OpenTDF Specification - https://github.com/opentdf/spec (open source, implements ZTDF)
5. Stormshield ZTDF Documentation - https://documentation.stormshield.com/SEP/en/Content/SDK_doc/ztdf.html
6. NATO Communications and Information Agency (NCIA) - DCS programme publications
