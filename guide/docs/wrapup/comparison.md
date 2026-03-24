# Comparing the Three Levels

## Side-by-side comparison

| Feature | Level 1: Labeling | Level 2: Access Control | Level 3: Encryption |
|---------|:-:|:-:|:-:|
| Data has security metadata | Yes (S3 tags) | Yes (S3 tags) | Yes (TDF assertions) |
| Access decisions based on attributes | No (labels returned, not enforced) | Yes (Cedar policies) | Yes (KAS policy engine) |
| Policy changes without code deploy | No | Yes | Yes |
| Data encrypted at rest | No (plain text) | No (plain text) | Yes (AES-256-GCM) |
| Admin can read data | Yes | Yes | No |
| Protection after data is copied | No | No | Yes |
| Labels cryptographically bound | No | No | Yes (JWS binding) |
| Federated across organizations | Limited | Possible | Built-in (multi-KAS) |
| Revoke access to shared data | Remove S3 access | Update Cedar policy | Update KAS entitlements |
| Audit trail | CloudTrail + Lambda logs | AVP decision logs | KAS + KMS CloudTrail |

## When to use each level

### Level 1 is right when...

- You're starting your DCS journey and want to add structure to your data
- You trust your infrastructure and application layer
- You need a quick way to add security metadata to existing systems
- The main goal is visibility (knowing what data you have and how sensitive it is)
- Budget and complexity constraints prevent a full DCS deployment

### Level 2 is right when...

- You need fine-grained access control that goes beyond simple permissions
- Multiple organizations need to share data with different access rules
- Access rules change frequently and can't wait for code deployments
- You need clear audit trails showing which policy authorized each access
- You trust your infrastructure but want stronger application-layer controls

### Level 3 is right when...

- Data crosses organizational or national boundaries
- You need to mitigate the risk of bad actors — whether insiders, cloud provider employees, or external attackers — accessing the underlying infrastructure
- Protection must persist regardless of where data ends up
- You need to revoke access to data that's already been shared
- Regulatory or classification requirements demand encryption
- You're building for NATO or coalition interoperability (ZTDF standard)

## The practical path

Most organizations don't jump straight to Level 3. A realistic path looks like:

1. **Start with Level 1**: Get your data labeled and build the habit of thinking about security metadata. This is quick and cheap.

2. **Add Level 2 when you need cross-org sharing**: When you start sharing data between teams or organizations and need policy-based access control.

3. **Move to Level 3 when data leaves your control**: When data needs to survive outside your infrastructure, or when you need to meet defence/intelligence classification requirements.

Each level is valuable on its own, and the investment in lower levels carries forward. The labels you define at Level 1 become the attributes your Level 2 policies evaluate, which become the assertions in your Level 3 TDF files.

## Cost comparison

| Level | Monthly cost (demo) | Main cost drivers |
|-------|-------------------|-------------------|
| Level 1 | ~$5 | S3, Lambda (mostly free tier) |
| Level 2 | ~$10-15 | Verified Permissions, Cognito |
| Level 3 | ~$15-25 | ECS Fargate, RDS db.t3.micro, KMS |

Production costs will be higher, especially at Level 3 where you'd add a load balancer, private subnets, multi-AZ database, and potentially multiple KAS deployments.
