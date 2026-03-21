# Step 6: Decrypt with Policy Checks

This is where DCS Level 3 comes alive. When someone tries to decrypt a TDF file, the SDK contacts the KAS, the KAS checks their attributes against the policy, and only then releases the encryption key.

## Decrypt as the UK analyst (authorized)

```bash
otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username uk-analyst-01 \
  --password demo-password-1 \
  --input intel-report.txt.tdf \
  --output intel-report-decrypted.txt
```

**Expected: Success.** The file decrypts and you can read the original content:

```bash
cat intel-report-decrypted.txt
```

```
INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
Enemy forces observed moving through GRID 12345678.
...
```

## What happened behind the scenes

Here's the exact flow that occurred:

1. **SDK read the TDF manifest** and found the KAS URL and wrapped DEK
2. **SDK authenticated to Keycloak** as `uk-analyst-01` and got an OIDC token containing the user's attributes (nationality: GBR, clearance: SECRET, saps: WALL)
3. **SDK sent the wrapped DEK + OIDC token to the KAS**
4. **KAS validated the OIDC token** with Keycloak
5. **KAS extracted user attributes** from the token
6. **KAS checked the TDF policy**: Does GBR have the `releasable` attribute? Does SECRET meet the `classification` hierarchy? Yes to all.
7. **KAS sent the wrapped DEK to KMS** for unwrapping
8. **KMS unwrapped the DEK** (this event is logged in CloudTrail)
9. **KAS returned the plaintext DEK** to the SDK
10. **SDK used the DEK to decrypt** the payload locally

Every step is logged. The KAS logged the access request. KMS logged the key operation in CloudTrail. The SDK can log locally too.

## Decrypt as the Polish analyst (authorized for this file)

```bash
otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username pol-analyst-01 \
  --password demo-password-1 \
  --input intel-report.txt.tdf \
  --output intel-report-pol.txt
```

**Expected: Success.** Poland is in the releasable-to list and has sufficient clearance.

## Create and try a WALL-protected file

Encrypt a file that requires the WALL SAP:

```bash
cat > wall-brief.txt << 'EOF'
OPERATION WALL - PHASE 2 BRIEFING
UK sources report enemy command restructuring.
Coordinated coalition response planned.
EOF

otdfctl encrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username uk-analyst-01 \
  --password demo-password-1 \
  --attr "https://dcs.example.com/attr/classification/value/SECRET" \
  --attr "https://dcs.example.com/attr/releasable/value/GBR" \
  --attr "https://dcs.example.com/attr/releasable/value/USA" \
  --attr "https://dcs.example.com/attr/releasable/value/POL" \
  --attr "https://dcs.example.com/attr/sap/value/WALL" \
  --input wall-brief.txt \
  --output wall-brief.txt.tdf
```

Now try to decrypt as the Polish analyst (who doesn't have WALL):

```bash
otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username pol-analyst-01 \
  --password demo-password-1 \
  --input wall-brief.txt.tdf \
  --output should-fail.txt
```

**Expected: DENIED.** The KAS checks the policy, finds that `pol-analyst-01` doesn't have the WALL SAP attribute, and refuses to unwrap the DEK. The file remains encrypted.

You'll see an error message like:
```
Error: access denied - policy requirements not met
```

The Polish analyst has the TDF file. They can copy it, email it, put it on a USB drive. It doesn't matter - without KAS authorization, the data is unreadable.

## Verify in KMS CloudTrail

1. Go to **CloudTrail Console** > **Event history**
2. Filter by **Event name**: `Decrypt`
3. You should see KMS Decrypt events for the successful decryptions
4. For the denied attempt, there will be NO KMS event - the KAS denied the request before it ever reached KMS

This is an important audit distinction:

- **KAS logs** show all access attempts (granted and denied) with policy evaluation details
- **KMS logs** show only successful key operations (the KAS only calls KMS after policy approval)

Next: **[Step 7: Test Federation and Denial](step7-test.md)**
