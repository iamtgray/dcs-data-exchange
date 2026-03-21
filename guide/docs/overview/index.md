# What is Data-Centric Security?

Data-Centric Security (DCS) is a way of protecting information by embedding security into the data itself, rather than relying on the network or systems around it.

Think of it this way:

- **Traditional security** is like putting your valuables in a locked building. The building has walls, doors, guards. But if someone gets past those defences, they can take whatever they want.
- **Data-centric security** is like putting each valuable item in its own locked box with a label that says who can open it. Even if someone breaks into the building, they still can't open the boxes unless they have the right credentials.

## Why does this matter?

In the real world, data doesn't stay in one place. It gets:

- Shared between organizations (e.g. NATO allies sharing intelligence)
- Copied to cloud storage
- Sent over networks you don't control
- Backed up to systems managed by different teams
- Moved between classification domains

Once data leaves your network, perimeter security can't help you. DCS means your data carries its own protection wherever it goes.

## The three things DCS does

DCS has three core capabilities that build on each other:

### 1. Control (Labeling)
Attach machine-readable security labels to your data. These labels describe:

- How classified the data is (UNCLASSIFIED, SECRET, TOP SECRET)
- Who is allowed to see it (which countries, which teams)
- What special access is needed (codewords, programs)

Labels are metadata - structured information that computers can read and act on.

### 2. Protect (Access Control)
Use those labels to make access decisions. When someone asks for data, the system checks:

- Does this person's clearance level meet the data's classification?
- Is this person's nationality on the releasability list?
- Does this person have the required special access?

If the answer to all of these is yes, access is granted. Otherwise, it's denied.

### 3. Share (Encryption + Federation)
Encrypt the data so protection persists even outside your systems. Each organization manages its own keys, but they can share data by including multiple key references in a single encrypted package. Any authorized organization can decrypt independently.

These three capabilities map directly to the **three DCS levels** we'll explore next.

## The learning path

This workshop teaches DCS in two passes:

1. **Concepts (the labs)**: Build each DCS level using straightforward AWS services. S3 tags for labels, Lambda for access checks, OpenTDF for encryption. You'll understand what each level does and why it matters.

2. **Compliance (the architecture references)**: See how the same concepts are implemented to NATO STANAG standards. Structured XML labels, cryptographic binding, formal classification vocabularies. This is what production coalition systems look like.

You don't need to do both passes. If you just want to understand DCS, the labs are enough. If you need to build something STANAG-compliant, the architecture references give you the blueprint.
