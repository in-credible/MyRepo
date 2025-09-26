#!/usr/bin/env bash
# Simple helper to point AWS CLI at repo-local credentials/config and set a profile.
# Usage:
#   source ./aws/aws-login.sh [profile] [region]
# Examples:
#   source ./aws/aws-login.sh           # uses profile "default" and region from config
#   source ./aws/aws-login.sh dev us-east-1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_FILE="$SCRIPT_DIR/credentials"
CONFIG_FILE="$SCRIPT_DIR/config"

# Ensure files exist
if [[ ! -f "$CREDS_FILE" ]]; then
  cat > "$CREDS_FILE" <<'EOF'
# AWS credentials file stored with the project (for local use only)
# Fill with real values or SSO config as needed. Do NOT commit secrets.
[default]
aws_access_key_id = REPLACE_ME
aws_secret_access_key = REPLACE_ME

# Example additional profile
[myprofile]
aws_access_key_id = REPLACE_ME
aws_secret_access_key = REPLACE_ME
EOF
  echo "Created $CREDS_FILE with placeholders. Update it with real values."
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<'EOF'
# AWS config file stored with the project
[default]
region = us-east-1
output = json

# Example additional profile config
[profile myprofile]
region = us-east-1
output = json
EOF
  echo "Created $CONFIG_FILE with defaults. Adjust region/output as needed."
fi

PROFILE="${1:-default}"
REGION_OVERRIDE="${2:-}"

# Point AWS CLI to these files and set profile
export AWS_SHARED_CREDENTIALS_FILE="$CREDS_FILE"
export AWS_CONFIG_FILE="$CONFIG_FILE"
export AWS_PROFILE="$PROFILE"

# Optionally override region
if [[ -n "$REGION_OVERRIDE" ]]; then
  export AWS_REGION="$REGION_OVERRIDE"
  export AWS_DEFAULT_REGION="$REGION_OVERRIDE"
fi

# Basic checks
if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found. Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" >&2
  return 1 2>/dev/null || exit 1
fi

# Warn if placeholders are still present for the active profile
if grep -q "REPLACE_ME" "$CREDS_FILE"; then
  echo "Warning: $CREDS_FILE contains placeholder values. Update with real credentials or configure SSO." >&2
fi

echo "AWS CLI configured:"
echo "- AWS_PROFILE=$AWS_PROFILE"
echo "- AWS_SHARED_CREDENTIALS_FILE=$AWS_SHARED_CREDENTIALS_FILE"
echo "- AWS_CONFIG_FILE=$AWS_CONFIG_FILE"
if [[ -n "${AWS_REGION:-}" ]]; then
  echo "- AWS_REGION=$AWS_REGION"
fi
echo "Try: aws sts get-caller-identity"
