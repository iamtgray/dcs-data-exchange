# Clean up your AWS resources

To avoid ongoing charges, delete the resources you created. Work backwards through the labs.

## Lab 3 resources (delete first - these cost the most)

### ECS Task and Cluster
1. Go to **ECS Console** > cluster `dcs-level3`
2. Stop the running task (select it > **Stop**)
3. Delete the cluster once the task has stopped

### RDS Database
1. Go to **RDS Console** > Databases
2. Select `dcs-level3-opentdf` > **Actions** > **Delete**
3. Uncheck "Create final snapshot" for a demo environment
4. Type "delete me" and confirm

### ECS Task Definitions
1. Go to **ECS** > **Task definitions**
2. Deregister all revisions of `dcs-level3-opentdf`

### Security Groups
1. Go to **EC2** > **Security Groups**
2. Delete `dcs-level3-ecs-sg` and `dcs-level3-rds-sg`

### KMS Key
1. Go to **KMS Console**
2. Select `dcs-level3-kas-kek` > **Schedule key deletion**
3. Set waiting period to 7 days (minimum)

### IAM Roles
1. Delete `dcs-level3-ecs-execution-role`
2. Delete `dcs-level3-kas-task-role`

## Lab 2 resources

### Verified Permissions
1. Go to **Verified Permissions Console**
2. Delete your policy store

### Cognito User Pools
1. Go to **Cognito Console**
2. Delete `dcs-level2-uk-idp`, `dcs-level2-pol-idp`, `dcs-level2-us-idp`

### Lambda
1. Go to **Lambda Console**
2. Delete `dcs-lab-data-service` (the modified version from Lab 2)
3. Delete the execution role `dcs-lab-data-service-role`

## Lab 1 resources

### S3 Buckets
1. Empty `dcs-lab-data-...` bucket (select all objects > delete)
2. Delete the bucket

### CloudTrail
1. Go to **CloudTrail Console**
2. Check for any `dcs-*` trails and delete them

### IAM Roles
1. Delete any remaining `dcs-*` roles

## Verify cleanup

After deleting everything, check:

- **Cost Explorer**: Should show costs declining over the next day
- **IAM**: No remaining `dcs-*` users or roles
- **S3**: No remaining `dcs-*` buckets
- **ECS**: No running tasks or services

!!! tip "Use AWS Resource Groups"
    If you tagged all resources with `Project: dcs-level-1/2/3`, you can use Resource Groups to find any resources you might have missed.
