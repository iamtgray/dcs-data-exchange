# Step 6: Test Federation and Denial

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

The file is useless without KAS authorization. Even with the OpenTDF CLI installed, without valid Cognito credentials that satisfy the policy, the data stays encrypted.

## Scenario B: Policy change after sharing

This demonstrates one of the most powerful DCS capabilities: changing access to data that's already been shared.

1. Verify the UK analyst can decrypt `intel-report.txt.tdf` (they can, from Step 5)

2. Update the subject mappings in the OpenTDF platform to remove the UK analyst's releasable entitlement:

```bash
# Switch to UK pool
export OIDC_ENDPOINT="https://cognito-idp.YOUR-REGION.amazonaws.com/YOUR-UK-POOL-ID"
export OIDC_CLIENT_ID="YOUR-UK-CLIENT-ID"

AUTH_RESULT=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $OIDC_CLIENT_ID \
  --auth-parameters USERNAME=uk-analyst-01,PASSWORD='TempPass1!' \
  --region YOUR-REGION)

ACCESS_TOKEN=$(echo $AUTH_RESULT | python3 -c "import sys,json; print(json.load(sys.stdin)['AuthenticationResult']['AccessToken'])")

KAS_IP="YOUR-TASK-PUBLIC-IP"

# Remove the GBR releasable entitlement
curl -X DELETE "http://$KAS_IP:8080/api/subject-mappings/MAPPING_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

3. Try to decrypt again as the UK analyst:

```bash
otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username uk-analyst-01 \
  --password 'TempPass1!' \
  --input intel-report.txt.tdf \
  --output should-now-fail.txt
```

**Expected: DENIED.** The TDF file hasn't changed. The data hasn't changed. But the KAS now evaluates the UK analyst's updated entitlements and refuses to unwrap the key.

This is policy persistence after sharing. You can revoke access to data that was encrypted weeks, months, or years ago. The TDF file sitting on someone's hard drive becomes unreadable the moment their entitlements change.

4. Restore the subject mapping so later tests work.

## Scenario C: Federated KAS (conceptual)

In a real coalition deployment, each nation runs their own KAS in their own AWS account:

```
TDF manifest with AnyOf key access:

keyAccess[0]: UK-KAS  (wrappedKey using UK KMS key)
keyAccess[1]: PL-KAS  (wrappedKey using PL KMS key)
keyAccess[2]: US-KAS  (wrappedKey using US KMS key)
```

When a UK analyst decrypts:

- CLI contacts UK-KAS (the KAS their nation operates)
- UK-KAS uses UK KMS to unwrap
- UK-KAS checks UK-managed entitlements
- Polish and US KAS are never contacted

When a Polish analyst decrypts the same TDF:

- CLI contacts PL-KAS
- PL-KAS uses PL KMS to unwrap
- PL-KAS checks Polish entitlements
- UK and US KAS are never contacted

Each nation maintains sovereignty over their keys and access decisions. No nation needs to trust another's infrastructure. The TDF format makes this possible by supporting multiple key access entries.

!!! note "This demo uses a single KAS"
    Setting up three separate AWS accounts with federated KAS is beyond the scope of this lab. But the architecture supports it, and the TDF specification is designed for it.

## Scenario D: Compare all three levels

Take the same file — `intel-report.txt` — and consider what happens at each level if someone gains unauthorized access to AWS:

| Attack | Level 1 (S3 tags) | Level 2 (Cedar) | Level 3 (TDF) |
|--------|:-:|:-:|:-:|
| Attacker gets S3 read access | **Read all data** | **Read all data** | **Gets ciphertext only** |
| Privileged insider (cloud provider or your own org) | **Read all data** | **Read all data** | **Gets ciphertext only** (would need to also compromise KAS) |
| Attacker copies file to USB | **Read all data** | **Read all data** | **Encrypted, useless** |
| Attacker steals backup tapes | **Read all data** | **Read all data** | **Gets ciphertext only** |
| Admin accidentally makes bucket public | **Data exposed** | **Data exposed** | **Only ciphertext exposed** |

Level 3 is the only level where the data is protected even if a bad actor — whether an insider within your own organization, a cloud provider employee, or an external attacker — gains privileged access to the underlying infrastructure.

Next: **[What You Learned](summary.md)**
