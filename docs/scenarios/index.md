# Operational scenarios

Scenarios are **problem definitions** describing operational requirements for data-centric security in coalition environments. Each includes actors, operational flow, constraints, technical challenges, and measurable acceptance criteria.

Scenarios are deliberately **solution-agnostic**: they describe what needs to be solved, not how.

| # | Scenario | Coverage | Key Challenge |
|---|----------|----------|---------------|
| 01 | [Coalition Strategic Sharing](01-coalition-strategic-sharing.md) | High | Multi-nation intelligence sharing with federated key management |
| 02 | [Tactical Unit-to-Unit](02-tactical-unit-to-unit.md) | None | DDIL environments without strategic infrastructure |
| 03 | [Legacy System Retrofit](03-legacy-system-dcs-retrofit.md) | None | Adding DCS to existing applications |
| 04 | [Cross-Domain Sanitisation](04-cross-domain-automated-sanitisation.md) | None | Automated content redaction across classification domains |
| 05 | [Mission-Based Coalition Sharing](05-mission-based-coalition-sharing.md) | Partial | Time-limited, mission-scoped data access |
| 06 | [Intelligence Fusion Centre](06-intelligence-fusion-centre.md) | Partial | Multi-source intelligence fusion with provenance |
| 07 | [Coalition Air Operations](07-coalition-air-operations.md) | Minimal | Real-time data with safety-critical overrides |
| 08 | [Maritime Domain Awareness](08-maritime-domain-awareness.md) | Minimal | Sensor fusion with compartmentalized access |
| 09 | [Disaster Recovery and Backup](09-disaster-recovery-backup.md) | Partial | Backup lifecycle with encrypted data |

!!! info "Coverage column"
    Coverage indicates how well the current [reference architectures](../architectures/index.md) address each scenario. See the [gap analysis](../NEXT-STEPS.md) for details on what's missing.
