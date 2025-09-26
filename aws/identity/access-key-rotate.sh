#!/usr/bin/env bash
set -euo pipefail

# Rotate an IAM user's access keys: create new, show secret, disable old.
# Usage: ./access-key-rotate.sh [-p profile] [-r region] --user <username>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; USER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --user)       USER="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --user <username>"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$USER" ]]; then read -rp "IAM username: " USER; fi
if [[ -z "$USER" ]]; then echo "Username is required" >&2; exit 1; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

EXISTING=$(aws iam list-access-keys --user-name "$USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
COUNT=$(wc -w <<< "$EXISTING" | tr -d ' ')
if (( COUNT >= 2 )); then echo "User already has 2 access keys; deactivate or delete one first." >&2; exit 1; fi

echo "Creating new access key for $USER..."
NEW=$(aws iam create-access-key --user-name "$USER")
NEW_ID=$(echo "$NEW" | jq -r .AccessKey.AccessKeyId)
NEW_SECRET=$(echo "$NEW" | jq -r .AccessKey.SecretAccessKey)
echo "New AccessKeyId: $NEW_ID"
echo "New SecretAccessKey (save securely): $NEW_SECRET"

if [[ -n "$EXISTING" ]]; then
  echo "Existing key(s): $EXISTING"
  read -rp "Deactivate existing key(s) now? (y/N): " _d
  if [[ "${_d:-}" =~ ^[Yy]$ ]]; then
    for key in $EXISTING; do aws iam update-access-key --user-name "$USER" --access-key-id "$key" --status Inactive; done
    echo "Old key(s) set to Inactive. Test new key before deletion."
  fi
fi
