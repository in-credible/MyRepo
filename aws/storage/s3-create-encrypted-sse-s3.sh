#!/usr/bin/env bash
set -euo pipefail

# Create an S3 bucket with default SSE-S3 (AES256) encryption.
# Usage: ./s3-create-encrypted-sse-s3.sh [-p profile] [-r region] <bucket-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi
source "$ROOT_DIR/storage/s3-lib.sh"

PROFILE="default"; REGION=""; BUCKET="${BUCKET:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] <bucket-name>"; exit 0;;
    *) BUCKET="$1"; shift;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "${REGION}" ]]; then read -rp "AWS region (leave blank to use profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "${BUCKET:-}" ]]; then read -rp "Enter S3 bucket name: " BUCKET; fi
if [[ -z "${BUCKET}" ]]; then echo "Bucket name required" >&2; exit 1; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

echo "Creating encrypted (SSE-S3) bucket: $BUCKET"
create_bucket "$BUCKET"
wait_bucket "$BUCKET"
set_bucket_encryption_sse_s3 "$BUCKET"
set_public_access_block_all "$BUCKET"
echo "Done."
