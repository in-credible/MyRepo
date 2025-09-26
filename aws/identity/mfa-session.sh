#!/usr/bin/env bash
set -euo pipefail

# Get a session token using MFA and export temporary credentials.
# Usage: source ./aws/mfa-session.sh [-p profile] [-r region] --serial <arn> --code <123456> [--duration 3600]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; SERIAL=""; CODE=""; DURATION=3600
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --serial)     SERIAL="$2"; shift 2;;
    --code)       CODE="$2"; shift 2;;
    --duration)   DURATION="$2"; shift 2;;
    -h|--help) echo "Usage: source $0 [-p profile] [-r region] --serial <arn> --code <123456> [--duration 3600]"; return 0 2>/dev/null || exit 0;;
    *) echo "Unknown arg: $1" >&2; return 1 2>/dev/null || exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$SERIAL" ]]; then read -rp "MFA Serial ARN (arn:aws:iam::ACCOUNT:mfa/USER): " SERIAL; fi
if [[ -z "$CODE" ]]; then read -rp "MFA one-time code: " CODE; fi
read -rp "Duration seconds [${DURATION}]: " _d; DURATION="${_d:-$DURATION}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

RESP_JSON=$(aws sts get-session-token --serial-number "$SERIAL" --token-code "$CODE" --duration-seconds "$DURATION")

export AWS_ACCESS_KEY_ID=$(echo "$RESP_JSON" | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$RESP_JSON" | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$RESP_JSON" | jq -r .Credentials.SessionToken)
unset AWS_PROFILE

echo "MFA session credentials exported."
echo "Run: aws sts get-caller-identity"
