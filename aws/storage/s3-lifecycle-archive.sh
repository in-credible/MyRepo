#!/usr/bin/env bash
set -euo pipefail

# Add a lifecycle rule to transition/expire objects in an S3 bucket.
# Usage: ./s3-lifecycle-archive.sh [-p profile] [-r region] --bucket <name> [--id <rule-id>] [--transition STANDARD_IA:30,GLACIER:60] [--expire 365]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; BUCKET=""; RULE_ID="archive-rule"; TRANSITIONS="STANDARD_IA:30"; EXPIRE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --bucket)     BUCKET="$2"; shift 2;;
    --id)         RULE_ID="$2"; shift 2;;
    --transition) TRANSITIONS="$2"; shift 2;;
    --expire)     EXPIRE="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --bucket <name> [--id <rule-id>] [--transition STANDARD_IA:30,GLACIER:60] [--expire 365]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$BUCKET" ]]; then read -rp "Bucket name: " BUCKET; fi
read -rp "Rule ID [${RULE_ID}]: " _i; RULE_ID="${_i:-$RULE_ID}"
read -rp "Transitions (CLASS:DAYS,CLASS:DAYS) [${TRANSITIONS}]: " _t; TRANSITIONS="${_t:-$TRANSITIONS}"
read -rp "Expiration days (blank to skip): " _e; EXPIRE="${_e:-$EXPIRE}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

# Build transitions JSON array
IFS=',' read -r -a PAIRS <<< "$TRANSITIONS"
TRANS_JSON="[]"
for pair in "${PAIRS[@]}"; do
  cls="${pair%%:*}"; days="${pair##*:}"
  TRANS_JSON=$(jq -c --arg c "$cls" --argjson d "$days" '. + [{"StorageClass":$c, "TransitionInDays":$d}]' <<< "$TRANS_JSON")
done

RULE=$(jq -n --arg id "$RULE_ID" --argjson transitions "$TRANS_JSON" --argjson expire ${EXPIRE:-null} '
  {Rules:[{ID:$id, Status:"Enabled", Filter:{}, Transitions:$transitions}]} | 
  if $expire!=null then .Rules[0].Expiration={Days:$expire} else . end')

aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration "$RULE"
echo "Lifecycle rule applied to $BUCKET: $RULE_ID"
