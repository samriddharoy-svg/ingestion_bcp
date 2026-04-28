#!/bin/bash

###############################################################################
# AWS Stock Data Pipeline Deployment Script
# Purpose: Deploy Step Functions, Lambda, EFS, EventBridge automation
# Date: December 4, 2024
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - UPDATE THESE VALUES
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
VPC_ID="vpc-xxxxxxxx"
SUBNET_IDS="subnet-xxxxxxxx,subnet-yyyyyyyy"  # Comma-separated
SECURITY_GROUP_ID="sg-xxxxxxxx"
RDS_HOST="your-rds-instance.us-east-1.rds.amazonaws.com"
RDS_DATABASE="ingest_db"
RDS_USERNAME="postgres"
RDS_PASSWORD="your-secure-password"

# API Keys
FMP_API_KEY="iyeAw4PFbtHWXtRCJ8mv6fAJ11RmNPoO"
TIINGO_API_KEY="37ee80c8063abdd83d1bd91311ac3a36cf86e658"

# Email for notifications
NOTIFICATION_EMAIL="your-email@example.com"

# Deployment names
STACK_NAME="stock-data-pipeline"
EFS_NAME="StockDataEFS"
LAMBDA_FETCH_NAME="FetchStocksData"
LAMBDA_INGEST_NAME="IngestToRDS"
STATE_MACHINE_NAME="StockDataPipeline"
SNS_TOPIC_NAME="DataPipelineNotifications"
EVENTBRIDGE_RULE_NAME="DailyStockDataFetch"

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   AWS Stock Data Pipeline - Deployment Script            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

print_status "AWS CLI configured"
echo ""

###############################################################################
# STEP 1: Create SNS Topic for Notifications
###############################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Creating SNS Topic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SNS_TOPIC_ARN=$(aws sns create-topic \
    --name $SNS_TOPIC_NAME \
    --region $AWS_REGION \
    --query 'TopicArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$SNS_TOPIC_ARN" ]; then
    # Topic might already exist
    SNS_TOPIC_ARN=$(aws sns list-topics --region $AWS_REGION \
        --query "Topics[?contains(TopicArn, '$SNS_TOPIC_NAME')].TopicArn" \
        --output text)
fi

print_status "SNS Topic: $SNS_TOPIC_ARN"

# Subscribe email
aws sns subscribe \
    --topic-arn $SNS_TOPIC_ARN \
    --protocol email \
    --notification-endpoint $NOTIFICATION_EMAIL \
    --region $AWS_REGION &> /dev/null || true

print_info "Email subscription sent to $NOTIFICATION_EMAIL (check inbox and confirm)"
echo ""

###############################################################################
# STEP 2: Create Secrets in Secrets Manager
###############################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Creating Secrets in Secrets Manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# API Keys Secret
API_SECRET="{\"FMP_API_KEY\":\"$FMP_API_KEY\",\"TIINGO_API_KEY\":\"$TIINGO_API_KEY\"}"

aws secretsmanager create-secret \
    --name stock-api-keys \
    --description "API keys for stock data fetching" \
    --secret-string "$API_SECRET" \
    --region $AWS_REGION &> /dev/null || \
aws secretsmanager update-secret \
    --secret-id stock-api-keys \
    --secret-string "$API_SECRET" \
    --region $AWS_REGION &> /dev/null

print_status "Created/Updated secret: stock-api-keys"

# RDS Credentials Secret
RDS_SECRET="{\"host\":\"$RDS_HOST\",\"port\":5432,\"username\":\"$RDS_USERNAME\",\"password\":\"$RDS_PASSWORD\",\"database\":\"$RDS_DATABASE\"}"

aws secretsmanager create-secret \
    --name rds-credentials \
    --description "RDS PostgreSQL credentials" \
    --secret-string "$RDS_SECRET" \
    --region $AWS_REGION &> /dev/null || \
aws secretsmanager update-secret \
    --secret-id rds-credentials \
    --secret-string "$RDS_SECRET" \
    --region $AWS_REGION &> /dev/null

print_status "Created/Updated secret: rds-credentials"
echo ""

###############################################################################
# STEP 3: Create Lambda Layer
###############################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Creating Lambda Layer with Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create layer directory
rm -rf lambda-layer
mkdir -p lambda-layer/python

# Install dependencies
print_info "Installing Python dependencies..."
pip install yfinance psycopg2-binary requests python-dotenv \
    -t lambda-layer/python/ --quiet

# Create layer ZIP
cd lambda-layer
zip -r stock-data-layer.zip python/ > /dev/null
cd ..

# Upload to AWS
LAYER_VERSION_ARN=$(aws lambda publish-layer-version \
    --layer-name stock-data-dependencies \
    --description "Python dependencies for stock data pipeline" \
    --zip-file fileb://lambda-layer/stock-data-layer.zip \
    --compatible-runtimes python3.11 \
    --region $AWS_REGION \
    --query 'LayerVersionArn' \
    --output text)

print_status "Lambda Layer created: $LAYER_VERSION_ARN"
echo ""

###############################################################################
# STEP 4: Create Lambda Functions
###############################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Creating Lambda Functions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_info "Note: EFS must be created manually first with access point"
print_info "Update EFS_ACCESS_POINT_ARN below with your EFS access point ARN"
echo ""

# You need to create EFS manually and provide the access point ARN
EFS_ACCESS_POINT_ARN="arn:aws:elasticfilesystem:$AWS_REGION:$AWS_ACCOUNT_ID:access-point/fsap-xxxxxxxx"

# TODO: Create Lambda functions (requires IAM roles first)
print_info "Lambda function creation skipped - requires IAM roles"
print_info "See deployment documentation for manual steps"
echo ""

###############################################################################
# STEP 5: Display Next Steps
###############################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS (Manual)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Create EFS file system in AWS Console"
echo "   - Performance mode: General Purpose"
echo "   - Create access point with path /mnt/efs"
echo ""
echo "2. Upload project files to EFS:"
echo "   - Mount EFS to EC2 instance"
echo "   - Copy all files from /Users/samriddha/Downloads/ingestion/"
echo ""
echo "3. Create IAM roles for Lambda functions"
echo "   - LambdaEFSExecutionRole (for FetchStocksData)"
echo "   - LambdaEFSRDSExecutionRole (for IngestToRDS)"
echo ""
echo "4. Create Lambda functions using AWS Console:"
echo "   - FetchStocksData (lambda_fetch_stocks.py)"
echo "   - IngestToRDS (lambda_ingest_rds.py)"
echo ""
echo "5. Create Step Functions state machine"
echo "   - Use step-functions-state-machine.json"
echo "   - Replace \${AWS_REGION} and \${AWS_ACCOUNT_ID}"
echo ""
echo "6. Create EventBridge rule"
echo "   - Schedule: cron(0 9 * * ? *)"
echo "   - Target: Step Functions state machine"
echo ""
echo "7. Confirm SNS email subscription"
echo "   - Check $NOTIFICATION_EMAIL inbox"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_status "Deployment preparation completed!"
echo ""
