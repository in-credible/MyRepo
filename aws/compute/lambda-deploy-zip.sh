#!/usr/bin/env bash
set -euo pipefail

# Create or update a Lambda function from a ZIP package.
# Usage: ./lambda-deploy-zip.sh [-p profile] [-r region] --name <fn> --runtime <rt> --handler <mod.handler> --zip <path> [--role-arn <arn>] [--memory 128] [--timeout 10]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; NAME=""; RUNTIME=""; HANDLER=""; ZIP=""; ROLE_ARN=""; MEMORY=128; TIMEOUT=10; ARCH="x86_64"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --runtime)    RUNTIME="$2"; shift 2;;
    --handler)    HANDLER="$2"; shift 2;;
    --zip)        ZIP="$2"; shift 2;;
    --role-arn)   ROLE_ARN="$2"; shift 2;;
    --memory)     MEMORY="$2"; shift 2;;
    --timeout)    TIMEOUT="$2"; shift 2;;
    --arch)       ARCH="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <fn> --runtime <rt> --handler <mod.handler> --zip <path> [--role-arn <arn>] [--memory 128] [--timeout 10] [--arch x86_64|arm64]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$NAME" ]]; then read -rp "Function name: " NAME; fi
if [[ -z "$RUNTIME" ]]; then read -rp "Runtime (e.g., python3.11, nodejs20.x): " RUNTIME; fi
if [[ -z "$HANDLER" ]]; then read -rp "Handler (module.handler): " HANDLER; fi
if [[ -z "$ZIP" ]]; then read -rp "Path to deployment ZIP: " ZIP; fi
if [[ -z "$ROLE_ARN" ]]; then read -rp "Execution role ARN (blank to reuse existing): " ROLE_ARN; fi
read -rp "Memory MB [${MEMORY}]: " _m; MEMORY="${_m:-$MEMORY}"
read -rp "Timeout seconds [${TIMEOUT}]: " _t; TIMEOUT="${_t:-$TIMEOUT}"
read -rp "Architecture [${ARCH}]: " _a; ARCH="${_a:-$ARCH}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

if aws lambda get-function --function-name "$NAME" >/dev/null 2>&1; then
  echo "Updating function code: $NAME"
  aws lambda update-function-code --function-name "$NAME" --zip-file "fileb://$ZIP" >/dev/null
  echo "Updating configuration"
  aws lambda update-function-configuration --function-name "$NAME" --runtime "$RUNTIME" --handler "$HANDLER" --memory-size "$MEMORY" --timeout "$TIMEOUT" --architectures "$ARCH" ${ROLE_ARN:+--role "$ROLE_ARN"} >/dev/null
else
  if [[ -z "$ROLE_ARN" ]]; then echo "Role ARN required for create." >&2; exit 1; fi
  echo "Creating function: $NAME"
  aws lambda create-function --function-name "$NAME" --runtime "$RUNTIME" --handler "$HANDLER" --zip-file "fileb://$ZIP" --role "$ROLE_ARN" --memory-size "$MEMORY" --timeout "$TIMEOUT" --architectures "$ARCH" >/dev/null
fi
echo "Done."
