# Wrap-Up

You've now built all three levels of Data-Centric Security on AWS. Here's a summary of what you accomplished:

## What you built

| Lab | DCS Level | What you built | Key AWS services |
|-----|-----------|----------------|------------------|
| Lab 1 | Level 1 - Labeling | S3 objects with security tags, Lambda access checker | S3, Lambda, IAM, CloudTrail |
| Lab 2 | Level 2 - Access Control | Policy engine with Cedar rules, multi-org identity | Cognito, Verified Permissions, DynamoDB, Lambda |
| Lab 3 | Level 3 - Encryption | OpenTDF platform with KAS, encrypted TDF files | ECS, KMS, RDS, Keycloak |

## The journey

You started with the simplest possible DCS implementation - putting labels on S3 objects - and progressed to a full encryption-based system where data protects itself. Each level addressed the limitations of the one before:

- **Level 1** showed that labels alone are advisory - anyone with access can ignore them
- **Level 2** added policy enforcement, but data was still unencrypted in storage
- **Level 3** encrypted the data itself, making protection independent of infrastructure

## The core message

Data-centric security moves protection from the network into the data. Instead of hoping that firewalls, VPNs, and access lists will keep your data safe, you make the data self-protecting. Labels describe the rules. Policies enforce them. Encryption makes enforcement unavoidable.

This approach is useful when:

- Data crosses organizational boundaries (coalition operations, partner sharing)
- You can't trust every system the data touches (cloud, partner networks)
- Access requirements change after data is shared (policy updates, revocations)
- You need to prove who accessed what and when (audit, compliance)

Continue to **[Comparing the Three Levels](comparison.md)** for a detailed side-by-side, or jump to **[Clean Up](cleanup.md)** to delete your AWS resources.
