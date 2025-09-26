#!/usr/bin/env bash
set -euo pipefail

# Create basic CloudWatch alarms for an EC2 instance (CPUUtilization and StatusCheckFailed) and optionally attach an SNS topic.
# Usage: ./cloudwatch-alarms-basic.sh [-p profile] [-r region] --instance-id <id> [--sns-arn <arn>] [--cpu-threshold 80] [--namespace AWS/EC2]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; INSTANCE_ID=""; SNS_ARN=""; CPU_THRESH=80; NAMESPACE="AWS/EC2"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --instance-id) INSTANCE_ID="$2"; shift 2;;
    --sns-arn)    SNS_ARN="$2"; shift 2;;
    --cpu-threshold) CPU_THRESH="$2"; shift 2;;
    --namespace)  NAMESPACE="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --instance-id <id> [--sns-arn <arn>] [--cpu-threshold 80] [--namespace AWS/EC2]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$INSTANCE_ID" ]]; then read -rp "EC2 Instance ID: " INSTANCE_ID; fi
if [[ -z "$SNS_ARN" ]]; then read -rp "SNS Topic ARN for notifications (blank to skip): " SNS_ARN; fi
read -rp "CPU threshold [${CPU_THRESH}]: " _c; CPU_THRESH="${_c:-$CPU_THRESH}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

ALARM_ACTIONS=(); [[ -n "$SNS_ARN" ]] && ALARM_ACTIONS+=(--alarm-actions "$SNS_ARN")

aws cloudwatch put-metric-alarm --alarm-name "EC2-$INSTANCE_ID-CPUUtilization-High" \
  --metric-name CPUUtilization --namespace "$NAMESPACE" --statistic Average --period 300 --threshold "$CPU_THRESH" \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
  --evaluation-periods 2 --treat-missing-data missing --actions-enabled ${SNS_ARN:+true} "${ALARM_ACTIONS[@]}"

aws cloudwatch put-metric-alarm --alarm-name "EC2-$INSTANCE_ID-StatusCheckFailed" \
  --metric-name StatusCheckFailed --namespace "$NAMESPACE" --statistic Maximum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
  --evaluation-periods 1 --treat-missing-data breaching --actions-enabled ${SNS_ARN:+true} "${ALARM_ACTIONS[@]}"

echo "Alarms created for $INSTANCE_ID"
