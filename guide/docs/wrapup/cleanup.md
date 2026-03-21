# Clean Up Your AWS Resources

To avoid ongoing charges, delete the resources you created. Work backwards through the labs.

## Lab 3 resources (delete first - these cost the most)

### ECS Services and Cluster
1. Go to **ECS Console** > cluster `dcs-level3`
2. Delete the `opentdf` service (set desired count to 0 first, then delete)
3. Delete the `keycloak` service if you created one
4. Delete the cluster

### RDS Database
1. Go to **RDS Console** > Databases
2. Select `dcs-level3-opentdf` > **Actions** > **Delete**
3. Uncheck "Create final snapshot" for a demo environment
4. Type "delete me" and confirm

### Load Balancer and Target Groups
1. Go to **EC2** > **Load Balancers** > delete `dcs-level3-alb`
2. Go to **Target Groups** > delete `dcs-level3-opentdf-tg`

### ECS Task Definitions
1. Go to **ECS** > **Task definitions**
2. Deregister all revisions of `dcs-level3-opentdf` and `dcs-level3-keycloak`

### VPC
1. Go to **VPC Console**
2. Delete the NAT Gateway first (this has an hourly charge)
3. Release the Elastic IP
4. Delete the VPC `dcs-level3` (this will delete subnets, route tables, etc.)

### KMS Key
1. Go to **KMS Console**
2. Select `dcs-level3-kas-kek` > **Schedule key deletion**
3. Set waiting period to 7 days (minimum)

### IAM Roles
1. Delete `dcs-level3-ecs-execution-role`
2. Delete `dcs-level3-kas-task-role`

## Lab 2 resources

### DynamoDB
1. Go to **DynamoDB Console** > Tables
2. Delete `dcs-level2-data`

### Verified Permissions
1. Go to **Verified Permissions Console**
2. Delete your policy store

### Cognito User Pools
1. Go to **Cognito Console**
2. Delete `dcs-level2-uk-idp`, `dcs-level2-pol-idp`, `dcs-level2-us-idp`

### Lambda
1. Delete `dcs-level2-data-service`
2. Delete the execution role `dcs-level2-service-role`

## Lab 1 resources

### S3 Buckets
1. Empty `dcs-level1-data-...` bucket (select all objects > delete)
2. Delete the bucket
3. Empty and delete `dcs-level1-audit-...` bucket

### CloudTrail
1. Go to **CloudTrail Console**
2. Delete trail `dcs-level1-audit`

### Lambda
1. Delete `dcs-level1-authorizer`
2. Delete role `dcs-level1-authorizer-role`

### IAM Users
1. Delete `dcs-user-gbr-secret`, `dcs-user-pol-ns`, `dcs-user-contractor`

## Verify cleanup

After deleting everything, check:

- **Cost Explorer**: Should show costs declining over the next day
- **IAM**: No remaining `dcs-*` users or roles
- **S3**: No remaining `dcs-*` buckets
- **ECS**: No running tasks or services

!!! tip "Use AWS Resource Groups"
    If you tagged all resources with `Project: dcs-level-1/2/3`, you can use Resource Groups to find any resources you might have missed.
