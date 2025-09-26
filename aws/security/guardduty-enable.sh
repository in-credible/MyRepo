#!/usr/bin/env bash
set -euo pipefail

# Enable GuardDuty in one or all regions for the current account.
# Usage: ./guardduty-enable.sh [-p profile] [-r region] [--all-regions]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; ALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --all-regions) ALL=true; shift 1;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] [--all-regions]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if ! $ALL && [[ -z "$REGION" ]]; then read -rp "AWS region (leave blank to enable in all regions instead): " _r; REGION="${_r:-}"; fi
if [[ -z "$REGION" ]]; then read -rp "Enable in ALL regions? (y/N): " _a; [[ "${_a:-}" =~ ^[Yy]$ ]] && ALL=true || true; fi

if $ALL; then
  # Use a login in any region for auth
  source "$ROOT_DIR/aws-login.sh" "$PROFILE" "us-east-1"
  REGIONS=$(aws ec2 describe-regions --all-regions --query 'Regions[].RegionName' --output text)
  for reg in $REGIONS; do
    echo "Enabling GuardDuty in $reg..."
    AWS_REGION=$reg AWS_DEFAULT_REGION=$reg aws guardduty create-detector --enable >/dev/null || true
  done
  echo "GuardDuty enabled in all regions."
else
  source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"
  aws guardduty create-detector --enable >/dev/null || true
  echo "GuardDuty enabled in $REGION."
fi
