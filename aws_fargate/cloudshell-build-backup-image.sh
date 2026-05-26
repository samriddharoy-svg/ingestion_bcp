#!/bin/bash
# Run these commands in AWS CloudShell (ap-south-1 region)
# They build the backup Docker image and push it to ECR

set -e

ACCOUNT_ID=724134393175
REGION=ap-south-1
ECR_REPO=stock-ingestion-backup
IMAGE_TAG=latest

# 1. Authenticate Docker to ECR
aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin \
    $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# 2. Clone (or upload) the repo — if already uploaded via CloudShell file upload:
# cd ingestion   ← adjust to wherever you uploaded it

# 3. Build the backup stage from the multi-stage Dockerfile
docker build \
  --target backup-rds \
  -t $ECR_REPO:$IMAGE_TAG \
  .

# 4. Tag for ECR
docker tag $ECR_REPO:$IMAGE_TAG \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

# 5. Push to ECR
docker push \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

echo "Done — image pushed to ECR as $ECR_REPO:$IMAGE_TAG"
