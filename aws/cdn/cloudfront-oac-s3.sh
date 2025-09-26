#!/usr/bin/env bash
set -euo pipefail

# Create a CloudFront distribution with an Origin Access Control (OAC) for an S3 website/origin bucket.
# Usage: ./cloudfront-oac-s3.sh [-p profile] [-r region] --bucket <name> [--domain <CNAME>] [--comment <text>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/aws-login.sh" ]]; then ROOT_DIR="$SCRIPT_DIR"; else ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; fi

PROFILE="default"; REGION="us-east-1"; BUCKET=""; DOMAIN=""; COMMENT="S3 via OAC"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="$2"; shift 2;;
    -r|--region)  REGION="$2"; shift 2;;
    --bucket)     BUCKET="$2"; shift 2;;
    --domain)     DOMAIN="$2"; shift 2;;
    --comment)    COMMENT="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [-p profile] [-r region(us-east-1 for CF API)] --bucket <name> [--domain <CNAME>] [--comment <text>]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

read -rp "AWS profile [${PROFILE}]: " _p; PROFILE="${_p:-$PROFILE}"
read -rp "CloudFront control plane region [${REGION}] (usually us-east-1): " _r; REGION="${_r:-$REGION}"
if [[ -z "$BUCKET" ]]; then read -rp "S3 bucket name (origin): " BUCKET; fi
read -rp "Optional CNAME (blank to skip): " _d; DOMAIN="${_d:-$DOMAIN}"
read -rp "Comment [${COMMENT}]: " _c; COMMENT="${_c:-$COMMENT}"

# CloudFront is global; region is still passed for auth. Use us-east-1 typically.
source "$ROOT_DIR/aws-login.sh" "$PROFILE" "$REGION"

OAC_ID=$(aws cloudfront create-origin-access-control --origin-access-control-config '{"Name":"oac-'"$BUCKET"'","SigningProtocol":"sigv4","SigningBehavior":"always","OriginAccessControlOriginType":"s3"}' --query 'OriginAccessControl.Id' --output text)

DIST_CONFIG=$(cat <<JSON
{
  "CallerReference": "$(date +%s)-$BUCKET",
  "Comment": "$COMMENT",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "s3-$BUCKET",
        "DomainName": "$BUCKET.s3.amazonaws.com",
        "S3OriginConfig": {"OriginAccessIdentity": ""},
        "OriginAccessControlId": "$OAC_ID"
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-$BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "TrustedSigners": {"Enabled": false, "Quantity": 0},
    "TrustedKeyGroups": {"Enabled": false, "Quantity": 0},
    "ForwardedValues": {"QueryString": false, "Cookies": {"Forward": "none"}},
    "AllowedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"], "CachedMethods": {"Quantity": 2, "Items": ["GET", "HEAD"]}},
    "Compress": true
  },
  "ViewerCertificate": {"CloudFrontDefaultCertificate": true},
  "HttpVersion": "http2",
  "IsIPV6Enabled": true,
  "Aliases": {"Quantity": $( [[ -n "$DOMAIN" ]] && echo 1 || echo 0 ), "Items": ["$DOMAIN"]}
}
JSON
)

DIST_ID=$(aws cloudfront create-distribution --distribution-config "$DIST_CONFIG" --query 'Distribution.Id' --output text)
DIST_ARN="arn:aws:cloudfront::$(aws sts get-caller-identity --query Account --output text):distribution/$DIST_ID"

POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {"Service": "cloudfront.amazonaws.com"},
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::$BUCKET/*",
      "Condition": {"StringEquals": {"AWS:SourceArn": "$DIST_ARN"}}
    }
  ]
}
JSON
)

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"

DOMAIN_NAME=$(aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)
echo "CloudFront distribution created: $DIST_ID"
echo "OAC: $OAC_ID"
echo "Bucket policy updated for OAC."
echo "Domain: https://$DOMAIN_NAME"
