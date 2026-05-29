# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a documentation-only repository (no build/test/lint commands) for designing secure multi-party data sharing architectures using Data-Centric Security (DCS), Zero Trust Data Format (ZTDF), and Trusted Data Format (TDF) in coalition/NATO defense contexts.

## Repository Structure

The repo follows a three-stage workflow: **Scenario → Solution → Architecture**.

- `scenarios/` — Solution-agnostic problem definitions with measurable acceptance criteria. Named `XX-descriptive-name.md`.
- `solutions/` — Approach options organized by scenario (`solutions/XX-name/option-Y-approach.md`) or as `cross-cutting/` for multi-scenario concerns. These describe general technology approaches, NOT specific implementations.
- `architectures/` — Concrete implementation designs (exact specs, real deployment data). Only created when backed by real experience or vendor docs. Organized as `XX-name/` directories with `overview.md`, `components.md`, `sequences.md`, `deployment.md`, `security.md`, `testing.md`.
- `documents/` — Local-only reference documents (gitignored). Never committed to the public repo.
- `.kiro/steering/` — Domain knowledge files for AI assistants (auto-included by Kiro):
  - `data-centric-security.md` — DCS principles, three DCS levels, NATO context
  - `ztdf-trusted-data-format.md` — ZTDF/TDF guide: encryption workflows, federated key management, ABAC, integration patterns
  - `scenario-development.md` — Format requirements and workflow guide for all three document types

## Key Distinctions

**Solution vs Architecture**: Solutions describe conceptual approaches (technology categories, high-level workflows, pros/cons). Architectures specify concrete implementations (hardware models, software versions, network topology, real performance data). Do not conflate these.

**Scenarios are solution-agnostic**: They describe problems and acceptance criteria, never prescribe a technology or approach.

## Content Conventions

- Acceptance criteria use checklist format (`- [ ]`) and must be specific, measurable, and testable
- Scenarios are numbered sequentially: `01-`, `02-`, etc.
- Solutions within a scenario: `option-1-name.md`, `option-2-name.md`, plus `comparison.md`
- Success metrics use qualitative assessments rather than fabricated quantitative targets
- Do not invent hardware specs, software versions, cost estimates, or performance numbers without real data

## Domain Context

Key concepts used throughout:
- **ZTDF/TDF**: Data packaging format defined in ACP-240 (CCEB/Five Eyes), built on OpenTDF, enabling encrypted data sharing with persistent access controls
- **KAS (Key Access Server)**: Manages key encryption keys, enforces ABAC policies, provides audit trails
- **Federated Key Management**: Each nation operates independent KAS while collaboratively managing shared data access
- **AnyOf vs AllOf**: Key access patterns — AnyOf lets any single KAS grant access; AllOf requires all KAS to approve
- **DDIL**: Denied, Degraded, Intermittent, Limited connectivity environments (tactical scenarios)
- **DCS Levels**: Level 1 (labeling/metadata), Level 2 (access control), Level 3 (encryption)
- **NATO STANAGs**: ADatP-4774 (labels), ADatP-4778 (binding), STANAG 5663 (ICAM/ABAC)
- **CCEB standards**: ACP-240 (DCS interoperability, includes ZTDF) -- cooperative arrangement with NATO
