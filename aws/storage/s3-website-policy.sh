#!/usr/bin/env bash
set -euo pipefail

# Apply a public-read bucket policy for S3 static website hosting, or generate CloudFront OAC policy.
# Usage: ./s3-website-policy.sh [-p profile] [-r region] --bucket <name> [--mode public|oac] [--oac-id <id>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION=""; BUCKET=""; MODE="public"; OAC_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --bucket)     BUCKET="$2"; shift 2;;
    --mode)       MODE="$2"; shift 2;;
    --oac-id)     OAC_ID="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region] --bucket <name> [--mode public|oac] [--oac-id <id>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
if [[ -z "$REGION" ]]; then read -rp "AWS region (blank=profile default): " _r; REGION="${_r:-}"; fi
if [[ -z "$BUCKET" ]]; then read -rp "Bucket name: " BUCKET; fi
read -rp "Mode [${MODE}] (public/oac): " _m; MODE="${_m:-$MODE}"
if [[ "$MODE" == "oac" && -z "$OAC_ID" ]]; then read -rp "CloudFront OAC ID: " OAC_ID; fi

if [[ -n "$REGION" ]]; then source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"; else source "$ROOT_DIR/aws-login.sh" "$PROFILE"; fi

if [[ "$MODE" == "public" ]]; then
  echo "Warning: Applying public-read policy and may require disabling public access block."
  read -rp "Disable Block Public Access for this bucket? (y/N): " _b
  if [[ "${_b:-}" =~ ^[Yy]$ ]]; then
    aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
  fi
  POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
JSON
)
  aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"
  echo "Public website policy applied."
else
  POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {"Service": "cloudfront.amazonaws.com"},
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/*",
      "Condition": {"StringEquals": {"AWS:SourceArn": "arn:aws:cloudfront::$(aws sts get-caller-identity --query Account --output text):distribution/*"}}
    }
  ]
}
JSON
)
  if [[ -n "$OAC_ID" ]]; then
    POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOACReadOnly",
      "Effect": "Allow",
      "Principal": {"Service": "cloudfront.amazonaws.com"},
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/*",
      "Condition": {"StringEquals": {"AWS:SourceArn": "arn:aws:cloudfront::$(aws sts get-caller-identity --query Account --output text):distribution/*"}}
    }
  ]
}
JSON
)
  fi
  aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"
  echo "Bucket policy for CloudFront applied."
fi
