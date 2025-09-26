#!/usr/bin/env bash
set -euo pipefail

# Create a multi-region CloudTrail (optionally organization trail) with S3 and optional KMS.
# Usage: ./cloudtrail-create-org.sh [-p profile] [-r region] --name <trail-name> --bucket <s3-bucket> [--org] [--kms-key-id <arn>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION="us-east-1"; NAME=""; BUCKET=""; ORG=false; KMS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --bucket)     BUCKET="$2"; shift 2;;
    --org)        ORG=true; shift 1;;
    --kms-key-id) KMS="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <trail-name> --bucket <s3-bucket> [--org] [--kms-key-id <arn>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
read -rp "Control plane region for CloudTrail [${REGION}]: " _r; REGION="${_r:-$REGION}"
if [[ -z "$NAME" ]]; then read -rp "Trail name: " NAME; fi
if [[ -z "$BUCKET" ]]; then read -rp "S3 bucket for logs: " BUCKET; fi
read -rp "Organization trail? (y/N): " _o; [[ "${_o:-}" =~ ^[Yy]$ ]] && ORG=true || true
if [[ -z "$KMS" ]]; then read -rp "KMS key ID/ARN for encryption (blank to skip): " KMS; fi

source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"

ARGS=(--name "$NAME" --s3-bucket-name "$BUCKET" --is-multi-region-trail)
$ORG && ARGS+=(--is-organization-trail)
[[ -n "$KMS" ]] && ARGS+=(--kms-key-id "$KMS")

aws cloudtrail create-trail "${ARGS[@]}" >/dev/null
aws cloudtrail update-trail --name "$NAME" --enable-log-file-validation >/dev/null
aws cloudtrail start-logging --name "$NAME"
echo "CloudTrail created and logging: $NAME (org=$ORG)"
