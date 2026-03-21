# Step 5: Encrypt Your First TDF File

Now for the moment everything has been building towards: encrypting a file so that protection is embedded in the data itself. We'll use the OpenTDF command-line tools.

## Install the OpenTDF CLI

The easiest way to use the OpenTDF SDK is via the command-line tool:

```bash
# Using npm (Node.js)
npm install -g @opentdf/ctl

# Or using Docker
docker pull ghcr.io/opentdf/otdfctl:latest
```

!!! tip "Alternative: Use the Go CLI"
    OpenTDF also provides `otdfctl`, a Go-based CLI. Download it from [github.com/opentdf/platform/releases](https://github.com/opentdf/platform/releases).

## Configure the CLI

Set up environment variables pointing to your platform:

```bash
export OPENTDF_ENDPOINT="http://YOUR-ALB-DNS"
export OIDC_ENDPOINT="http://YOUR-ALB-DNS/auth/realms/coalition"
export OIDC_CLIENT_ID="opentdf-sdk"
```

## Encrypt a file

Let's encrypt the intelligence report from Lab 1:

```bash
# Create a test file
cat > intel-report.txt << 'EOF'
INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
Enemy forces observed moving through GRID 12345678.
Estimated 200 personnel with armoured vehicles.
Movement pattern suggests preparation for offensive operations.
Recommend increased surveillance.
EOF

# Encrypt it as a TDF file with access policy
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
  --input intel-report.txt \
  --output intel-report.txt.tdf
```

This creates `intel-report.txt.tdf` - an encrypted TDF file.

## Examine what was created

The TDF file is a ZIP archive. Let's look inside:

```bash
unzip -l intel-report.txt.tdf
```

You'll see:
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

You'll see something like:

```json
{
  "encryptionInformation": {
    "type": "split",
    "keyAccess": [
      {
        "type": "wrapped",
        "url": "http://YOUR-ALB-DNS/kas",
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

## Understand what's in the TDF

**`0.payload`**: Your intelligence report, encrypted with AES-256-GCM. This is ciphertext - completely unreadable without the DEK.

**`0.manifest.json`**: The metadata that makes DCS work:

- **`wrappedKey`**: The DEK, wrapped (encrypted) by the KAS using your KMS key. Even though it's in the file, it's useless without the KAS unwrapping it.
- **`url`**: Points to the KAS that can unwrap this key. Without this KAS, nobody can decrypt.
- **`policyBinding`**: An HMAC that ties the policy to the wrapped key. If someone tampers with the policy, the binding check fails and decryption is refused.
- **`algorithm`**: AES-256-GCM - the same algorithm used by NATO for classified data.

## Try to read the encrypted payload

```bash
unzip -p intel-report.txt.tdf 0.payload | xxd | head -5
```

You'll see random bytes - the data is fully encrypted. Without the DEK (which is locked inside the wrapped key, which can only be unwrapped by the KAS, which will only unwrap after checking your attributes), this is useless.

## Upload to S3

```bash
aws s3 cp intel-report.txt.tdf s3://dcs-level1-data-YOUR-ACCOUNT-ID/tdf/
```

The TDF file is now in S3. But unlike Lab 1, an S3 administrator who downloads this file gets nothing but ciphertext. The data is self-protecting.

!!! tip "Compare to Lab 1"
    In Lab 1, we uploaded `intel-report.txt` to S3 with tags. Anyone with S3 access could read it. Now we've uploaded `intel-report.txt.tdf` - the same content, but encrypted. The security isn't in the S3 permissions anymore. It's in the data itself.

Next: **[Step 6: Decrypt with Policy Checks](step6-decrypt.md)**
