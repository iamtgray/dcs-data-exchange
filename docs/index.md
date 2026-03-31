# Data-Centric Security on AWS

Security embedded in the data itself -- not the network, not the perimeter. Protection that persists wherever data travels, whoever holds it.

This site covers **concepts, hands-on labs, reference architectures, and operational scenarios** for implementing Data-Centric Security (DCS) in coalition and defence environments using AWS.

---

## Where should I start?

??? question "I'm new to DCS and want to understand the basics"
    Start with **[What is Data-Centric Security?](labs/overview/index.md)** -- a plain-language introduction covering the problem DCS solves, the three protection levels, and how NATO standards fit in.

    Then try **[Lab 1](labs/lab1/index.md)** (~30 min) to build a working DCS Level 1 system on AWS and see the concepts in action.

??? question "I want to build something on AWS"
    The **[Hands-On Labs](labs/index.md)** walk you through building all three DCS levels step by step:

    | Lab | What you build | Time |
    |-----|---------------|------|
    | [Lab 1: Labeling](labs/lab1/index.md) | S3 objects with security tags, Lambda data service, CloudTrail audit | ~30 min |
    | [Lab 2: Access Control](labs/lab2/index.md) | Cognito identity, Verified Permissions with Cedar policies, ABAC enforcement | ~45 min |
    | [Lab 3: Encryption](labs/lab3/index.md) | OpenTDF on ECS Fargate, KMS key management, policy-gated decryption | ~60 min |

    When you're ready for production, the **[Reference Architectures](architectures/index.md)** provide STANAG-compliant designs with Terraform.

??? question "I'm planning an integration or evaluating DCS for a programme"
    Start with the **[Operational Scenarios](scenarios/index.md)** -- 17 problem definitions covering coalition sharing, tactical operations, legacy systems, and emerging domains. Each includes actors, constraints, and measurable acceptance criteria.

    Then review **[Solution Patterns](solutions/index.md)** for approach options, and **[Reference Architectures](architectures/index.md)** for concrete AWS implementations.

??? question "I need to understand the NATO standards"
    See **[NATO Standards and DCS](labs/overview/nato-standards.md)** for how STANAG 4774, 4778, ZTDF, and ACP-240 relate to each other, or the full **[NATO STANAGs Reference](documents/nato-stanags/README.md)** for detailed coverage of each standard.

---

## Key concepts

**Data-Centric Security (DCS)**
:   Security embedded in the data itself. Protection persists wherever data travels -- across networks, organizations, and classification domains.

**The Three DCS Levels**
:   **Level 1** labels data with classification metadata. **Level 2** enforces access control based on those labels. **Level 3** encrypts data so only authorized parties can decrypt it.

**Zero Trust Data Format (ZTDF)**
:   NATO-standardized (March 2024) data wrapper built on OpenTDF. Combines labels, encryption, and federated key management into a single interoperable format.

**Federated Key Management**
:   Each nation operates its own Key Access Server (KAS). Data can require approval from one KAS (AnyOf) or all of them (AllOf) before decryption.

---

## References

- [OpenTDF Specification](https://github.com/opentdf/spec) -- Official TDF standard
- [OpenTDF Platform](https://github.com/opentdf/platform) -- Reference implementation
- [ACP-240](documents/nato-stanags/README.md#acp-240-data-centric-security-interoperability) -- FVEY/CCEB data-centric security interoperability standard (adopted by NATO)
- [NATO STANAGs](documents/nato-stanags/README.md) -- Search the [NSO standards database](https://nso.nato.int/nso/nsdd/main/standards) by standard number
