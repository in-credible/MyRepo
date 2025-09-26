#!/usr/bin/env bash
set -euo pipefail

# Create a Glue crawler to catalog an S3 path.
# Usage: ./glue-crawler-create.sh [-p profile] [-r region] --name <crawler> --role-arn <arn> --s3 <s3://bucket/prefix/> [--db <database>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; NAME=""; ROLE_ARN=""; S3_TARGET=""; DB="default"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --role-arn)   ROLE_ARN="$2"; shift 2;;
    --s3)         S3_TARGET="$2"; shift 2;;
    --db)         DB="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <crawler> --role-arn <arn> --s3 <s3://bucket/prefix/> [--db <database>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$NAME" ]]; then read -rp "Crawler name: " NAME; fi
if [[ -z "$ROLE_ARN" ]]; then read -rp "Glue service role ARN: " ROLE_ARN; fi
if [[ -z "$S3_TARGET" ]]; then read -rp "S3 target (s3://bucket/prefix/): " S3_TARGET; fi
read -rp "Glue database name [${DB}]: " _d; DB="${_d:-$DB}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

aws glue create-crawler --name "$NAME" --role "$ROLE_ARN" --database-name "$DB" --targets S3Targets=[{Path="$S3_TARGET"}] >/dev/null
echo "Glue crawler created: $NAME -> $S3_TARGET (db=$DB)"
