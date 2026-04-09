# Automate everything with Terraform

You've built all three DCS levels by hand. Now here's the Terraform to deploy the entire thing in one go.

This creates every resource from Labs 1, 2, and 3: the S3 bucket with labeled objects, the Lambda data service, Cognito user pools with test users, Verified Permissions with Cedar policies, the KMS key, the RDS database, and the OpenTDF platform on ECS Fargate.

The full Terraform source code is in the repository at [`terraform/labs-combined/`](https://github.com/iamtgray/dcs-data-exchange/tree/main/terraform/labs-combined).

!!! warning "This is demo infrastructure"
    No TLS, no private subnets, no multi-AZ, passwords in variables. Fine for learning. Not for production.

## Project structure

```
terraform/labs-combined/
├── main.tf           # Provider and data sources
├── variables.tf      # Input variables
├── outputs.tf        # Useful outputs (URLs, IDs)
├── lab1.tf           # S3 bucket, objects, labels, Lambda
├── lab2.tf           # Cognito, Verified Permissions, updated Lambda
├── lab3.tf           # KMS, RDS, ECS, OpenTDF platform
├── lambda/
│   └── lab2.py       # Lambda function code (Lab 2 version)
└── terraform.tfvars  # Your values
```

## Deploy

```bash
git clone https://github.com/iamtgray/dcs-data-exchange.git
cd dcs-data-exchange/terraform/labs-combined

# Edit terraform.tfvars to set your db_password
terraform init
terraform plan
terraform apply
```

After apply completes, Terraform prints the outputs including the platform URL (backed by an NLB with an Elastic IP, so it's stable). The ECS task takes a couple of minutes to start.

## Test it

### Lab 1 test (data + labels, no access control)

The Lambda deploys with the Lab 2 code, so you need to pass user attributes. To replicate the Lab 1 experience (everything returned), just pass a valid user:

```bash
FUNCTION_URL=$(terraform output -raw lambda_function_url)

curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "intel-report.txt",
    "username": "uk-analyst-01",
    "clearanceLevel": 2,
    "nationality": "GBR",
    "saps": ["WALL"]
  }' | python3 -m json.tool
```

### Lab 2 test (ABAC denial)

```bash
curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "operation-wall.txt",
    "username": "pol-analyst-01",
    "clearanceLevel": 2,
    "nationality": "POL",
    "saps": []
  }' | python3 -m json.tool
```

Expected: 403 -- Polish analyst doesn't have the WALL SAP.

### Lab 3 test (encrypt/decrypt)

Once the ECS task is running, the platform is reachable at the stable IP from the Terraform output:

```bash
export OPENTDF_ENDPOINT="$(terraform output -raw platform_url)"
export OIDC_ENDPOINT="$(terraform output -raw cognito_issuer_url)"
export OIDC_CLIENT_ID="$(terraform output -raw cognito_uk_client_id)"
```

Then follow the Lab 3 steps from Step 3 onwards (configure attributes, encrypt, decrypt). The OpenTDF attribute and subject mapping configuration still needs to be done via the API -- Terraform creates the infrastructure, but the OpenTDF platform's internal configuration (attribute namespaces and subject mappings) is done through its own REST API after it boots.

## Tear down

```bash
terraform destroy
```

This deletes everything across all three labs in one command. The KMS key enters a 7-day deletion waiting period (AWS minimum).
