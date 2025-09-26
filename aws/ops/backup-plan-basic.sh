#!/usr/bin/env bash
set -euo pipefail

# Create a basic AWS Backup vault and plan with daily/weekly/monthly retention.
# Usage: ./backup-plan-basic.sh [-p profile] [-r region] --name <base-name> [--daily 35] [--weekly 12] [--monthly 12]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; NAME="backup"; DAILY=35; WEEKLY=12; MONTHLY=12
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --daily)      DAILY="$2"; shift 2;;
    --weekly)     WEEKLY="$2"; shift 2;;
    --monthly)    MONTHLY="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --name <base-name> [--daily 35] [--weekly 12] [--monthly 12]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
read -rp "Base name [${NAME}]: " _n; NAME="${_n:-$NAME}"
read -rp "Daily retention days [${DAILY}]: " _d; DAILY="${_d:-$DAILY}"
read -rp "Weekly retention weeks [${WEEKLY}]: " _w; WEEKLY="${_w:-$WEEKLY}"
read -rp "Monthly retention months [${MONTHLY}]: " _m; MONTHLY="${_m:-$MONTHLY}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

VAULT_NAME="$NAME-vault"
aws backup create-backup-vault --backup-vault-name "$VAULT_NAME" >/dev/null || true

PLAN_DOC=$(jq -n \
  --arg name "$NAME-plan" \
  --arg daily "$DAILY" \
  --arg weekly "$WEEKLY" \
  --arg monthly "$MONTHLY" \
  '{
    BackupPlan: {
      BackupPlanName: $name,
      Rules: [
        {RuleName:"daily",TargetBackupVaultName:"'"$VAULT_NAME"'",ScheduleExpression:"cron(0 5 * * ? *)", StartWindowMinutes:60, CompletionWindowMinutes:180, Lifecycle:{DeleteAfterDays: ($daily|tonumber)}},
        {RuleName:"weekly",TargetBackupVaultName:"'"$VAULT_NAME"'",ScheduleExpression:"cron(0 6 ? * SUN *)", StartWindowMinutes:60, CompletionWindowMinutes:180, Lifecycle:{DeleteAfterDays: ( ($weekly|tonumber) * 7 )}},
        {RuleName:"monthly",TargetBackupVaultName:"'"$VAULT_NAME"'",ScheduleExpression:"cron(0 7 1 * ? *)", StartWindowMinutes:60, CompletionWindowMinutes:180, Lifecycle:{DeleteAfterDays: ( ($monthly|tonumber) * 30 )}}
      ]
    }
  }')

PLAN_ID=$(aws backup create-backup-plan --backup-plan "$PLAN_DOC" --query BackupPlanId --output text)
echo "Backup plan created: $PLAN_ID (vault: $VAULT_NAME)"
echo "Note: You must create selections to attach resources: aws backup create-backup-selection ..."
