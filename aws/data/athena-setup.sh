#!/usr/bin/env bash
set -euo pipefail

# Create an Athena workgroup and set output S3 location.
# Usage: ./athena-setup.sh [-p profile] [-r region] --workgroup <name> --output s3://bucket/prefix/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; WORKGROUP=""; OUTPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --workgroup)  WORKGROUP="$2"; shift 2;;
    --output)     OUTPUT="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --workgroup <name> --output s3://bucket/prefix/"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$WORKGROUP" ]]; then read -rp "Workgroup name: " WORKGROUP; fi
if [[ -z "$OUTPUT" ]]; then read -rp "Output location (s3://bucket/prefix/): " OUTPUT; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

CFG=$(jq -n --arg out "$OUTPUT" '{ResultConfiguration: {OutputLocation: $out}}')
aws athena create-work-group --name "$WORKGROUP" --configuration "$CFG" --description "Workgroup $WORKGROUP" >/dev/null || aws athena update-work-group --work-group "$WORKGROUP" --state ENABLED --configuration-updates "$CFG"
echo "Athena workgroup configured: $WORKGROUP -> $OUTPUT"
