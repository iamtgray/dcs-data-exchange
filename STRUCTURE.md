# Repository Structure Guide

## Quick Reference

```
dcs-data-exchange/
├── scenarios/              # WHAT needs to be solved
├── solutions/              # HOW it could be solved
├── architectures/          # DETAILED implementation designs
└── .kiro/steering/         # Knowledge base for AI assistants
```

## File Organization

### Scenarios (Problem Definitions)

**Location**: `scenarios/XX-name.md`

**Purpose**: Define operational requirements and challenges without assuming solutions

**Format**:
- Overview and actors
- Scenario flow
- Operational constraints
- Technical challenges
- **Acceptance criteria** (measurable, testable)
- Success metrics
- Out of scope

**Example**: `scenarios/01-coalition-strategic-sharing.md`

### Solutions (Approach Options)

**Location**: `solutions/XX-scenario-name/option-Y-approach.md`

**Purpose**: Propose and analyze different approaches to solve scenario challenges

**Format**:
- Scenario reference
- How it works
- Advantages / Disadvantages
- Acceptance criteria coverage
- Technology stack
- Implementation complexity
- Operational fit

**Example**: `solutions/01-strategic/option-1-tdf-anyof.md`

**Cross-cutting**: `solutions/cross-cutting/` for solutions spanning multiple scenarios

### Architectures (Technical Designs)

**Location**: `architectures/XX-name/`

**Purpose**: Detailed technical design implementing a solution

**Structure**:
```
architectures/01-strategic-tdf-federation/
├── overview.md          # High-level architecture + diagrams
├── components.md        # Component specifications
├── sequences.md         # Sequence diagrams
├── deployment.md        # Deployment models
├── security.md          # Security analysis
└── testing.md           # Test plans
```

### Knowledge Base

**Location**: `.kiro/steering/`

**Purpose**: Domain knowledge automatically included in AI assistant context

**Files**:
- `data-centric-security.md` - DCS principles and levels
- `ztdf-trusted-data-format.md` - ZTDF/TDF comprehensive guide
- `scenario-development.md` - Workflow and format guide

## Naming Conventions

### Scenarios
- Format: `XX-descriptive-name.md`
- Example: `01-coalition-strategic-sharing.md`
- Sequential numbering

### Solutions
- Format: `option-Y-approach-name.md`
- Example: `option-1-tdf-anyof.md`
- Organized in scenario folders

### Architectures
- Format: `XX-descriptive-name/`
- Example: `01-strategic-tdf-federation/`
- Matches solution numbering

## Workflow

```
1. SCENARIO          2. SOLUTIONS           3. ARCHITECTURE        4. VALIDATE
   (Problem)            (Options)              (Design)               (Test)
      │                    │                      │                     │
      ├─ Actors           ├─ Option 1            ├─ Components         ├─ AC1 ✓
      ├─ Flow             ├─ Option 2            ├─ Sequences          ├─ AC2 ✓
      ├─ Constraints      ├─ Option 3            ├─ Deployment         ├─ AC3 ✗
      ├─ Challenges       └─ Comparison          ├─ Security           └─ Iterate
      └─ Acceptance           ↓                  └─ Testing
         Criteria          Select Best               ↓
                              ↓                   Implement
                          Design Arch
```

## Current State

### Scenarios (Defined)
- ✅ 01: Coalition Strategic Intelligence Sharing
- ✅ 02: Tactical Unit-to-Unit Communications

### Solutions (In Progress)
- ✅ Cross-cutting: Offline Key Management Options (6 options analyzed)
- ⏳ 01-strategic: TDF-based solutions (pending)
- ⏳ 02-tactical: PKI-based solutions (pending)

### Architectures (Planned)
- ⏳ 01-strategic-tdf-federation
- ⏳ 02-tactical-pki
- ⏳ Gateway (tactical-to-strategic transition)

## Key Principles

### Scenarios
- **Solution-agnostic**: Describe problems, not solutions
- **Measurable**: Acceptance criteria must be testable
- **Realistic**: Based on actual operational needs
- **Constrained**: Include real-world limitations

### Solutions
- **Multiple options**: Explore alternatives
- **Honest trade-offs**: Document pros and cons
- **Criteria mapping**: Show which AC are met
- **Operational focus**: Will it work in practice?

### Architectures
- **Detailed**: Enough to implement
- **Diagrammed**: Visual communication
- **Validated**: Maps to acceptance criteria
- **Practical**: Considers deployment and operations

## Working with AI Assistants

The `.kiro/steering/` files provide context automatically. When starting work:

**New scenario**: "Let's create a scenario for [context]. Follow the scenario format."

**Explore solutions**: "For Scenario X, let's brainstorm solutions. I'm interested in [approach]."

**Design architecture**: "Design the architecture for [solution]. Start with overview."

**Validate**: "Check [architecture] against Scenario X acceptance criteria."

## Version Control

- Scenarios evolve as requirements clarify
- Solutions added as new approaches discovered
- Architectures refined through iteration
- Use meaningful commit messages

Track evolution through git history.

---

*This structure separates concerns: problems (scenarios), approaches (solutions), and implementations (architectures).*
