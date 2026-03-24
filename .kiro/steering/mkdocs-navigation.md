---
inclusion: fileMatch
fileMatchPattern: "mkdocs.yml"
description: Rules for maintaining the mkdocs.yml navigation structure when adding or modifying documentation pages
---

# MkDocs Navigation Management

## Overview

This project uses MkDocs with the Material theme to generate a documentation site. The navigation structure is defined in `mkdocs.yml` under the `nav:` key. When you create, move, or delete documentation files under `docs/`, you must keep the `nav` section in sync.

## Navigation Structure

The nav is organised into these top-level sections:

1. **Home** -- `index.md`
2. **What is Data-Centric Security?** -- `labs/overview/` (conceptual content)
3. **Reference Architectures** -- `architectures/` (AWS implementation architectures)
4. **Operational Scenarios** -- `scenarios/` (problem definitions, numbered 01-09)
5. **Solution Options** -- `solutions/` (solution approaches organised by scenario or cross-cutting)
6. **Hands-On Labs** -- `labs/` (lab1, lab2, lab3 with step-by-step guides)
7. **Reference** -- STANAGs, gap analysis, repo structure

## Rules for Updating Navigation

### When adding a new documentation page

1. Create the markdown file under the appropriate `docs/` subdirectory
2. Add a corresponding entry in the `nav:` section of `mkdocs.yml` in the correct section
3. Use the existing naming conventions:
   - Scenarios: `"01: Short Title": scenarios/01-filename.md`
   - Solutions: Nested under scenario-specific or cross-cutting folders
   - Labs: Step-by-step with `"Step N: Title": labs/labN/stepN-name.md`
   - Architectures: Grouped by level with Overview and Terraform sub-pages

### When adding a new solution

Solutions go under the "Solution Options" nav section. They are organised as:

- **Cross-cutting solutions** (span multiple scenarios): `solutions/cross-cutting/`
- **Scenario-specific solutions**: `solutions/XX-name/` where XX matches the scenario number

Each solution folder should have an `index.md` and individual option files. The nav entry should be a nested group:

```yaml
- "Solution Group Name":
  - solutions/XX-name/index.md
  - "Option Title": solutions/XX-name/option-file.md
```

### When adding a new scenario

Add the scenario file to `docs/scenarios/` with the next sequential number. Add a nav entry in the "Operational Scenarios" section following the pattern:

```yaml
- "NN: Scenario Short Title": scenarios/NN-scenario-slug.md
```

### Index pages

Folders that contain multiple documents should have an `index.md` that lists and links to all documents in that folder. When adding new documents to a folder, update the folder's `index.md` as well as `mkdocs.yml`.

Also update `docs/solutions/index.md` when adding new solution documents -- it serves as the landing page for the Solution Options section.

### Do not change

- The `theme`, `markdown_extensions`, or `site_*` configuration unless explicitly asked
- The ordering of top-level nav sections
- Lab step numbering (labs are sequential and referenced by step number)
