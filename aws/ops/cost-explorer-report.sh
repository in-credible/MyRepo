#!/usr/bin/env bash
set -euo pipefail

# Quick AWS Cost Explorer report by service.
# Usage: ./cost-explorer-report.sh [-p profile] [-r region] [--granularity DAILY|MONTHLY] [--start YYYY-MM-DD] [--end YYYY-MM-DD]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION="us-east-1"; GRAN="MONTHLY"; START=""; END=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --granularity) GRAN="$2"; shift 2;;
    --start)      START="$2"; shift 2;;
    --end)        END="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] [--granularity DAILY|MONTHLY] [--start YYYY-MM-DD] [--end YYYY-MM-DD]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
read -rp "Cost Explorer API region [${REGION}]: " _r; REGION="${_r:-$REGION}"
read -rp "Granularity [${GRAN}] (DAILY/MONTHLY): " _g; GRAN="${_g:-$GRAN}"
if [[ -z "$START" || -z "$END" ]]; then
  read -rp "Start date (YYYY-MM-DD) [30 days ago]: " _s; START="${_s:-$(date -v-30d +%F 2>/dev/null || date -d '30 days ago' +%F)}"
  read -rp "End date (YYYY-MM-DD) [today]: " _e; END="${_e:-$(date +%F)}"
fi

source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"

aws ce get-cost-and-usage \
  --time-period Start="$START",End="$END" \
  --granularity "$GRAN" \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[].Groups[].{Service:Keys[0],Cost:Metrics.UnblendedCost.Amount}' \
  --output table
