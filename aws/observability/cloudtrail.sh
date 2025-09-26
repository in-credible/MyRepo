#!/usr/bin/env bash
# CloudTrail helper that uses the repo-local AWS CLI config.
#
# Usage:
#   ./cloudtrail.sh [options] [command]
#
# Options:
#   -p, --profile <name>   AWS profile to use (default: default)
#   -r, --region  <name>   AWS region override (optional)
#
# Commands:
#   status   Show caller identity and selected config (default)
#   list     List CloudTrail trails
#
# Examples:
#   ./cloudtrail.sh status
#   ./cloudtrail.sh -p myprofile -r us-east-1 list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"
REGION=""
CMD="status"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile)
      PROFILE="$2"; shift 2 ;;
    -r|--region)
      REGION="$2"; shift 2 ;;
    status|list)
      CMD="$1"; shift ;;
    -h|--help)
      sed -n '1,60p' "$0" | sed -n '1,40p' ; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Source the login helper to set AWS_* env vars
if [[ -n "$REGION" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"
else
  # shellcheck disable=SC1091
  source "$ROOT_DIR/aws-login.sh" "$PROFILE"
fi

case "$CMD" in
  status)
    echo "== AWS Caller Identity =="
    aws sts get-caller-identity
    echo
    echo "== AWS Config =="
    aws configure list
    ;;
  list)
    echo "== CloudTrail Trails =="
    aws cloudtrail list-trails
    ;;
esac
