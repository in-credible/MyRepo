#!/usr/bin/env bash
set -euo pipefail

# Create an S3 bucket with default SSE-KMS encryption using a specified KMS key.
# Usage: ./s3-create-encrypted-sse-kms.sh [-p profile] [-r region] --kms-key-id <key-id-or-arn> <bucket-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi
source "$ROOT_DIR/storage/s3-lib.sh"

PROFILE="default"; REGION=""; KMS_KEY_ID=""; BUCKET="${BUCKET:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --kms-key-id) KMS_KEY_ID="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --kms-key-id <key-id-or-arn> <bucket-name>"; exit 0;;
    *) BUCKET="$1"; shift;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "${REGION}" ]]; then read -rp "AWS region (leave blank to use profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "${BUCKET:-}" ]]; then read -rp "Enter S3 bucket name: " BUCKET; fi
if [[ -z "$KMS_KEY_ID" ]]; then read -rp "Enter KMS Key ID or ARN for SSE-KMS: " KMS_KEY_ID; fi
if [[ -z "${BUCKET}" || -z "$KMS_KEY_ID" ]]; then echo "Bucket name and KMS key ID are required" >&2; exit 1; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

echo "Creating encrypted (SSE-KMS) bucket: $BUCKET with KMS key: $KMS_KEY_ID"
create_bucket "$BUCKET"
wait_bucket "$BUCKET"
set_bucket_encryption_sse_kms "$BUCKET" "$KMS_KEY_ID"
set_public_access_block_all "$BUCKET"
echo "Done."
