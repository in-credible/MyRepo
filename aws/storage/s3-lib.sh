#!/usr/bin/env bash
set -euo pipefail

# Common helpers for S3 bucket creation scripts.

# create_bucket <bucket_name> [region] [object_lock]
# - region: if empty, uses env; if 'us-east-1', omit LocationConstraint
# - object_lock: true/false (default false)
create_bucket() {
  local bucket="$1"; shift || true
  local region="${1:-${AWS_REGION:-${AWS_DEFAULT_REGION:-}}}"; shift || true
  local object_lock="${1:-false}"

  if [[ -z "$bucket" ]]; then
    echo "Bucket name is required" >&2
    return 1
  fi

  local create_args=("s3api" "create-bucket" "--bucket" "$bucket")
  if [[ -n "$region" && "$region" != "us-east-1" ]]; then
    create_args+=("--create-bucket-configuration" "LocationConstraint=$region")
  fi
  if [[ "$object_lock" == "true" ]]; then
    create_args+=("--object-lock-enabled-for-bucket")
  fi

  aws "${create_args[@]}"
}

wait_bucket() {
  local bucket="$1"
  aws s3api wait bucket-exists --bucket "$bucket"
}

enable_versioning() {
  local bucket="$1"
  aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
}

set_public_access_block_all() {
  local bucket="$1"
  aws s3api put-public-access-block \
    --bucket "$bucket" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
}

set_bucket_encryption_sse_s3() {
  local bucket="$1"
  aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
}

set_bucket_encryption_sse_kms() {
  local bucket="$1"; local kms_key_id="$2"
  aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"'"$kms_key_id"'"}}]}'
}

enable_transfer_acceleration() {
  local bucket="$1"
  aws s3api put-bucket-accelerate-configuration --bucket "$bucket" --accelerate-configuration Status=Enabled
}

set_bucket_logging() {
  local bucket="$1"; local target_bucket="$2"; local prefix="${3:-logs/}"
  aws s3api put-bucket-logging --bucket "$bucket" --bucket-logging-status '{"LoggingEnabled":{"TargetBucket":"'"$target_bucket"'","TargetPrefix":"'"$prefix"'"}}'
}

enable_requester_pays() {
  local bucket="$1"
  aws s3api put-bucket-request-payment --bucket "$bucket" --request-payment-configuration Payer=Requester
}

disable_acls_bucket_owner_enforced() {
  local bucket="$1"
  aws s3api put-bucket-ownership-controls --bucket "$bucket" --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}'
}

configure_website() {
  local bucket="$1"; local index_doc="${2:-index.html}"; local error_doc="${3:-error.html}"
  aws s3api put-bucket-website --bucket "$bucket" --website-configuration '{"IndexDocument":{"Suffix":"'"$index_doc"'"},"ErrorDocument":{"Key":"'"$error_doc"'"}}'
}

