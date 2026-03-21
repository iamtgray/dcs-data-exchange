# Step 7: Test Federation and Denial

Let's run through several scenarios that show why DCS Level 3 is fundamentally different from Levels 1 and 2.

## Scenario A: Data exfiltration protection

Simulate an insider who copies a TDF file to their local machine:

```bash
# Copy the TDF file to a "stolen" location
cp intel-report.txt.tdf /tmp/stolen-data.tdf

# Try to read it directly
cat /tmp/stolen-data.tdf
# Output: binary garbage - it's encrypted

# Try to unzip and read the payload
unzip -p /tmp/stolen-data.tdf 0.payload | strings | head
# Output: nothing readable - AES-256-GCM ciphertext
```

The file is useless without KAS authorization. Even with the TDF SDK installed, without valid credentials that satisfy the policy, the data stays encrypted.

## Scenario B: Policy change after sharing

This demonstrates one of the most powerful DCS capabilities: changing access to data that's already been shared.

1. First, verify the UK analyst can decrypt `intel-report.txt.tdf` (they can, from Step 6)

2. Now, go to your OpenTDF platform and revoke the UK analyst's `releasable` entitlement:

```bash
# Remove GBR releasable entitlement from UK analyst
curl -X DELETE "http://YOUR-ALB-DNS/api/entitlements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "uk-analyst-01",
    "attribute_values": [
      "https://dcs.example.com/attr/releasable/value/GBR"
    ]
  }'
```

3. Try to decrypt again as the UK analyst:

```bash
otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username uk-analyst-01 \
  --password demo-password-1 \
  --input intel-report.txt.tdf \
  --output should-now-fail.txt
```

**Expected: DENIED.** The TDF file hasn't changed. The data hasn't changed. But the KAS now evaluates the UK analyst's updated entitlements and refuses to unwrap the key.

This is policy persistence after sharing. You can revoke access to data that was encrypted weeks, months, or years ago. The TDF file sitting on someone's hard drive becomes unreadable the moment their entitlements change.

4. Restore the entitlement (so later tests work):

```bash
curl -X POST "http://YOUR-ALB-DNS/api/entitlements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "uk-analyst-01",
    "attribute_values": [
      "https://dcs.example.com/attr/releasable/value/GBR"
    ]
  }'
```

## Scenario C: Understanding federated KAS (conceptual)

In a real coalition deployment, each nation runs their own KAS in their own AWS account:

```
TDF manifest with AnyOf key access:

keyAccess[0]: UK-KAS  (wrappedKey using UK KMS key)
keyAccess[1]: PL-KAS  (wrappedKey using PL KMS key)
keyAccess[2]: US-KAS  (wrappedKey using US KMS key)
```

When a UK analyst decrypts:
- SDK contacts UK-KAS (the first KAS their nation operates)
- UK-KAS uses UK KMS to unwrap
- UK-KAS checks UK-managed entitlements
- Polish and US KAS are never contacted

When a Polish analyst decrypts the same TDF:
- SDK contacts PL-KAS
- PL-KAS uses PL KMS to unwrap
- PL-KAS checks Polish entitlements
- UK and US KAS are never contacted

Each nation maintains sovereignty over their keys and access decisions. No nation needs to trust another's infrastructure. The TDF format makes this possible by supporting multiple key access entries.

!!! note "This demo uses a single KAS"
    Setting up three separate AWS accounts with federated KAS is beyond the scope of this lab. But the architecture supports it, and the TDF specification is designed for it. In the architecture documentation (`architectures/aws-dcs-level-3-encryption/`), you'll find designs for multi-account federated KAS.

## Scenario D: Compare all three levels

Take the same file - `intel-report.txt` - and consider what happens at each level if someone gains unauthorized access to AWS:

| Attack | Level 1 (S3 tags) | Level 2 (ABAC) | Level 3 (TDF) |
|--------|:-:|:-:|:-:|
| Attacker gets S3 read access | **Read all data** | N/A (DynamoDB) | **Gets ciphertext only** |
| Attacker gets DB read access | N/A | **Read all data** | N/A |
| Attacker gets AWS root access | **Read all data** | **Read all data** | **Gets ciphertext only** (would need to also compromise KAS) |
| Attacker copies file to USB | **Read all data** | N/A | **Encrypted, useless** |
| Attacker steals backup tapes | **Read all data** | **Read all data** | **Gets ciphertext only** |
| Admin accidentally makes bucket public | **Data exposed** | N/A | **Only ciphertext exposed** |

Level 3 is the only level where the data is protected regardless of infrastructure compromise.

Next: **[What You Learned](summary.md)**
