# Step 4: Encrypt Your First TDF File

Now for the moment everything has been building towards: encrypting a file so that protection is embedded in the data itself.

## Install the OpenTDF CLI

```bash
# Using npm
npm install -g @opentdf/ctl

# Or download the Go CLI from GitHub
# https://github.com/opentdf/platform/releases
```

!!! tip "Alternative: Docker"
    `docker pull ghcr.io/opentdf/otdfctl:latest`

## Configure the CLI

Point the CLI at your OpenTDF platform and Cognito:

```bash
KAS_IP="YOUR-TASK-PUBLIC-IP"
export OPENTDF_ENDPOINT="http://$KAS_IP:8080"

# Cognito OIDC endpoint for the UK user pool
export OIDC_ENDPOINT="https://cognito-idp.YOUR-REGION.amazonaws.com/YOUR-UK-POOL-ID"
export OIDC_CLIENT_ID="YOUR-UK-CLIENT-ID"
```

## Encrypt a file

Let's encrypt the same intelligence report from Lab 1:

```bash
cat > intel-report.txt << 'EOF'
INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
Enemy forces observed moving through GRID 12345678.
Estimated 200 personnel with armoured vehicles.
Movement pattern suggests preparation for offensive operations.
Recommend increased surveillance.
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
  --input intel-report.txt \
  --output intel-report.txt.tdf
```

This creates `intel-report.txt.tdf` — an encrypted TDF file.

## Examine what was created

The TDF file is a ZIP archive:

```bash
unzip -l intel-report.txt.tdf
```

```
Archive:  intel-report.txt.tdf
  Length      Date    Time    Name
---------  ---------- -----   ----
      xxx  2025-03-20 10:00   0.payload
      xxx  2025-03-20 10:00   0.manifest.json
```

Look at the manifest:

```bash
unzip -p intel-report.txt.tdf 0.manifest.json | python3 -m json.tool
```

```json
{
  "encryptionInformation": {
    "type": "split",
    "keyAccess": [
      {
        "type": "wrapped",
        "url": "http://YOUR-KAS-IP:8080/kas",
        "wrappedKey": "BASE64_ENCODED_WRAPPED_DEK...",
        "policyBinding": {
          "alg": "HS256",
          "hash": "HMAC_OF_POLICY..."
        }
      }
    ],
    "method": {
      "algorithm": "AES-256-GCM"
    }
  },
  "payload": {
    "type": "reference",
    "url": "0.payload",
    "mimeType": "text/plain"
  }
}
```

## What's in the TDF

**`0.payload`**: Your intelligence report, encrypted with AES-256-GCM. Completely unreadable without the DEK.

**`0.manifest.json`**: The metadata that makes DCS work:

- **`wrappedKey`**: The DEK, wrapped by the KAS using your KMS key. Useless without the KAS unwrapping it.
- **`url`**: Points to the KAS that can unwrap this key.
- **`policyBinding`**: An HMAC that ties the policy to the wrapped key. Tamper with the policy and the binding check fails.
- **`algorithm`**: AES-256-GCM — the same algorithm used by NATO for classified data.

## Try to read the encrypted payload

```bash
unzip -p intel-report.txt.tdf 0.payload | xxd | head -5
```

Random bytes. The data is fully encrypted.

## Upload to S3

```bash
aws s3 cp intel-report.txt.tdf s3://dcs-lab-data-YOUR-ACCOUNT-ID/tdf/
```

Unlike Lab 1, an S3 administrator who downloads this file gets nothing but ciphertext. The data is self-protecting.

!!! tip "Compare to Lab 1"
    In Lab 1, we uploaded `intel-report.txt` to S3 with tags. Anyone with S3 access could read it. Now we've uploaded `intel-report.txt.tdf` — the same content, but encrypted. The security isn't in the S3 permissions anymore. It's in the data itself.

Next: **[Step 5: Decrypt with Policy Checks](step5-decrypt.md)**
