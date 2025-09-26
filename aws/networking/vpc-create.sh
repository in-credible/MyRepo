#!/usr/bin/env bash
set -euo pipefail

# Create a VPC with 2 public and 2 private subnets across 2 AZs, IGW, and 1 NAT GW.
# Usage: ./vpc-create.sh [-p profile] [-r region] --cidr 10.0.0.0/16 --name my-vpc

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; CIDR=""; NAME="my-vpc"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --cidr)       CIDR="$2"; shift 2;;
    --name)       NAME="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --cidr <vpc-cidr> [--name <name>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$CIDR" ]]; then read -rp "VPC CIDR (e.g., 10.0.0.0/16): " CIDR; fi
read -rp "VPC name tag [${NAME}]: " _n; NAME="${_n:-$NAME}"

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

ZONES=( $(aws ec2 describe-availability-zones --query 'AvailabilityZones[?State==`available`].ZoneName' --output text | awk '{print $1, $2}') )
AZ1=${ZONES[0]}; AZ2=${ZONES[1]:-$AZ1}

VPC_ID=$(aws ec2 create-vpc --cidr-block "$CIDR" --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$NAME"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

PUB_RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$PUB_RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null

PUB1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text)
PUB2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text)
PRI1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.11.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text)
PRI2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.12.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text)

for s in "$PUB1" "$PUB2"; do aws ec2 modify-subnet-attribute --subnet-id "$s" --map-public-ip-on-launch; done

aws ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB1" >/dev/null
aws ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB2" >/div/null 2>/dev/null || aws ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB2" >/dev/null

EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id "$PUB1" --allocation-id "$EIP_ALLOC" --query 'NatGateway.NatGatewayId' --output text)
echo "Waiting for NAT gateway to be available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID"

PRI_RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$PRI_RT_ID" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" >/dev/null
aws ec2 associate-route-table --route-table-id "$PRI_RT_ID" --subnet-id "$PRI1" >/dev/null
aws ec2 associate-route-table --route-table-id "$PRI_RT_ID" --subnet-id "$PRI2" >/dev/null

echo "VPC created: $VPC_ID"
echo "Public subnets: $PUB1, $PUB2"
echo "Private subnets: $PRI1, $PRI2"
