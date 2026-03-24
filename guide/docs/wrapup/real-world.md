# Real-World Applications

## NATO coalition intelligence sharing

The scenario that runs through this entire workshop - Poland, UK, and US sharing intelligence - is based on real operational requirements. DCS Level 3 with ZTDF is how NATO is standardizing cross-border data protection.

In a real deployment:

- Each nation runs its own KAS in its own sovereign cloud environment
- TDF files include multiple key access entries (one per nation's KAS)
- STANAG 4774 labels in TDF assertions describe classification and releasability
- Each nation's KAS independently evaluates access for its own citizens
- No nation ever sees another nation's encryption keys

## Defence cloud migration

Many defence organizations are moving workloads to commercial cloud. DCS addresses a key concern: mitigating the risk of any bad actor — whether an insider within your own organization, a partner, or a cloud service provider — gaining access to sensitive data.

!!! note "Cloud provider access models vary"
    Some cloud services offer zero-operator access guarantees where provider employees cannot access customer data. However, not all services provide this (for example, S3 at the time of writing is not a zero-operator access service). DCS Level 3 provides protection regardless of the service's operator access model.

With Level 3:

- Data is encrypted before it reaches the cloud
- The cloud provider stores only ciphertext
- Even if data is exfiltrated — by an insider, a compromised credential, or a compelled disclosure — only encrypted files are exposed
- Key management stays under the organization's control (through KMS key policies)

## Cross-domain solutions

When data needs to move between classification domains (e.g., TOP SECRET to SECRET), DCS labels help automate the sanitization process:

- Level 1 labels identify what classification each piece of data carries
- Level 2 policies can determine what data is eligible for downgrade
- Level 3 keeps data protected during the transfer process

## Supply chain security

Defence supply chains involve sharing technical data with contractors, sub-contractors, and partner nations. DCS protects this data:

- Original manufacturer encrypts technical drawings with TDF
- Access policy specifies which contractors can read them
- When a subcontractor no longer needs access, entitlements are revoked
- All access is audited for compliance

## Healthcare and regulated industries

DCS concepts apply beyond defence. Any industry where data must be shared across organizational boundaries with fine-grained access control can benefit:

- **Healthcare**: Patient records shared between hospitals, with access based on role and relationship to the patient
- **Financial services**: Trading data shared between firms, with access based on regulatory authorization
- **Government**: Citizen data shared between departments, with access based on purpose and authorization

## Getting started for real

If you're ready to move beyond the demo:

1. Start with your data classification scheme. Define your labels before building infrastructure.
2. Evaluate OpenTDF. The open-source platform is production-ready and actively maintained.
3. Plan your attribute schema. What attributes define access in your organization?
4. Consider federated identity. How will you authenticate users from different organizations?
5. Design your KAS topology. One central KAS, or federated KAS per organization?
6. Plan for offline/tactical. If you need DDIL (disconnected) support, look at asymmetric TDF mode.

The architecture documentation in this repository (`architectures/`) provides more detailed technical designs for each level.
