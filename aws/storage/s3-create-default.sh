#!/usr/bin/env bash
set -euo pipefail

# Create a standard private S3 bucket with public access blocked.
# Usage: ./s3-create-default.sh [-p profile] [-r region] <bucket-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Determine aws root directory
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

# Interactive prompts for missing inputs
read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "${REGION}" ]]; then read -rp "AWS region (leave blank to use profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "${BUCKET:-}" ]]; then read -rp "Enter S3 bucket name: " BUCKET; fi
if [[ -z "${BUCKET}" ]]; then echo "Bucket name required" >&2; exit 1; fi

# Source login after parsing flags to set env
if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

_show_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-unset}}"
echo "Creating bucket: $BUCKET (profile=$AWS_PROFILE region=$_show_region)"
create_bucket "$BUCKET"
wait_bucket "$BUCKET"
set_public_access_block_all "$BUCKET"
echo "Done."
