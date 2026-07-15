#!/usr/bin/env bash

# This script checks if the S3 bucket and DynamoDB table for Terraform remote state exist.
# If they do not exist, it automatically creates them in the target AWS region.

set -eo pipefail

BUCKET_NAME=${1}
REGION=${2}

if [ -z "$BUCKET_NAME" ] || [ -z "$REGION" ]; then
    echo "❌ Error: BUCKET_NAME and REGION must be provided."
    echo "Usage: $0 <bucket-name> <region>"
    exit 1
fi

echo "===================================================="
echo " Bootstrapping Terraform Backend Infrastructure..."
echo " Target S3 Bucket:      $BUCKET_NAME"
echo " AWS Region:            $REGION"
echo "===================================================="

# 1. Bootstrap S3 Bucket
echo "Checking S3 bucket existence..."
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo "ℹ️ Bucket '$BUCKET_NAME' does not exist or access is forbidden. Attempting to create it..."
    
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "✅ Successfully created S3 bucket '$BUCKET_NAME'."

    # Enable Versioning (Best practice for Terraform state to recover from accidental deletions)
    echo "Enabling S3 bucket versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$REGION"

    # Enable Default Encryption (Encrypt state files at rest)
    echo "Enabling S3 bucket default encryption (AES256)..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' \
        --region "$REGION"
else
    echo "✅ S3 Bucket '$BUCKET_NAME' already exists and is accessible."
fi



echo "===================================================="
echo "✅ State backend bootstrap completed successfully!"
echo "===================================================="
exit 0
