#!/usr/bin/env bash
set -euo pipefail

# Create an S3 bucket and configure static website hosting.
# Note: Public access/policy for static hosting is not configured here.
# Usage: ./s3-create-website.sh [-p profile] [-r region] [--index index.html] [--error error.html] <bucket-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi
source "$ROOT_DIR/storage/s3-lib.sh"

PROFILE="default"; REGION=""; INDEX="index.html"; ERROR="error.html"; BUCKET="${BUCKET:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --index) INDEX="$2"; shift 2;;
    --error) ERROR="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] [--index file] [--error file] <bucket-name>"; exit 0;;
    *) BUCKET="$1"; shift;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "${REGION}" ]]; then read -rp "AWS region (leave blank to use profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "${BUCKET:-}" ]]; then read -rp "Enter S3 bucket name: " BUCKET; fi
read -rp "Index document [${INDEX}]: " _i; INDEX="${_i:-$INDEX}"
read -rp "Error document [${ERROR}]: " _e; ERROR="${_e:-$ERROR}"
if [[ -z "${BUCKET}" ]]; then echo "Bucket name required" >&2; exit 1; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

echo "Creating website bucket: $BUCKET (index=$INDEX error=$ERROR)"
create_bucket "$BUCKET"
wait_bucket "$BUCKET"
configure_website "$BUCKET" "$INDEX" "$ERROR"
echo "Website configured. Consider updating public access and bucket policy if needed."
