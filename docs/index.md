# Data-Centric Security: Coalition Data Exchange

Everything you need to learn and implement **Data-Centric Security (DCS)** on AWS: concepts, reference architectures, operational scenarios, solution patterns, and hands-on labs for coalition data sharing.

## What's inside

### [What is Data-Centric Security?](labs/overview/index.md)

Understand what DCS is, why it matters, the three DCS levels, NATO standards, and how it maps to AWS services.

### [Reference Architectures](architectures/index.md)

Five architecture designs with Terraform, covering all three DCS levels including STANAG-compliant and cloud-native approaches.

### [Operational Scenarios](scenarios/index.md)

Nine scenarios describing coalition data sharing challenges, from strategic intelligence sharing to tactical DDIL environments, legacy system retrofits, and real-time air operations.

### [Solution Options](solutions/index.md)

Proposed approaches to solve scenario challenges, with trade-off analysis and acceptance criteria mapping.

### [Hands-On Labs](labs/index.md)

Three progressive labs that teach DCS by building it on AWS:

| Lab | DCS Level | What You'll Build | Time |
|-----|-----------|-------------------|------|
| [Lab 1](labs/lab1/index.md) | Level 1 - Labeling | S3 objects with security tags, a Lambda that returns data with its labels | ~30 min |
| [Lab 2](labs/lab2/index.md) | Level 2 - Access Control | A policy engine (Amazon Verified Permissions) evaluating user attributes against data labels | ~45 min |
| [Lab 3](labs/lab3/index.md) | Level 3 - Encryption | OpenTDF platform on ECS with AWS KMS, data encrypted and released only after policy checks | ~60 min |

### Reference Material
- [NATO STANAGs](documents/nato-stanags/README.md) -- Standards underpinning data-centric security
- [Gap Analysis](NEXT-STEPS.md) -- What the current architectures cover and what's still needed
- [Repository Structure](STRUCTURE.md) -- How this project is organized

## Key concepts

**Data-Centric Security (DCS)** -- Security embedded in the data itself, not the perimeter. Protection persists wherever data travels.

**Zero Trust Data Format (ZTDF)** -- NATO-standardized (March 2024) data wrapper built on OpenTDF. Supports secure cross-border data sharing with persistent access controls.

**Federated Key Management** -- Multiple organizations operate independent Key Access Servers (KAS) that collaboratively manage access to shared data while each maintains sovereignty.

## References

- [OpenTDF Specification](https://github.com/opentdf/spec) - Official TDF standard
- [OpenTDF Platform](https://github.com/opentdf/platform) - Reference implementation
- ACP-240
