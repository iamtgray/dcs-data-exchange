# Data-Centric Security on AWS

## Welcome

This workshop teaches you how to build **Data-Centric Security (DCS)** on AWS. You'll work through three hands-on labs, each one building on the last, until you have a working understanding of how to protect data so that security travels with the data itself.

By the end, you'll understand:

- Why traditional perimeter security isn't enough when data crosses organizational boundaries
- How to label data with security metadata so systems can make access decisions
- How to use policies to control who sees what, based on their attributes
- How to encrypt data so that even infrastructure administrators can't read it without authorization
- What NATO STANAG compliance looks like and how to get there

## How this workshop approaches DCS

This workshop takes a deliberate basics-first approach. We start by teaching the core DCS concepts using simple, approachable AWS services -- S3 tags for labels, Lambda for access checks, DynamoDB for data. This lets you focus on understanding *what* DCS does and *why* it matters, without getting tangled in XML schemas and cryptographic signatures on day one.

Once you've built that foundation, we introduce NATO STANAG compliance -- the formal standards that make DCS interoperable across nations and organizations. You'll see how the basic concepts you already understand map to structured XML labels (STANAG 4774), cryptographic binding (STANAG 4778), and the Zero Trust Data Format (ZTDF).

Think of it as learning to drive before learning the highway code. Both matter, but the order matters too.

## Who is this for?

- Cloud architects and engineers who need to understand DCS
- Defence and government teams evaluating DCS for coalition data sharing
- Anyone curious about how NATO-standard data protection works in practice

## What you'll need

- An **AWS account** with administrator access
- Basic familiarity with the **AWS Console** (S3, IAM, Lambda)
- About **2-3 hours** for all three labs (you can do them independently)
- No prior DCS knowledge required - we'll explain everything as we go

## The Three Labs

| Lab | DCS Level | What You'll Build | Time |
|-----|-----------|-------------------|------|
| **Lab 1** | Level 1 - Labeling | S3 objects with security tags, a Lambda that checks labels before granting access | ~30 min |
| **Lab 2** | Level 2 - Access Control | A proper policy engine (Amazon Verified Permissions) that evaluates user attributes against data labels | ~45 min |
| **Lab 3** | Level 3 - Encryption | OpenTDF platform on ECS with AWS KMS, where data is encrypted and only released after policy checks | ~60 min |

Each lab is self-contained. You can do just Lab 1 to understand the basics, or work through all three to see the full picture.

!!! info "Basic concepts first, then STANAG compliance"
    The labs teach DCS using simplified AWS implementations. Once you've completed them, the architecture reference documents show how to make each level NATO STANAG-compliant, with proper 4774 XML labels, 4778 cryptographic binding, and ZTDF encryption. The basic labs give you the "why"; the architecture references give you the "how it's done for real."

## How this workshop is structured

Each lab follows the same pattern:

1. **Context** - What we're building and why
2. **Step-by-step instructions** - Exactly what to create in AWS
3. **Test it** - Try different scenarios to see DCS in action
4. **What you learned** - Key takeaways

Ready? Start with **[What is Data-Centric Security?](overview/index.md)** to understand the concepts, or jump straight to **[Lab 1](lab1/index.md)** if you want to get building.
