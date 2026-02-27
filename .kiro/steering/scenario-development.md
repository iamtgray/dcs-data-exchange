---
inclusion: auto
description: Guide for developing and working with data-centric security scenarios, solutions, and architectures
---

# Scenario Development and Architecture Workflow

## Purpose

This guide explains how to work with scenarios, solutions, and architectures in this repository. It provides structure for exploring data-centric security challenges and designing practical solutions.

## Repository Structure

```
dcs-data-exchange/
├── scenarios/           # Problem definitions with acceptance criteria
│   ├── 01-coalition-strategic-sharing.md
│   ├── 02-tactical-unit-to-unit.md
│   └── XX-scenario-name.md
├── solutions/           # Solution options for scenarios
│   ├── 01-strategic/
│   │   ├── option-1-tdf-anyof.md
│   │   ├── option-2-tdf-allof.md
│   │   └── comparison.md
│   ├── 02-tactical/
│   │   ├── option-1-pki-certificates.md
│   │   ├── option-2-pre-shared-keys.md
│   │   └── comparison.md
│   └── cross-cutting/
│       └── dual-mode-encryption.md
└── architectures/       # Detailed technical architectures
    ├── 01-strategic-tdf-federation/
    │   ├── overview.md
    │   ├── components.md
    │   ├── sequences.md
    │   └── deployment.md
    └── 02-tactical-pki/
        ├── overview.md
        ├── components.md
        └── deployment.md
```

## Scenario Format

Scenarios describe **problems**, not solutions. They are solution-agnostic and focus on operational requirements.

### Required Sections

1. **Overview**: Brief description of the scenario
2. **Actors**: Organizations/entities involved with their constraints
3. **Scenario Flow**: Step-by-step description of data sharing needs
4. **Operational Constraints**: Real-world limitations (connectivity, infrastructure, etc.)
5. **Technical Challenges**: Specific problems that need solving
6. **Acceptance Criteria**: Measurable success criteria (checklist format)
7. **Success Metrics**: Quantitative performance targets
8. **Out of Scope**: What this scenario doesn't cover
9. **Related Scenarios**: Links to complementary scenarios

### Acceptance Criteria Format

Use testable, measurable criteria in checklist format:

```markdown
### AC1: Cross-Border Data Sharing
- [ ] Polish sensor data encrypted once can be decrypted by authorized UK and US personnel
- [ ] No need to create separate encrypted copies for each nation
- [ ] Data protection persists regardless of storage location
```

Each criterion should be:
- **Specific**: Clear what needs to be achieved
- **Measurable**: Can be tested/verified
- **Achievable**: Technically feasible
- **Relevant**: Addresses a real operational need
- **Testable**: Can be demonstrated in a prototype or test

### Naming Convention

Scenarios are numbered sequentially: `01-scenario-name.md`, `02-scenario-name.md`

Use descriptive names that indicate the operational context:
- `01-coalition-strategic-sharing.md` (strategic level, multiple nations)
- `02-tactical-unit-to-unit.md` (tactical level, DDIL environment)
- `03-cross-domain-transfer.md` (classification level transitions)

## Solution Format

Solutions propose **approaches** to solve scenario challenges. Multiple solutions can address the same scenario.

### Required Sections

1. **Scenario Reference**: Which scenario(s) this solves
2. **Overview**: High-level approach
3. **How It Works**: Detailed explanation of the solution
4. **Advantages**: Benefits of this approach
5. **Disadvantages**: Limitations and trade-offs
6. **Acceptance Criteria Coverage**: Which AC from scenario are met
7. **Technology Stack**: Specific technologies/standards used
8. **Implementation Complexity**: Effort required (Low/Medium/High)
9. **Operational Fit**: How well it matches real-world operations

### Solution Organization

Solutions are organized by scenario:
- `solutions/01-strategic/` - Solutions for Scenario 01
- `solutions/02-tactical/` - Solutions for Scenario 02
- `solutions/cross-cutting/` - Solutions that span multiple scenarios

Each scenario folder should include:
- Individual solution options (`option-1-name.md`, `option-2-name.md`)
- Comparison document (`comparison.md`) analyzing trade-offs

### Naming Convention

Solutions use descriptive names indicating the approach:
- `option-1-tdf-anyof.md` (TDF with AnyOf key access)
- `option-2-pki-certificates.md` (PKI-based approach)
- `option-3-hybrid-mode.md` (Combination approach)

## Architecture Format

Architectures provide **detailed technical designs** implementing a solution.

### Required Sections

1. **Solution Reference**: Which solution this implements
2. **Overview**: Architecture summary with diagrams
3. **Components**: Detailed component descriptions
4. **Interactions**: Sequence diagrams and data flows
5. **Deployment Models**: How to deploy in different environments
6. **Security Considerations**: Threat model and mitigations
7. **Performance Analysis**: Scalability and performance characteristics
8. **Implementation Guide**: Step-by-step implementation instructions
9. **Testing Strategy**: How to verify acceptance criteria

### Architecture Organization

Architectures are organized by solution approach:
- `architectures/01-strategic-tdf-federation/` - TDF-based strategic architecture
- `architectures/02-tactical-pki/` - PKI-based tactical architecture

Each architecture folder should include:
- `overview.md` - High-level architecture and diagrams
- `components.md` - Detailed component specifications
- `sequences.md` - Sequence diagrams for key flows
- `deployment.md` - Deployment models and configurations
- `security.md` - Security analysis and threat model
- `testing.md` - Test plans and verification procedures

## Workflow: From Scenario to Architecture

### Step 1: Define Scenario
1. Identify operational need or use case
2. Document actors, constraints, and flow
3. Define technical challenges
4. Write acceptance criteria (measurable, testable)
5. Review with stakeholders for realism

### Step 2: Explore Solutions
1. Brainstorm multiple solution approaches
2. Document each option with pros/cons
3. Analyze how each addresses acceptance criteria
4. Compare solutions in `comparison.md`
5. Select preferred solution(s) for architecture

### Step 3: Design Architecture
1. Create detailed technical design for selected solution
2. Define components, interfaces, and interactions
3. Create sequence diagrams for key flows
4. Document deployment models
5. Analyze security and performance
6. Map architecture to acceptance criteria

### Step 4: Validate
1. Review architecture against acceptance criteria
2. Identify gaps or unmet criteria
3. Iterate on architecture or revisit solution
4. Document trade-offs and decisions

## Working with AI Assistants

When working with AI assistants on this repository:

### Starting a New Scenario
```
"I want to create a new scenario for [operational context]. 
The key challenge is [problem description]. 
Let's develop it following the scenario format."
```

### Exploring Solutions
```
"For Scenario [number], let's brainstorm solution options. 
I'm particularly interested in [approach/technology]. 
Create solution documents for comparison."
```

### Designing Architecture
```
"Let's design the architecture for [solution name]. 
Start with the overview and component diagram. 
Focus on [specific aspect]."
```

### Reviewing Against Criteria
```
"Review the [architecture/solution] against the acceptance criteria 
for Scenario [number]. Which criteria are met? Which need work?"
```

## Best Practices

### Scenario Development
- **Start with real operations**: Base scenarios on actual operational needs
- **Be specific**: Vague scenarios lead to vague solutions
- **Include constraints**: Real-world limitations drive design decisions
- **Write testable criteria**: If you can't test it, you can't verify it
- **Avoid solution bias**: Don't assume a solution in the scenario

### Solution Exploration
- **Consider multiple options**: Don't settle on first idea
- **Document trade-offs**: Every solution has pros and cons
- **Be honest about limitations**: Acknowledge what doesn't work
- **Think operationally**: Will this work in the real world?
- **Consider existing standards**: Leverage proven technologies

### Architecture Design
- **Start simple**: Minimum viable architecture first
- **Diagram everything**: Pictures communicate better than text
- **Think about failure**: How does it break? How do you recover?
- **Consider scale**: Will it work with 10 nations? 100 users? 1000?
- **Document decisions**: Why did you choose this approach?

## Scenario Relationships

Scenarios can be:
- **Sequential**: Scenario 02 follows Scenario 01 (tactical → strategic)
- **Complementary**: Different aspects of same operation
- **Alternative**: Different operational contexts for similar problems
- **Layered**: Different classification levels or security domains

Document relationships in the "Related Scenarios" section.

## Evolution and Iteration

Scenarios, solutions, and architectures evolve:
- New operational needs emerge → New scenarios
- Better approaches discovered → New solutions
- Technology advances → Updated architectures
- Lessons learned → Refined acceptance criteria

Version control (git) tracks this evolution. Use meaningful commit messages describing changes and rationale.

## Current Scenarios

### Scenario 01: Coalition Strategic Intelligence Sharing
**Focus**: Multi-nation intelligence sharing with reliable connectivity  
**Key Challenges**: Federated key management, classification mapping, policy enforcement  
**Status**: Acceptance criteria defined, solutions in development

### Scenario 02: Tactical Unit-to-Unit Communications
**Focus**: Forward-deployed units in DDIL environments  
**Key Challenges**: Offline encryption/decryption, certificate validation, tactical-to-strategic transition  
**Status**: Acceptance criteria defined, solutions in development

## Questions to Ask

When developing scenarios:
- What is the operational context?
- Who are the actors and what are their constraints?
- What data needs to be shared and why?
- What are the security requirements?
- What are the connectivity/infrastructure limitations?
- How do we measure success?

When exploring solutions:
- Does this address the scenario's challenges?
- What are the trade-offs?
- Is this operationally feasible?
- What technologies/standards does it use?
- How complex is implementation?
- Which acceptance criteria does it meet?

When designing architectures:
- What are the components and how do they interact?
- How is it deployed?
- What are the failure modes?
- How does it scale?
- How do we test it?
- Does it meet all acceptance criteria?

---

*This guide helps maintain consistency and quality across scenario development, solution exploration, and architecture design.*
