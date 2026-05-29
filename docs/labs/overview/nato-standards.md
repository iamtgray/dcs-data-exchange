# NATO standards

DCS isn't just a concept. NATO has published formal standards that define how it works. You don't need to read these standards to complete the labs, but understanding what they are helps you see how this fits into real-world defence systems.

## Basic concepts vs STANAG compliance

This workshop teaches DCS in two stages:

1. **Basic concepts (the labs)** -- You'll use simplified AWS implementations (S3 tags, Lambda functions, Cedar policies) to learn what DCS does and why each level matters. Like learning to cook with a recipe before studying food science.

2. **STANAG-compliant implementations (the architecture references)** -- Once you understand the concepts, the architecture documents show how to implement them using the actual NATO standards. Proper XML labels, cryptographic signatures, formal classification vocabularies.

Why this order? Because the standards are dense. If you start with STANAG 4774 XML schemas and STANAG 4778 digital signature binding, you'll spend all your time on format details and miss the security concepts underneath. The labs strip away that complexity so you can focus on what matters: how labels, access control, and encryption work together to protect data.

!!! tip "When does STANAG compliance matter?"
    If you're building a system that only operates within your own organization, the basic approach may be sufficient. STANAG compliance becomes important when you need to share data across organizational or national boundaries, because both sides need to agree on label formats, signature mechanisms, and trust models. The STANAGs provide that common language.

## The key standards

### STANAG 4774: how to write security labels

This standard defines the format for confidentiality labels. It specifies how to express:

- Classification levels (UNCLASSIFIED, NATO SECRET, COSMIC TOP SECRET, etc.)
- Which policy applies (NATO, national, or coalition-specific)
- Release markings (which countries can see the data)
- Special access requirements (codewords, programs)

A STANAG 4774 label looks something like this:

```xml
<ConfidentialityLabel
    xmlns="urn:nato:stanag:4774:confidentialitymetadatalabel:1:0">
  <ConfidentialityInformation>
    <PolicyIdentifier>
      urn:nato:stanag:4774:confidentialitymetadatalabel:1:0:policy:NATO
    </PolicyIdentifier>
    <Classification>SECRET</Classification>
    <Category TagName="ReleasableTo" Type="PERMISSIVE">
      <CategoryValue>GBR</CategoryValue>
      <CategoryValue>USA</CategoryValue>
      <CategoryValue>POL</CategoryValue>
    </Category>
  </ConfidentialityInformation>
</ConfidentialityLabel>
```

Compare this to what we use in Lab 1:

```
S3 Tag: dcs:classification = SECRET
S3 Tag: dcs:releasable-to  = GBR,USA,POL
```

The S3 tags carry the same information, but they lack the structure that makes labels interoperable. The STANAG 4774 format includes:

- A **PolicyIdentifier** that specifies which classification scheme applies (NATO, UK national, US national)
- **Typed categories** -- `PERMISSIVE` means the user must match at least one value; `RESTRICTIVE` means the user must hold all values
- A formal **namespace** so any STANAG 4774-compliant system worldwide can parse the label
- Support for **portion-level labelling** -- different parts of a document can carry different classifications
- A **common security policy model** with machine-readable Security Policy Information Files (SPIFs)

**Why it matters:** Without a standard label format, every system invents its own way of marking data. That makes it impossible to share data between systems from different organizations or nations.

### STANAG 4778: how to bind metadata to data

STANAG 4778 is more than cryptographic binding -- it defines a complete framework for formally associating metadata with data. It specifies:

- **How to state the relationship** between metadata and data (what the metadata asserts about the data)
- **Three binding approaches** depending on how data is structured:
    - **Encapsulating** -- the binding wraps both data and metadata (like a signed envelope)
    - **Embedded** -- the binding lives inside the data object itself (like a signed XML element)
    - **Detached** -- the binding is stored separately, referencing both metadata and data (like a signed manifest)
- **Cryptographic integrity** using digital signatures to detect tampering
- **Non-cryptographic bindings** (algorithm="none") for environments where integrity is assured by other means

A key capability is **granular sub-document binding**. Rather than labelling a whole document at one classification, 4778 lets you bind different labels to different portions of structured data. It defines four inheritance rules for how child elements relate to parent labels.

This is the difference between basic and assured DCS Level 1:

| | Basic Level 1 (Lab 1) | Assured Level 1 (Architecture Reference) |
|---|---|---|
| Labels | S3 tags, anyone with tagging permissions can change them | STANAG 4774 XML, stored in DynamoDB |
| Binding | None, labels are advisory | Digital signature over label + data hash via AWS KMS |
| Tampering | Undetectable | Cryptographically detectable |
| Data integrity | Not checked | SHA-256 hash verified on every access |
| Trust model | Trust the application layer | Trust the cryptography |

**Why it matters:** Without binding, labels are just suggestions. With binding, labels have cryptographic proof of integrity, making them trustworthy across organizational boundaries. But 4778's granular binding capability also enables **DCS Level 2** -- because you can label individual portions of structured data (e.g., fields in a C2 message), a system can redact or release specific portions based on the recipient's clearance. This "redact-before-sending" pattern is how NATO envisions sharing structured data across classification boundaries.

### STANAG 5663: identity and access control (ABAC)

STANAG 5663 defines Identity, Credential, and Access Management (ICAM) including Attribute-Based Access Control (ABAC). While 4774 tells you how to label data and 4778 binds those labels, 5663 provides the framework for making access decisions based on those labels.

Key concepts:

- **Attributes** describe users, data, and the environment (clearance level, nationality, role, time, location)
- **Policies** define rules that compare user attributes against data labels to produce access decisions
- **Federation** allows attributes asserted by one nation to be trusted by another (within agreed trust frameworks)

**Why it matters:** Labels alone don't enforce anything -- you need a system that reads the labels, evaluates the requester's attributes, and makes an access decision. STANAG 5663 standardises how that works across NATO. It is the standards-level answer to DCS Level 2 (access control based on labels).

### ZTDF: Zero Trust Data Format

ZTDF is a data packaging format defined in ACP-240 Supplements 3 and 4 (a Combined Communications-Electronics Board publication, not a NATO STANAG). It packages together:

- Encrypted data (the payload)
- Security labels (STANAG 4774 format)
- Cryptographic binding (STANAG 4778 method)
- Key access information (which Key Access Server can unwrap the encryption key)
- Access control policy (what attributes a user needs to decrypt)

ZTDF is built on the open-source **OpenTDF** specification. ACP-240 positions ZTDF as one encoding specification for cryptographic data protection, noting that other formats may be added in future.

!!! warning "ZTDF and NATO"
    NATO has not adopted ZTDF and is not working towards doing so. From NATO's perspective, ZTDF has specific technical limitations:

    - **File-level encryption only** -- it cannot handle structured C2 data where individual fields need granular access control (e.g., releasing some fields of a message while withholding others)
    - **Centralised key management model** -- assumes a single key store, which conflicts with NATO's requirement for federated key sovereignty across nations
    - **Skips DCS Level 2** -- addresses encryption (Level 3) without solving granular labelling and ABAC enforcement (Level 2) first

    NATO is independently developing federated cryptographic key management standards for DCS Level 3, through a joint CCEB-NATO working group. The result will be published as both ACP-240 Supplement 5 and a NATO Allied Data Publication.

**Why it matters for this workshop:** ZTDF demonstrates DCS Level 3 *concepts* -- encryption with policy-gated key release and federated key management. The labs use OpenTDF to teach these principles. However, ZTDF should not be conflated with NATO's approach to Level 3 interoperability.

### ACP-240: data-centric security interoperability

ACP-240 is an Allied Communications Publication developed under the Combined Communications-Electronics Board (CCEB) within the Five Eyes (FVEY) alliance. It defines DCS principles, architecture, and key management for coalition data sharing. ACP-240 is effective on receipt for CCEB nations and requires a separate NAMILCOM directive for activation by NATO nations.

The NATO STANAGs (4774, 4778) predate ACP-240 by approximately 8 years. A cooperative arrangement signed between the NATO Digital Policy Committee and the CCEB Data Working Group updated ACP-240 supplements to properly reference and align with the NATO standards -- bringing ACP-240 up to NATO's existing specifications, not introducing ACP-240 concepts into NATO. Supplements 1, 3, and 4 have been updated so far.

NATO and CCEB are now co-developing federated cryptographic key management standards for DCS Level 3. The result will be published as both ACP-240 Supplement 5 and a NATO Allied Data Publication, ensuring interoperability between the two frameworks.

## How these standards map to our labs and architectures

| Standard | DCS Level | In the Labs (basic) | In the Architecture References |
|----------|-----------|--------------------|--------------------------------------------|
| STANAG 4774 (labels) | Level 1 | S3 tags as simplified labels | Full XML labels with PolicyIdentifier, typed Categories, portion marking |
| STANAG 4778 (binding) | Level 1-2 | Not implemented, labels are advisory | Formal relationship statements, cryptographic binding, granular sub-document labelling |
| STANAG 5663 (ABAC) | Level 2 | Cedar policies as simplified ABAC | Federated ICAM with attribute-based access decisions |
| ZTDF / ACP-240 (encryption) | Level 3 | OpenTDF to demonstrate encryption concepts | NATO developing federated key management standards (joint CCEB-NATO); ZTDF is one CCEB approach, not adopted by NATO |

## NATO DCS maturity timeline

NATO's Federated Mission Networking (FMN) framework defines target dates for DCS capability:

| DCS Maturity | Target | Capability |
|---|---|---|
| DCS-1 | 2025 | Basic labelling -- metadata labels applied to data objects |
| DCS-2 | 2028 | Enhanced labelling and access control -- granular labelling, ABAC enforcement |
| DCS-3 | 2033 | Cryptographic protection -- data encrypted with policy-bound keys, federated key management |

This timeline reflects that most NATO nations are still working towards DCS-1. The labs in this workshop let you experience all three levels using AWS services, but in practice the Alliance is on a multi-year journey from Level 1 to Level 3.

!!! note "You don't need to read the STANAGs"
    The full STANAG documents are distributed through official NATO channels and aren't publicly downloadable. The labs in this workshop teach the same concepts using AWS services, without requiring access to the original standards. The architecture references show how to implement the standards correctly if you need formal compliance.
