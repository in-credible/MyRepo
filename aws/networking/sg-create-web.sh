#!/usr/bin/env bash
set -euo pipefail

# Create a web security group allowing 80/443 from the internet and SSH from a specified CIDR.
# Usage: ./sg-create-web.sh [-p profile] [-r region] --vpc-id <vpc-xxxx> --name <name> [--ssh-cidr <x.x.x.x/32>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; VPC_ID=""; NAME="web-sg"; SSH_CIDR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --vpc-id)     VPC_ID="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    --ssh-cidr)   SSH_CIDR="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --vpc-id <vpc-xxxx> --name <name> [--ssh-cidr <x.x.x.x/32>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$VPC_ID" ]]; then read -rp "VPC ID: " VPC_ID; fi
read -rp "Security group name [${NAME}]: " _n; NAME="${_n:-$NAME}"
if [[ -z "$SSH_CIDR" ]]; then read -rp "SSH allowed CIDR (blank to skip SSH): " SSH_CIDR; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

SG_ID=$(aws ec2 create-security-group --group-name "$NAME" --description "Web SG" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions 'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]' >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions 'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]' >/dev/null
if [[ -n "$SSH_CIDR" ]]; then aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$SSH_CIDR}]" >/dev/null; fi
aws ec2 authorize-security-group-egress --group-id "$SG_ID" --ip-permissions 'IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}]' >/dev/null || true

echo "Security group created: $SG_ID ($NAME)"
