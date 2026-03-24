# The problem DCS solves

## A real-world scenario

Imagine three NATO nations -- Poland, the UK, and the US -- are running a joint military operation. Poland collects sensor data from the border region. The UK enriches it with their own intelligence. The US adds their analysis. Each nation needs to share data with the others, but with controls:

- Some data is SECRET and should only be seen by people with SECRET clearance
- Some data is UK-EYES-ONLY and shouldn't leave UK systems
- Some data requires a special codeword (like "WALL") to access
- Each nation uses a different classification system (UK uses SECRET, Poland uses NATO SECRET, the US uses Impact Levels)

### What goes wrong with traditional security

With perimeter-based security, you'd set up secure networks between the three nations. But:

**Problem 1: Once data is on a shared network, everyone on that network can see it.** There's no way to say "this file is UK-EYES-ONLY" if the network grants access to everyone.

**Problem 2: If data gets copied outside the secure network, it's unprotected.** Someone saves a file to a USB drive, emails it, or copies it to a different system, and the network perimeter can't help.

**Problem 3: You can't express complex rules.** "Allow access if the person has SECRET clearance AND is from the UK or US AND has the WALL codeword" -- networks don't understand this. They know IP addresses and ports, not clearances and codewords.

**Problem 4: Each nation has different systems.** Poland's classification system is different from the UK's, which is different from the US's. There's no common language for security rules.

## What DCS changes
With data-centric security:

| Problem | DCS Solution |
|---------|-------------|
| Everyone on the network can see everything | Each piece of data has labels that control who can see it |
| Copied data loses protection | Labels and encryption travel with the data |
| Complex access rules | Attribute-based policies evaluate clearance, nationality, codewords |
| Different national systems | Standardized label format (NATO STANAG 4774) maps between systems |

## The key insight

Security should be a property of the data, not a property of the network.

When you send a letter through the post, you don't rely on the postal service to keep it private -- you seal the envelope. DCS seals your data.
In the three labs that follow, you'll build each layer of this protection on AWS, starting with labels (the envelope markings), then access control (checking credentials before opening), then encryption (sealing the envelope so only authorized people can open it).
