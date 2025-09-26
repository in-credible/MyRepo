#!/usr/bin/env bash
set -euo pipefail

# Create an ECR repository and optionally log Docker into it.
# Usage: ./ecr-repo-create.sh [-p profile] [-r region] --name <repo> [--scan] [--kms-key <arn>] [--login]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; NAME=""; SCAN=false; KMS_KEY=""; LOGIN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --scan)       SCAN=true; shift 1;;
    --kms-key)    KMS_KEY="$2"; shift 2;;
    --login)      LOGIN=true; shift 1;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <repo> [--scan] [--kms-key <arn>] [--login]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$NAME" ]]; then read -rp "ECR repo name: " NAME; fi
read -rp "Enable image scan on push? (y/N): " _s; [[ "${_s:-}" =~ ^[Yy]$ ]] && SCAN=true || true
read -rp "Provide KMS key ARN for encryption (blank for AES256): " _k; KMS_KEY="${_k:-$KMS_KEY}"
read -rp "Docker login after creation? (y/N): " _l; [[ "${_l:-}" =~ ^[Yy]$ ]] && LOGIN=true || true

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

ENC_ARGS=()
if [[ -n "$KMS_KEY" ]]; then ENC_ARGS+=(--encryption-configuration encryptionType=KMS,kmsKey=$KMS_KEY); else ENC_ARGS+=(--encryption-configuration encryptionType=AES256); fi
SCAN_ARGS=()
if $SCAN; then SCAN_ARGS+=(--image-scanning-configuration scanOnPush=true); fi

aws ecr create-repository --repository-name "$NAME" "${ENC_ARGS[@]}" "${SCAN_ARGS[@]}" >/dev/null
echo "Repository created: $NAME"

if $LOGIN; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  REG="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  aws ecr get-login-password | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$REG.amazonaws.com"
  echo "Docker logged in to ECR."
fi
