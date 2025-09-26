#!/usr/bin/env bash
set -euo pipefail

# Create an S3 bucket and enable server access logging to a target bucket.
# Usage: ./s3-create-logging.sh [-p profile] [-r region] --log-bucket <target> [--log-prefix <prefix>] <bucket-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi
source "$ROOT_DIR/storage/s3-lib.sh"

PROFILE="default"; REGION=""; LOG_BUCKET=""; LOG_PREFIX="logs/"; BUCKET="${BUCKET:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --log-bucket) LOG_BUCKET="$2"; shift 2;;
    --log-prefix) LOG_PREFIX="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --log-bucket <target> [--log-prefix <prefix>] <bucket-name>"; exit 0;;
    *) BUCKET="$1"; shift;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "${REGION}" ]]; then read -rp "AWS region (leave blank to use profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "${BUCKET:-}" ]]; then read -rp "Enter S3 bucket name: " BUCKET; fi
if [[ -z "$LOG_BUCKET" ]]; then read -rp "Enter target log bucket name: " LOG_BUCKET; fi
read -rp "Log prefix [${LOG_PREFIX}]: " _lp; LOG_PREFIX="${_lp:-$LOG_PREFIX}"
if [[ -z "${BUCKET}" || -z "$LOG_BUCKET" ]]; then echo "Bucket name and log bucket are required" >&2; exit 1; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

echo "Creating bucket with logging: $BUCKET -> $LOG_BUCKET ($LOG_PREFIX)"
create_bucket "$BUCKET"
wait_bucket "$BUCKET"
set_bucket_logging "$BUCKET" "$LOG_BUCKET" "$LOG_PREFIX"
set_public_access_block_all "$BUCKET"
echo "Done. Ensure target bucket policy grants log delivery permissions."
