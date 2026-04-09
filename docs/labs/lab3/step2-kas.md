# Step 2: Deploy the Key Access Server

The Key Access Server (KAS) is the core of DCS Level 3. It decides whether to release a Data Encryption Key based on the requesting user's attributes and the data's policy. We'll run the OpenTDF platform as a single ECS Fargate task with a public IP in your account's default VPC, no custom networking, no load balancer.

## Create the RDS database

OpenTDF needs PostgreSQL for storing attribute definitions, subject mappings, and audit logs. We'll use a small single-AZ instance in the default VPC.

1. Go to **RDS Console**: [https://console.aws.amazon.com/rds](https://console.aws.amazon.com/rds)
2. Click **Create database**
3. **Engine**: PostgreSQL
4. **Templates**: Free tier
5. **DB instance identifier**: `dcs-level3-opentdf`
6. **Master username**: `opentdf`
7. **Master password**: Choose a password and save it
8. **Instance configuration**: db.t3.micro
9. **Connectivity**:
    - VPC: Default VPC
    - Public access: No
    - VPC security group: Create new > `dcs-level3-rds-sg`
10. **Database name** (under Additional configuration): `opentdf`
11. Click **Create database** (takes 5-10 minutes)

!!! info "While the database creates..."
    Continue with the ECS setup below. Come back to verify the database is available before starting the ECS service.

## Update the RDS security group

The auto-created security group needs to allow connections from ECS tasks.

1. Go to **EC2** > **Security Groups** > find `dcs-level3-rds-sg`
2. Edit **Inbound rules**
3. Add: Type: PostgreSQL, Port: 5432, Source: the default VPC's CIDR (e.g., `172.31.0.0/16`)
4. Click **Save rules**

!!! tip "Default VPC"
    Every AWS account has a default VPC with public subnets in each AZ. We're using it to avoid creating any custom networking. The RDS instance and ECS task will both run here.

## Create the ECS cluster

1. Go to **ECS Console**: [https://console.aws.amazon.com/ecs](https://console.aws.amazon.com/ecs)
2. Click **Create cluster**
3. **Cluster name**: `dcs-level3`
4. **Infrastructure**: AWS Fargate
5. Click **Create**

## Create the ECS task execution role

1. Go to **IAM** > **Roles** > **Create role**
2. **Trusted entity**: AWS service > Elastic Container Service > Elastic Container Service Task
3. Attach policy: `AmazonECSTaskExecutionRolePolicy`
4. **Role name**: `dcs-level3-ecs-execution-role`
5. Click **Create role**

## Create the ECS task role (for KMS access)

1. Create another role: **AWS service** > **Elastic Container Service** > **Elastic Container Service Task**
2. **Role name**: `dcs-level3-kas-task-role`
3. Click **Create role**
4. Add an inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:YOUR-REGION:YOUR-ACCOUNT:key/YOUR-KMS-KEY-ID"
    }
  ]
}
```

!!! warning "Update the KMS key ARN"
    Replace the Resource with your actual KMS key ARN from Step 1.

## Update the KMS key policy

Add the task role to the key's usage permissions:

1. Open your `dcs-level3-kas-kek` key in the KMS console
2. Click **Key policy** > **Edit**
3. Add a statement:

```json
{
  "Sid": "AllowKASTaskRole",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::YOUR-ACCOUNT:role/dcs-level3-kas-task-role"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

## Create the ECS task definition

This is where we configure the OpenTDF platform. We point the auth issuer at your Cognito user pool from Lab 2 and set entity resolution to `claims` mode so the platform reads user attributes directly from the JWT.

1. Go to **ECS** > **Task definitions** > **Create new task definition**
2. **Family**: `dcs-level3-opentdf`
3. **Launch type**: Fargate
4. **CPU**: 0.5 vCPU
5. **Memory**: 1 GB
6. **Task role**: `dcs-level3-kas-task-role`
7. **Task execution role**: `dcs-level3-ecs-execution-role`
8. **Container**:
    - Name: `opentdf`
    - Image: `registry.opentdf.io/platform:v0.8.1`
    - Port mappings: 8080 TCP
    - Environment variables:

| Variable | Value |
|----------|-------|
| `OPENTDF_DB_HOST` | Your RDS endpoint (e.g., `dcs-level3-opentdf.abc123.eu-west-2.rds.amazonaws.com`) |
| `OPENTDF_DB_PORT` | `5432` |
| `OPENTDF_DB_DATABASE` | `opentdf` |
| `OPENTDF_DB_USER` | `opentdf` |
| `OPENTDF_DB_PASSWORD` | Your database password |
| `OPENTDF_SERVER_PORT` | `8080` |
| `OPENTDF_SERVER_AUTH_ISSUER` | `https://cognito-idp.YOUR-REGION.amazonaws.com/YOUR-UK-POOL-ID` |
| `OPENTDF_SERVER_AUTH_AUDIENCE` | Your Cognito app client ID (e.g., `75n9gqu87lcj0n7io98kplt30a`) |
| `OPENTDF_SERVICES_ENTITYRESOLUTION_MODE` | `claims` |
| `OPENTDF_SERVER_AUTH_POLICY_CLIENT_ID_CLAIM` | `sub` |

9. Click **Create**

!!! tip "Finding your Cognito issuer URL"
    The issuer URL follows the pattern `https://cognito-idp.{region}.amazonaws.com/{userPoolId}`. Use the UK user pool ID from Lab 2. Verify it by opening `https://cognito-idp.{region}.amazonaws.com/{userPoolId}/.well-known/openid-configuration` in a browser.

!!! warning "Why `CLIENT_ID_CLAIM` is set to `sub`"
    The OpenTDF platform defaults to reading the client ID from the `azp` JWT claim, which Keycloak always provides. Cognito doesn't include `azp` in its tokens — it puts the client ID in `aud` instead. You might think setting the claim to `aud` would fix it, but `aud` is defined as an array in the JWT spec (RFC 7519), and the platform's extraction code does a plain string type assertion that fails on arrays. Setting it to `sub` sidesteps the issue: `sub` is always a string, and the extracted value is only used as metadata for the platform's obligation decisioning, not for the actual ABAC access check. See [the full write-up](../../OPENTDF-COGNITO-DECRYPT-ISSUE.md) for details.

!!! info "Why claims mode?"
    The OpenTDF platform has three entity resolution modes: `keycloak` (calls back to Keycloak's admin API), `claims` (reads attributes directly from the JWT), and `multi-strategy` (preview). Since Cognito includes custom attributes in its OIDC tokens, `claims` mode is all we need. No extra identity infrastructure.

## Run the ECS task with a public IP

Instead of setting up a load balancer, we'll run the task directly in a public subnet with a public IP assigned. This is the simplest way to make the KAS reachable.

1. Go to your **ECS cluster** `dcs-level3` > **Tasks** tab > **Run new task**
2. **Launch type**: Fargate
3. **Task definition**: `dcs-level3-opentdf`
4. **Networking**:
    - VPC: Default VPC
    - Subnets: Pick any one of the default public subnets
    - Security group: Create new > `dcs-level3-ecs-sg`
        - Inbound: Custom TCP, Port 8080, Source 0.0.0.0/0
    - **Public IP**: ENABLED (this is the key setting)
5. Click **Run task** (or **Create** depending on your console version)

## Find the public IP

1. Click on the running task
2. In the **Configuration** section, find the **Public IP** (e.g., `3.10.45.123`)
3. Note this IP, you'll use it as your KAS endpoint

Test it:

```bash
KAS_IP="YOUR-TASK-PUBLIC-IP"
curl http://$KAS_IP:8080/healthz
```

You should get a 200 response.

!!! note "The IP changes if the task restarts"
    Since we're not using a load balancer or Elastic IP, the public IP is dynamic. If the task stops and restarts, you'll get a new IP. For a demo this is fine, just note the new one. In production you'd put a load balancer or DNS in front.

!!! note "Troubleshooting"
    If the task keeps stopping, check CloudWatch logs (the task definition creates a log group automatically). Common issues:

    - **Database connection refused**: Check that the RDS security group allows inbound from the default VPC CIDR
    - **Wrong DB credentials**: Double-check the environment variables
    - **Image pull failure**: The task needs outbound internet access (default VPC public subnets have this via the internet gateway)
    - **Auth issuer unreachable**: Verify the Cognito issuer URL is correct

Next: **[Step 3: Configure Identity and Attributes](step3-identity.md)**
