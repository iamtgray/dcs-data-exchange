#!/usr/bin/env bash
# test.sh - Validate DCS Level 3 Encryption infrastructure
#
# Tests that the OpenTDF platform infrastructure is deployed:
# KMS key, RDS database, ECS cluster/service, and S3 bucket.
#
# Full OpenTDF API testing requires the ECS task to be running
# and attribute/subject mappings configured via the platform API.
# This script validates the infrastructure layer.
#
# Usage: ./test.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
REGION="eu-west-2"
PROJECT="dcs-level-3"
export AWS_PAGER=""

echo "Testing Level 3 Encryption infrastructure"
echo "================================================"

check() {
  local test_name="$1"
  local result="$2"

  if [ "$result" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo -e "${GREEN}  PASS${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "${RED}  FAIL${NC} $test_name"
  fi
}

echo ""
echo "KMS"
echo "----"

KMS_KEY_ID=$(terraform output -raw kms_key_id 2>/dev/null)
key_state=$(aws kms describe-key --key-id "$KMS_KEY_ID" --region "$REGION" \
  --query "KeyMetadata.KeyState" --output text 2>/dev/null || echo "MISSING")
check "KMS key exists and is enabled" "$([ "$key_state" = "Enabled" ] && echo 0 || echo 1)"

key_usage=$(aws kms describe-key --key-id "$KMS_KEY_ID" --region "$REGION" \
  --query "KeyMetadata.KeyUsage" --output text 2>/dev/null || echo "")
check "KMS key usage is ENCRYPT_DECRYPT" "$([ "$key_usage" = "ENCRYPT_DECRYPT" ] && echo 0 || echo 1)"

alias_exists=$(aws kms list-aliases --region "$REGION" \
  --query "Aliases[?AliasName=='alias/${PROJECT}-kas-kek'].AliasName" --output text 2>/dev/null || echo "")
check "KMS alias ${PROJECT}-kas-kek exists" "$([ -n "$alias_exists" ] && echo 0 || echo 1)"

echo ""
echo "RDS"
echo "----"

RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null)
db_status=$(aws rds describe-db-instances --db-instance-identifier "${PROJECT}-opentdf" --region "$REGION" \
  --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null || echo "MISSING")
check "RDS instance is available" "$([ "$db_status" = "available" ] && echo 0 || echo 1)"

db_encrypted=$(aws rds describe-db-instances --db-instance-identifier "${PROJECT}-opentdf" --region "$REGION" \
  --query "DBInstances[0].StorageEncrypted" --output text 2>/dev/null || echo "false")
check "RDS storage is encrypted" "$([ "$db_encrypted" = "True" ] && echo 0 || echo 1)"

echo ""
echo "ECS"
echo "----"

CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
cluster_status=$(aws ecs describe-clusters --clusters "$CLUSTER" --region "$REGION" \
  --query "clusters[0].status" --output text 2>/dev/null || echo "MISSING")
check "ECS cluster is active" "$([ "$cluster_status" = "ACTIVE" ] && echo 0 || echo 1)"

service_count=$(aws ecs describe-services --cluster "$CLUSTER" --services "${PROJECT}-opentdf" --region "$REGION" \
  --query "services[0].desiredCount" --output text 2>/dev/null || echo "0")
check "ECS service desired count is 1" "$([ "$service_count" = "1" ] && echo 0 || echo 1)"

running_count=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "${PROJECT}-opentdf" --region "$REGION" \
  --desired-status RUNNING --query "length(taskArns)" --output text 2>/dev/null || echo "0")
if [ "$running_count" -ge "1" ] 2>/dev/null; then
  check "ECS task is running" 0
  task_arn=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "${PROJECT}-opentdf" --region "$REGION" \
    --query "taskArns[0]" --output text 2>/dev/null || echo "")
  if [ -n "$task_arn" ] && [ "$task_arn" != "None" ]; then
    eni=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$task_arn" --region "$REGION" \
      --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text 2>/dev/null || echo "")
    if [ -n "$eni" ] && [ "$eni" != "None" ]; then
      public_ip=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni" --region "$REGION" \
        --query "NetworkInterfaces[0].Association.PublicIp" --output text 2>/dev/null || echo "")
      if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
        echo -e "${YELLOW}  INFO${NC} OpenTDF platform at http://$public_ip:8080"

        # Try hitting the health endpoint
        health=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$public_ip:8080/healthz" 2>/dev/null || echo "000")
        check "OpenTDF health endpoint responds" "$([ "$health" = "200" ] && echo 0 || echo 1)"
      fi
    fi
  fi
else
  # Check if it's an image pull issue vs infra issue
  latest_event=$(aws ecs describe-services --cluster "$CLUSTER" --services "${PROJECT}-opentdf" --region "$REGION" \
    --query "services[0].events[0].message" --output text 2>/dev/null || echo "")
  if echo "$latest_event" | grep -q "CannotPullContainerError"; then
    FAIL=$((FAIL + 1))
    echo -e "${RED}  FAIL${NC} ECS task not running - container image pull failed"
    echo -e "${RED}       ${NC} Check the image name in ecs.tf is correct."
  else
    echo -e "${YELLOW}  WARN${NC} ECS task not yet running (running=$running_count). It may still be starting."
    FAIL=$((FAIL + 1))
    echo -e "${RED}  FAIL${NC} ECS task is running"
  fi
fi

echo ""
echo "S3"
echo "---"

bucket_name="dcs-lab-data-$(aws sts get-caller-identity --query Account --output text --region "$REGION")"
aws s3api head-bucket --bucket "$bucket_name" --region "$REGION" > /dev/null 2>&1
check "TDF data bucket exists" "$?"

echo ""
echo "================================================"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
