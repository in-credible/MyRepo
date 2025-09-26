#!/usr/bin/env bash
set -euo pipefail

# Assume an IAM role and export temporary credentials into the current shell.
# Usage: source ./aws/assume-role.sh [-p profile] [-r region] --role-arn <arn> [--session-name <name>] [--duration 3600]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; ROLE_ARN=""; SESSION_NAME="assumed-$(whoami)-$(date +%s)"; DURATION=3600
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --role-arn)   ROLE_ARN="$2"; shift 2;;
    --session-name) SESSION_NAME="$2"; shift 2;;
    --duration)   DURATION="$2"; shift 2;;
    -h|--help) echo "Usage: source $0 [-p profile] [-r region] --role-arn <arn> [--session-name <name>] [--duration 3600]"; return 0 2>/dev/null || exit 0;;
    *) echo "Unknown arg: $1" >&2; return 1 2>/dev/null || exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$ROLE_ARN" ]]; then read -rp "Role ARN to assume: " ROLE_ARN; fi
read -rp "Session name [${SESSION_NAME}]: " _s; SESSION_NAME="${_s:-$SESSION_NAME}"
read -rp "Duration seconds [${DURATION}]: " _d; DURATION="${_d:-$DURATION}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

RESP_JSON=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME" --duration-seconds "$DURATION")

export AWS_ACCESS_KEY_ID=$(echo "$RESP_JSON" | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$RESP_JSON" | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$RESP_JSON" | jq -r .Credentials.SessionToken)
unset AWS_PROFILE

echo "Assumed role into $ROLE_ARN. Temporary credentials exported."
echo "Run: aws sts get-caller-identity"
