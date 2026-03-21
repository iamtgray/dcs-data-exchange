# Step 3: Deploy the Key Access Server

The Key Access Server (KAS) is the core of DCS Level 3. It's the gatekeeper that decides whether to release a Data Encryption Key. We'll deploy the OpenTDF platform on ECS Fargate with a PostgreSQL database for state management.

## Create the RDS database

OpenTDF needs PostgreSQL for storing attribute definitions, entitlements, and audit logs.

1. Go to **RDS Console**: [https://console.aws.amazon.com/rds](https://console.aws.amazon.com/rds)
2. Click **Create database**
3. **Engine**: Aurora (PostgreSQL Compatible)
4. **Edition**: Aurora Serverless v2 (cost-effective for demos)
5. **Cluster identifier**: `dcs-level3-opentdf`
6. **Master username**: `opentdf`
7. **Master password**: Choose a strong password and save it
8. **Instance configuration**: Serverless v2, min 0.5 ACU, max 2 ACU
9. **Connectivity**:
    - VPC: `dcs-level3`
    - Subnet group: Create new, select your private subnets
    - VPC security group: Choose existing > `dcs-level3-rds-sg`
    - Public access: No
10. **Database name**: `opentdf`
11. Click **Create database** (this takes 5-10 minutes)

!!! info "While the database creates..."
    Continue with the ECS setup below. The database needs to be ready before ECS tasks start, but you can prepare everything else in parallel.

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
4. Add an inline policy with KMS permissions:

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
    Replace the Resource with your actual KMS key ARN from Step 2.

## Update the KMS key policy

Go back to KMS and add the task role to the key's usage permissions:

1. Open your `dcs-level3-kas-kek` key
2. Click **Key policy** > **Edit**
3. Add a statement allowing the ECS task role:

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

## Create the Application Load Balancer

1. Go to **EC2 Console** > **Load Balancers** > **Create Application Load Balancer**
2. **Name**: `dcs-level3-alb`
3. **Scheme**: Internet-facing
4. **Network**:
    - VPC: `dcs-level3`
    - Mappings: Select both public subnets
5. **Security group**: `dcs-level3-alb-sg`
6. **Listener**: HTTP:80 (we'll add HTTPS later, or use HTTP for the demo)
7. **Target group**: Create new
    - Name: `dcs-level3-opentdf-tg`
    - Target type: IP
    - Port: 8080
    - Health check path: `/healthz`
8. Click **Create load balancer**

Note the ALB DNS name (e.g., `dcs-level3-alb-123456789.eu-west-2.elb.amazonaws.com`).

## Create the ECS task definition

1. Go to **ECS** > **Task definitions** > **Create new task definition**
2. **Family**: `dcs-level3-opentdf`
3. **Launch type**: Fargate
4. **CPU**: 0.5 vCPU
5. **Memory**: 1 GB
6. **Task role**: `dcs-level3-kas-task-role`
7. **Task execution role**: `dcs-level3-ecs-execution-role`
8. **Container**:
    - Name: `opentdf`
    - Image: `ghcr.io/opentdf/platform:latest`
    - Port mappings: 8080 TCP
    - Environment variables:
        - `OPENTDF_DB_HOST` = your RDS cluster endpoint (e.g., `dcs-level3-opentdf.cluster-abc123.eu-west-2.rds.amazonaws.com`)
        - `OPENTDF_DB_PORT` = `5432`
        - `OPENTDF_DB_NAME` = `opentdf`
        - `OPENTDF_DB_USER` = `opentdf`
        - `OPENTDF_DB_PASSWORD` = your database password
        - `OPENTDF_SERVER_PORT` = `8080`
9. Click **Create**

!!! tip "Storing the password securely"
    For a production system, use AWS Secrets Manager or SSM Parameter Store for the database password. For this demo, environment variables work.

## Create the ECS service

1. Go to your **ECS cluster** > **Services** > **Create**
2. **Task definition**: `dcs-level3-opentdf`
3. **Service name**: `opentdf`
4. **Desired tasks**: 1 (for demo; use 2+ for production)
5. **Networking**:
    - VPC: `dcs-level3`
    - Subnets: Both private subnets
    - Security group: `dcs-level3-ecs-sg`
    - Public IP: Off
6. **Load balancing**:
    - Target group: `dcs-level3-opentdf-tg`
    - Container: `opentdf:8080`
7. Click **Create**

## Verify the deployment

Wait 2-3 minutes for the task to start, then check:

1. Go to your ECS service and check the **Tasks** tab - the task should be RUNNING
2. Check the ALB target group - the target should be healthy
3. Test the health endpoint:

```bash
curl http://YOUR-ALB-DNS:80/healthz
```

You should get a 200 response.

!!! note "Troubleshooting"
    If the task keeps stopping, check the CloudWatch logs at `/ecs/dcs-level3-opentdf`. Common issues: database connection refused (check security groups), wrong DB credentials, or image pull failures (check NAT gateway).

Next: **[Step 4: Configure Identity and Attributes](step4-identity.md)**
