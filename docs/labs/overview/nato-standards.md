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

This standard defines the format for confidentiality labels. It specifies how to express:- Classification levels (UNCLASSIFIED, NATO SECRET, COSMIC TOP SECRET, etc.)
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

**Why it matters:** Without a standard label format, every system invents its own way of marking data. That makes it impossible to share data between systems from different organizations or nations.

### STANAG 4778: how to bind labels to data

Labels are only useful if you can trust them. STANAG 4778 defines how to cryptographically bind a label to its data using digital signatures. This means:

- Nobody can remove a label from data without being detected
- Nobody can change a label without being detected
- You can verify who created the label and when

This is the difference between basic and assured DCS Level 1:

| | Basic Level 1 (Lab 1) | Assured Level 1 (Architecture Reference) |
|---|---|---|
| Labels | S3 tags, anyone with tagging permissions can change them | STANAG 4774 XML, stored in DynamoDB |
| Binding | None, labels are advisory | Digital signature over label + data hash via AWS KMS |
| Tampering | Undetectable | Cryptographically detectable |
| Data integrity | Not checked | SHA-256 hash verified on every access |
| Trust model | Trust the application layer | Trust the cryptography |

**Why it matters:** Without binding, labels are just suggestions. With binding, labels have cryptographic proof of integrity, making them trustworthy across organizational boundaries.

### ZTDF: Zero Trust Data Format (NATO, March 2024)

ZTDF is the newest NATO standard. It packages everything together:

- Encrypted data (the payload)
- Security labels (STANAG 4774 format)
- Cryptographic binding (STANAG 4778 method)
- Key access information (which Key Access Server can unwrap the encryption key)
- Access control policy (what attributes a user needs to decrypt)

ZTDF is built on the open-source **OpenTDF** specification, which means there's freely available software that implements it.

**Why it matters:** ZTDF is the implementation of DCS Level 3. It's the standard format for data that protects itself.

### ACP-240: cryptographic interoperability

This standard governs which encryption algorithms NATO nations can use and how they should interoperate. When one nation encrypts data, other authorized nations can decrypt it.

## How these standards map to our labs and architectures

| Standard | DCS Level | In the Labs (basic) | In the Architecture References (compliant) |
|----------|-----------|--------------------|--------------------------------------------|
| STANAG 4774 (labels) | Level 1 | S3 tags as simplified labels | Full XML labels with PolicyIdentifier, typed Categories |
| STANAG 4778 (binding) | Level 1+ | Not implemented, labels are advisory | KMS digital signatures binding labels to data hashes |
| ZTDF (encryption) | Level 3 | OpenTDF deployment (already ZTDF-compliant) | Same, OpenTDF implements the NATO standard directly |
| ACP-240 (crypto) | Level 3 | AWS KMS with AES-256-GCM | Same, KMS is FIPS 140-3 Level 3 validated |

Notice that Lab 3 is already close to STANAG-compliant because OpenTDF implements ZTDF directly. The biggest gap is in Level 1, where the labs use simplified S3 tags instead of proper 4774/4778 labels. The **Assured DCS Level 1** architecture reference closes that gap.

!!! note "You don't need to read the STANAGs"
    The full STANAG documents are distributed through official NATO channels and aren't publicly downloadable. The labs in this workshop teach the same concepts using AWS services, without requiring access to the original standards. The architecture references show how to implement the standards correctly if you need formal compliance.
