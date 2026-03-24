# Hands-on labs

This workshop teaches you how to build **Data-Centric Security (DCS)** on AWS. You'll work through three hands-on labs, each building on the last, until you have a working understanding of how to protect data so that security travels with the data itself.

By the end, you'll know:

- Why perimeter security falls short when data crosses organizational boundaries
- How to label data with security metadata so systems can make access decisions
- How to use policies to control who sees what, based on their attributes
- How to encrypt data so that even infrastructure administrators can't read it without authorization
- What NATO STANAG compliance looks like and how to get there

## The three labs

| Lab | DCS Level | What You'll Build | Time |
|-----|-----------|-------------------|------|
| [Lab 1](lab1/index.md) | Level 1 - Labeling | S3 objects with security tags, a Lambda that returns data with its labels | ~30 min |
| [Lab 2](lab2/index.md) | Level 2 - Access Control | A policy engine (Amazon Verified Permissions) evaluating user attributes against data labels | ~45 min |
| [Lab 3](lab3/index.md) | Level 3 - Encryption | OpenTDF platform on ECS with AWS KMS, data encrypted and released only after policy checks | ~60 min |

Each lab is self-contained. You can do just Lab 1 to understand the basics, or work through all three to see the full picture.

## What you need

- An **AWS account** with administrator access
- Basic familiarity with the **AWS Console** (S3, IAM, Lambda)
- About **2-3 hours** for all three labs (you can do them independently)
- No prior DCS knowledge required; we explain everything as we go

!!! info "Basic concepts first, then STANAG compliance"
    The labs teach DCS using simplified AWS implementations. Once you've completed them, the [reference architectures](../architectures/index.md) show how to make each level NATO STANAG-compliant, with proper 4774 XML labels, 4778 cryptographic binding, and ZTDF encryption.

Ready? Start with [What is Data-Centric Security?](overview/index.md) to understand the concepts, or jump straight to [Lab 1](lab1/index.md) if you want to get building.
