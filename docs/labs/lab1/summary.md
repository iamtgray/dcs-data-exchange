# What you learned - Lab 1

## Key takeaways

### 1. Labels make data self-describing

By adding S3 tags to each object, the data now carries its own security metadata. Any system that reads those tags knows how the data should be handled: what classification it is, who should be able to see it, and what special access is needed.

### 2. Labels travel with data

When you copied an S3 object, the tags went with it. This is the DCS principle: security metadata is attached to the data, not stored in a separate system that might get out of sync.

### 3. Labels without enforcement are just suggestions

Our data service returned SECRET intelligence reports to anyone who asked. The labels were there in the response, but nothing stopped an unauthorized person from reading the data. Labels describe policy; they don't enforce it.

### 4. Labels without binding can be silently changed

We changed a SECRET report's label to UNCLASSIFIED with a single CLI command. Nobody was alerted. The data service happily returned the mislabeled data. In a real system, STANAG 4778 cryptographic binding would make this tampering detectable.

### 5. Audit tells you what happened, not whether it should have

The Lambda logs show which objects were accessed and what their labels were. But there's no record of who the caller was or whether they had the right clearance. Audit without identity is incomplete.

## What's missing

| Gap | What it means | Fixed in |
|-----|--------------|----------|
| No access control | Anyone can read any data | Lab 2 |
| No user identity | Can't attribute access to a person | Lab 2 |
| No policy enforcement | Labels are ignored | Lab 2 |
| No cryptographic binding | Labels can be silently changed | Assured Level 1 architecture |
| No encryption | Data is plaintext in S3 | Lab 3 |

## What Lab 2 adds

Lab 2 keeps the same data and labels but adds the pieces that make labels meaningful:

- **User identity** via Cognito, where each person has attributes (clearance, nationality, SAPs)
- **A policy engine** (Amazon Verified Permissions) that evaluates Cedar policies
- **Access checking** where the Lambda asks the policy engine "should this user see this data?" before returning anything
- **Dynamic policies** so you can change access rules without touching code or data

The data service from this lab becomes an access-controlled service. Same data, same labels, but now someone checks the labels before handing over the data.

---

Ready for enforcement? Continue to **[Lab 2: Access Control (DCS Level 2)](../lab2/index.md)**.
