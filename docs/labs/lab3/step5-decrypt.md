# Step 5: Decrypt with Policy Checks

This is where DCS Level 3 comes alive. When someone tries to decrypt a TDF file, the CLI contacts the KAS, the KAS checks their attributes against the policy, and only then releases the encryption key.

## Decrypt as the UK analyst (authorized)

```bash
otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username uk-analyst-01 \
  --password 'TempPass1!' \
  --input intel-report.txt.tdf \
  --output intel-report-decrypted.txt
```

**Expected: Success.**

```bash
cat intel-report-decrypted.txt
```

```
INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
Enemy forces observed moving through GRID 12345678.
...
```

## What happened behind the scenes

1. **CLI read the TDF manifest** and found the KAS URL and wrapped DEK
2. **CLI authenticated to Cognito** as `uk-analyst-01` and got an OIDC token with custom attributes
3. **CLI sent the wrapped DEK + OIDC token to the KAS**
4. **KAS validated the token** against Cognito's JWKS endpoint
5. **KAS extracted user attributes** from the token claims (Claims ERS mode)
6. **KAS applied subject mappings** to determine entitlements
7. **KAS checked the TDF policy** against the user's entitlements, all satisfied
8. **KAS sent the wrapped DEK to KMS** for unwrapping
9. **KMS unwrapped the DEK** (logged in CloudTrail)
10. **KAS returned the plaintext DEK** to the CLI
11. **CLI decrypted the payload** locally

Every step is logged. The KAS logged the access request. KMS logged the key operation in CloudTrail.

## Decrypt as the Polish analyst (authorized for this file)

Switch to the Polish Cognito pool:

```bash
export OIDC_ENDPOINT="https://cognito-idp.YOUR-REGION.amazonaws.com/YOUR-POL-POOL-ID"
export OIDC_CLIENT_ID="YOUR-POL-CLIENT-ID"

otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username pol-analyst-01 \
  --password 'TempPass1!' \
  --input intel-report.txt.tdf \
  --output intel-report-pol.txt
```

**Expected: Success.** Poland is in the releasable-to list and has sufficient clearance.

## Create and try a WALL-protected file

Encrypt a file that requires the WALL SAP:

```bash
# Switch back to UK pool
export OIDC_ENDPOINT="https://cognito-idp.YOUR-REGION.amazonaws.com/YOUR-UK-POOL-ID"
export OIDC_CLIENT_ID="YOUR-UK-CLIENT-ID"

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
  --password 'TempPass1!' \
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
export OIDC_ENDPOINT="https://cognito-idp.YOUR-REGION.amazonaws.com/YOUR-POL-POOL-ID"
export OIDC_CLIENT_ID="YOUR-POL-CLIENT-ID"

otdfctl decrypt \
  --endpoint $OPENTDF_ENDPOINT \
  --oidc-endpoint $OIDC_ENDPOINT \
  --client-id $OIDC_CLIENT_ID \
  --username pol-analyst-01 \
  --password 'TempPass1!' \
  --input wall-brief.txt.tdf \
  --output should-fail.txt
```

**Expected: DENIED.** The KAS finds that `pol-analyst-01` doesn't have the WALL SAP and refuses to unwrap the DEK.

```
Error: access denied - policy requirements not met
```

The Polish analyst has the TDF file. They can copy it, email it, put it on a USB drive. Doesn't matter, without KAS authorization, the data is unreadable.

## Verify in KMS CloudTrail

1. Go to **CloudTrail Console** > **Event history**
2. Filter by **Event name**: `Decrypt`
3. You should see KMS Decrypt events for the successful decryptions (UK analyst, Polish analyst on the first file)
4. For the denied attempt (Polish analyst on the WALL file), there will be NO KMS event. The KAS denied the request before it ever reached KMS

This is an important audit distinction:

- **KAS logs** show all access attempts (granted and denied) with policy evaluation details
- **KMS logs** show only successful key operations (the KAS only calls KMS after policy approval)

Together they give you a complete picture: who tried to access what, whether they were allowed, and which key operations actually happened.

Next: **[Step 6: Test Federation and Denial](step6-test.md)**
