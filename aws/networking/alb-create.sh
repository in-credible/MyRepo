#!/usr/bin/env bash
set -euo pipefail

# Create an Application Load Balancer, target group, and HTTP listener.
# Usage: ./alb-create.sh [-p profile] [-r region] --name <alb-name> --vpc-id <vpc-xxx> --subnets <subnet-ids-csv> --sgs <sg-ids-csv> --tg-name <tg-name> --tg-port <80>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; NAME=""; VPC_ID=""; SUBNETS=""; SGS=""; TG_NAME=""; TG_PORT=80
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --vpc-id)     VPC_ID="$2"; shift 2;;
    --subnets)    SUBNETS="$2"; shift 2;;
    --sgs)        SGS="$2"; shift 2;;
    --tg-name)    TG_NAME="$2"; shift 2;;
    --tg-port)    TG_PORT="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <alb-name> --vpc-id <vpc-xxx> --subnets <csv> --sgs <csv> --tg-name <name> --tg-port <80>"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$NAME" ]]; then read -rp "ALB name: " NAME; fi
if [[ -z "$VPC_ID" ]]; then read -rp "VPC ID: " VPC_ID; fi
if [[ -z "$SUBNETS" ]]; then read -rp "Public subnets (csv): " SUBNETS; fi
if [[ -z "$SGS" ]]; then read -rp "Security groups (csv): " SGS; fi
if [[ -z "$TG_NAME" ]]; then read -rp "Target group name: " TG_NAME; fi
read -rp "Target group port [${TG_PORT}]: " _tp; TG_PORT="${_tp:-$TG_PORT}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

TG_ARN=$(aws elbv2 create-target-group --name "$TG_NAME" --protocol HTTP --port "$TG_PORT" --vpc-id "$VPC_ID" --target-type ip --query 'TargetGroups[0].TargetGroupArn' --output text)
ALB_ARN=$(aws elbv2 create-load-balancer --name "$NAME" --subnets $(echo "$SUBNETS" | sed 's/,/ /g') --security-groups $(echo "$SGS" | sed 's/,/ /g') --scheme internet-facing --type application --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn="$TG_ARN" >/dev/null

DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB created: $ALB_ARN"
echo "Target group: $TG_ARN"
echo "Listener: HTTP:80"
echo "DNS: http://$DNS"
