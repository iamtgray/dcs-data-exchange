# Operational Scenarios

Scenarios are **solution-agnostic problem definitions** for data-centric security in coalition environments. Each includes actors, operational flow, constraints, technical challenges, and measurable acceptance criteria.

Use these to understand what DCS needs to solve, evaluate coverage gaps, or scope a demonstration.

---

## By theme

### Coalition intelligence and strategic sharing

Sharing classified intelligence across national boundaries with different classification systems, clearance levels, and trust relationships.

| # | Scenario | Coverage | Key Challenge |
|---|----------|----------|---------------|
| 01 | [Coalition Strategic Sharing](01-coalition-strategic-sharing.md) | High | Multi-nation intelligence sharing with federated key management |
| 05 | [Mission-Based Coalition Sharing](05-mission-based-coalition-sharing.md) | Partial | Time-limited, mission-scoped data access |
| 06 | [Intelligence Fusion Centre](06-intelligence-fusion-centre.md) | Partial | Multi-source intelligence fusion with provenance |
| 12 | [Cyber Threat Intelligence Sharing](12-cyber-threat-intelligence-sharing.md) | None | Multi-level CTI with machine-speed automated sharing |
| 15 | [Counter-Hybrid Threat Intelligence](15-counter-hybrid-threat-intelligence.md) | None | Civil-military fusion and disinformation response |

### Tactical and real-time operations

Time-critical data sharing where latency matters, connectivity is unreliable, and safety-of-life decisions depend on data access.

| # | Scenario | Coverage | Key Challenge |
|---|----------|----------|---------------|
| 02 | [Tactical Unit-to-Unit](02-tactical-unit-to-unit.md) | None | DDIL environments without strategic infrastructure |
| 07 | [Coalition Air Operations](07-coalition-air-operations.md) | Minimal | Real-time data with safety-critical overrides |
| 08 | [Maritime Domain Awareness](08-maritime-domain-awareness.md) | Minimal | Sensor fusion with compartmentalized access |
| 10 | [Sensor-to-Shooter Data Chain](10-sensor-to-shooter-data-chain.md) | None | Automated classification downgrade and kill chain latency |

### Emerging and specialist domains

Newer operational areas where DCS intersects with AI, space, industrial partnerships, and military messaging systems.

| # | Scenario | Coverage | Key Challenge |
|---|----------|----------|---------------|
| 11 | [Military Messaging (STANAG 4406)](11-military-messaging-stanag-4406.md) | None | Paragraph-level classification within military messages |
| 13 | [Space Domain Awareness](13-space-domain-awareness.md) | None | Federated space data sharing across 17+ nations |
| 14 | [AI/ML Data Sharing](14-ai-ml-data-sharing.md) | None | Federated learning with data sovereignty and provenance |

### Enterprise, lifecycle, and legacy systems

Retrofitting existing systems, managing data across its lifecycle, and protecting industrial supply chains.

| # | Scenario | Coverage | Key Challenge |
|---|----------|----------|---------------|
| 03 | [Legacy System Retrofit](03-legacy-system-dcs-retrofit.md) | None | Adding DCS to existing applications |
| 04 | [Cross-Domain Sanitisation](04-cross-domain-automated-sanitisation.md) | None | Automated content redaction across classification domains |
| 09 | [Disaster Recovery and Backup](09-disaster-recovery-backup.md) | Partial | Backup lifecycle with encrypted data |
| 16 | [Defence Industrial Base](16-defence-industrial-base.md) | None | Export control enforcement (ITAR/EAR) and through-life support |
| 17 | [Multinational Logistics](17-multinational-logistics.md) | None | Aggregation sensitivity and DDIL-resilient forward logistics |

---

## DCS Level Scenarios

These define the acceptance criteria for each DCS protection level -- use them to validate an architecture against a specific level.

| Level | Scenario | Key Focus |
|---|----------|-----------|
| 1 | [Basic Labelling](dcs-levels/level-1-basic-labelling.md) | Mandatory classification and releasability labels (STANAG 4774) |
| 2 | [Enhanced Labelling](dcs-levels/level-2-enhanced-labelling.md) | Minimum Essential Metadata and ABAC policy enforcement |
| 3 | [Cryptographic Protection](dcs-levels/level-3-cryptographic-protection.md) | Envelope encryption with per-classification keys and HMAC integrity |

!!! info "Coverage column"
    Coverage indicates how well the current [reference architectures](../architectures/index.md) address each scenario. See the [gap analysis](../NEXT-STEPS.md) for details on what's missing.
