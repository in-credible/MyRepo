#!/usr/bin/env bash
set -euo pipefail

# Create an ECS Fargate cluster, task definition, and service.
# Usage: ./ecs-fargate-service.sh [-p profile] [-r region] --cluster <name> --service <name> --family <task-family> --container <name> --image <repo:tag> --port <80> --subnets <subnet-ids-csv> --security-groups <sg-ids-csv>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; CLUSTER=""; SERVICE=""; FAMILY=""; CONTAINER="app"; IMAGE=""; PORT="80"; SUBNETS=""; SGS=""; DESIRED=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --cluster)    CLUSTER="$2"; shift 2;;
    --service)    SERVICE="$2"; shift 2;;
    --family)     FAMILY="$2"; shift 2;;
    --container)  CONTAINER="$2"; shift 2;;
    --image)      IMAGE="$2"; shift 2;;
    --port)       PORT="$2"; shift 2;;
    --subnets)    SUBNETS="$2"; shift 2;;
    --security-groups) SGS="$2"; shift 2;;
    --desired)    DESIRED="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --cluster <name> --service <name> --family <task-family> --container <name> --image <repo:tag> --port <80> --subnets <csv> --security-groups <csv> [--desired 1]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$CLUSTER" ]]; then read -rp "Cluster name: " CLUSTER; fi
if [[ -z "$SERVICE" ]]; then read -rp "Service name: " SERVICE; fi
if [[ -z "$FAMILY" ]]; then read -rp "Task family name: " FAMILY; fi
read -rp "Container name [${CONTAINER}]: " _c; CONTAINER="${_c:-$CONTAINER}"
if [[ -z "$IMAGE" ]]; then read -rp "Container image (repo:tag): " IMAGE; fi
read -rp "Container port [${PORT}]: " _p2; PORT="${_p2:-$PORT}"
if [[ -z "$SUBNETS" ]]; then read -rp "Subnets (comma-separated subnet-ids): " SUBNETS; fi
if [[ -z "$SGS" ]]; then read -rp "Security groups (comma-separated sg-ids): " SGS; fi
read -rp "Desired count [${DESIRED}]: " _d; DESIRED="${_d:-$DESIRED}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

aws ecs create-cluster --cluster-name "$CLUSTER" >/dev/null || true

TASK_DEF=$(cat <<JSON
{
  "family": "$FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "$CONTAINER",
      "image": "$IMAGE",
      "essential": true,
      "portMappings": [{"containerPort": $PORT, "protocol": "tcp"}]
    }
  ]
}
JSON
)

REVISION_ARN=$(aws ecs register-task-definition --cli-input-json "$TASK_DEF" --query 'taskDefinition.taskDefinitionArn' --output text)

aws ecs create-service \
  --cluster "$CLUSTER" \
  --service-name "$SERVICE" \
  --task-definition "$REVISION_ARN" \
  --desired-count "$DESIRED" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(echo "$SUBNETS" | sed 's/,/,/g')],securityGroups=[$(echo "$SGS" | sed 's/,/,/g')],assignPublicIp=ENABLED}"

echo "ECS Fargate service created: $SERVICE in cluster $CLUSTER"
