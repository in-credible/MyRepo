#!/usr/bin/env bash
set -euo pipefail

# Create an IAM role for Lambda with basic execution policy attached.
# Usage: ./iam-role-lambda.sh [-p profile] [-r region] --name <role-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <role-name>"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$NAME" ]]; then read -rp "Role name: " NAME; fi
if [[ -z "$NAME" ]]; then echo "Role name required" >&2; exit 1; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name "$NAME" --assume-role-policy-document "$TRUST" >/dev/null
aws iam attach-role-policy --role-name "$NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
echo "Role created and policy attached: $NAME"
