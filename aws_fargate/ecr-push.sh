#!/bin/bash
# Script to build and push Docker image to AWS ECR
# Usage: ./ecr-push.sh [AWS_REGION] [AWS_ACCOUNT_ID]

set -e

# Configuration
AWS_REGION=${1:-"ap-south-1"}
AWS_ACCOUNT_ID=${2:-"YOUR_AWS_ACCOUNT_ID"}
ECR_REPOSITORY_NAME="stock-data-ingestion"
IMAGE_TAG=${3:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}AWS ECR Docker Image Push Script${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "AWS Region: ${YELLOW}${AWS_REGION}${NC}"
echo -e "AWS Account: ${YELLOW}${AWS_ACCOUNT_ID}${NC}"
echo -e "Repository: ${YELLOW}${ECR_REPOSITORY_NAME}${NC}"
echo -e "Image Tag: ${YELLOW}${IMAGE_TAG}${NC}"
echo ""

# ECR URL
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY="${ECR_URL}/${ECR_REPOSITORY_NAME}"

# Step 1: Create ECR repository if it doesn't exist
echo -e "${YELLOW}[1/5] Creating ECR repository (if not exists)...${NC}"
aws ecr describe-repositories \
    --repository-names ${ECR_REPOSITORY_NAME} \
    --region ${AWS_REGION} > /dev/null 2>&1 || \
aws ecr create-repository \
    --repository-name ${ECR_REPOSITORY_NAME} \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256

echo -e "${GREEN}✓ ECR repository ready${NC}"

# Step 2: Authenticate Docker to ECR
echo -e "${YELLOW}[2/5] Authenticating Docker to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_URL}

echo -e "${GREEN}✓ Docker authenticated${NC}"

# Step 3: Build Docker image
echo -e "${YELLOW}[3/5] Building Docker image...${NC}"
docker build -t ${ECR_REPOSITORY_NAME}:${IMAGE_TAG} .

echo -e "${GREEN}✓ Docker image built${NC}"

# Step 4: Tag image for ECR
echo -e "${YELLOW}[4/5] Tagging image for ECR...${NC}"
docker tag ${ECR_REPOSITORY_NAME}:${IMAGE_TAG} ${ECR_REPOSITORY}:${IMAGE_TAG}
docker tag ${ECR_REPOSITORY_NAME}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest

echo -e "${GREEN}✓ Image tagged${NC}"

# Step 5: Push to ECR
echo -e "${YELLOW}[5/5] Pushing image to ECR...${NC}"
docker push ${ECR_REPOSITORY}:${IMAGE_TAG}
docker push ${ECR_REPOSITORY}:latest

echo -e "${GREEN}✓ Image pushed successfully${NC}"

# Output
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Success! Image available at:${NC}"
echo -e "${YELLOW}${ECR_REPOSITORY}:${IMAGE_TAG}${NC}"
echo -e "${YELLOW}${ECR_REPOSITORY}:latest${NC}"
echo -e "${GREEN}======================================${NC}"
