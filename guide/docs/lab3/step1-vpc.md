# Step 1: Set Up the Network

The OpenTDF platform and Keycloak need to run in a VPC with public and private subnets. The load balancer sits in public subnets, while the application containers and database sit in private subnets.

## Create the VPC

1. Go to **VPC Console**: [https://console.aws.amazon.com/vpc](https://console.aws.amazon.com/vpc)
2. Click **Create VPC**
3. Choose **VPC and more** (this creates subnets, route tables, and gateways for you)
4. Set:
    - **Name**: `dcs-level3`
    - **IPv4 CIDR**: `10.0.0.0/16`
    - **Number of Availability Zones**: 2
    - **Number of public subnets**: 2
    - **Number of private subnets**: 2
    - **NAT gateways**: In 1 AZ (needed for private subnets to reach the internet for container image pulls)
    - **VPC endpoints**: None (we'll keep it simple)
5. Click **Create VPC**

Wait for all resources to be created (this takes about 2 minutes).

## Note the subnet IDs

You'll need these in later steps. Go to **Subnets** and note:

- **Public subnet 1** ID (e.g., `subnet-0abc...`) - for the load balancer
- **Public subnet 2** ID - for the load balancer
- **Private subnet 1** ID - for ECS tasks and RDS
- **Private subnet 2** ID - for ECS tasks and RDS

## Create security groups

### ALB Security Group

1. Go to **Security Groups** > **Create security group**
2. **Name**: `dcs-level3-alb-sg`
3. **VPC**: Select `dcs-level3`
4. **Inbound rules**:
    - Type: HTTPS, Port: 443, Source: 0.0.0.0/0
    - Type: HTTP, Port: 80, Source: 0.0.0.0/0 (for redirect to HTTPS)
5. **Outbound rules**: All traffic (default)
6. Click **Create**

### ECS Security Group

1. **Name**: `dcs-level3-ecs-sg`
2. **VPC**: `dcs-level3`
3. **Inbound rules**:
    - Type: Custom TCP, Port: 8080, Source: `dcs-level3-alb-sg` (only ALB can reach containers)
    - Type: Custom TCP, Port: 8443, Source: `dcs-level3-alb-sg`
4. **Outbound rules**: All traffic
5. Click **Create**

### RDS Security Group

1. **Name**: `dcs-level3-rds-sg`
2. **VPC**: `dcs-level3`
3. **Inbound rules**:
    - Type: PostgreSQL, Port: 5432, Source: `dcs-level3-ecs-sg` (only ECS can reach the database)
4. **Outbound rules**: All traffic
5. Click **Create**

## What you've built

```
Internet
    |
    v
[ALB Security Group] - Port 443 from anywhere
    |
    v
[ECS Security Group] - Port 8080 from ALB only
    |
    v
[RDS Security Group] - Port 5432 from ECS only
```

This is a standard three-tier architecture. The database is only reachable from the application layer, which is only reachable from the load balancer.

Next: **[Step 2: Create the Key Store](step2-kms.md)**
