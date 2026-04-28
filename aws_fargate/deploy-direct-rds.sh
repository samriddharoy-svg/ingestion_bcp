#!/bin/bash
# Complete AWS Fargate Deployment Script - Option B: Direct RDS
# Simpler deployment: No EFS, single-phase pipeline

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
CLUSTER_NAME="stock-data-cluster"
ECR_REPOSITORY="stock-data-ingestion"
VPC_ID="vpc-XXXXXXXXX"
SUBNET_IDS=("subnet-XXXXXXXXX" "subnet-YYYYYYYYY")
SECURITY_GROUP_ID="sg-XXXXXXXXX"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Fargate Direct RDS Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Create ECS Cluster
echo -e "${YELLOW}[1/9] Creating ECS Cluster...${NC}"
aws ecs create-cluster \
    --cluster-name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
    --tags key=Project,value=StockDataPipeline || echo "Cluster already exists"

echo -e "${GREEN}✓ ECS Cluster ready${NC}"

# Step 2: Create CloudWatch Log Groups
echo -e "${YELLOW}[2/9] Creating CloudWatch Log Groups...${NC}"
aws logs create-log-group --log-group-name /ecs/stock-data-direct-rds --region ${AWS_REGION} || true
aws logs put-retention-policy --log-group-name /ecs/stock-data-direct-rds --retention-in-days 7 --region ${AWS_REGION}

echo -e "${GREEN}✓ Log groups created${NC}"

# Step 3: Build and Push Docker Image
echo -e "${YELLOW}[3/9] Building and pushing Docker image...${NC}"
./ecr-push.sh ${AWS_REGION} ${AWS_ACCOUNT_ID}

echo -e "${GREEN}✓ Docker image pushed${NC}"

# Step 4: Register ECS Task Definition
echo -e "${YELLOW}[4/9] Registering ECS Task Definition...${NC}"

# Update task definition with actual values
sed -i.bak "s/YOUR_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" ecs-task-definition-direct-rds.json
aws ecs register-task-definition \
    --cli-input-json file://ecs-task-definition-direct-rds.json \
    --region ${AWS_REGION}

# Restore backup
mv ecs-task-definition-direct-rds.json.bak ecs-task-definition-direct-rds.json

echo -e "${GREEN}✓ Task definition registered${NC}"

# Step 5: Create SNS Topic
echo -e "${YELLOW}[5/9] Creating SNS Topic...${NC}"
SNS_TOPIC_ARN=$(aws sns create-topic \
    --name StockDataPipelineNotifications \
    --region ${AWS_REGION} \
    --output text --query 'TopicArn')

echo -e "${GREEN}✓ SNS Topic created: ${SNS_TOPIC_ARN}${NC}"

# Step 6: Subscribe Email to SNS
read -p "Enter email for notifications: " EMAIL
aws sns subscribe \
    --topic-arn ${SNS_TOPIC_ARN} \
    --protocol email \
    --notification-endpoint ${EMAIL} \
    --region ${AWS_REGION}

echo -e "${YELLOW}Check your email and confirm the SNS subscription${NC}"

# Step 7: Create Step Functions State Machine
echo -e "${YELLOW}[7/9] Creating Step Functions State Machine...${NC}"

# Update state machine with actual values
sed -i.bak "s/YOUR_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" step-functions-direct-rds.json
sed -i.bak "s/subnet-XXXXXXXXX/${SUBNET_IDS[0]}/g" step-functions-direct-rds.json
sed -i.bak "s/subnet-YYYYYYYYY/${SUBNET_IDS[1]}/g" step-functions-direct-rds.json
sed -i.bak "s/sg-XXXXXXXXX/${SECURITY_GROUP_ID}/g" step-functions-direct-rds.json

aws stepfunctions create-state-machine \
    --name StockDataPipelineDirectRDS \
    --definition file://step-functions-direct-rds.json \
    --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/StepFunctionsExecutionRole \
    --region ${AWS_REGION}

# Restore backup
mv step-functions-direct-rds.json.bak step-functions-direct-rds.json

echo -e "${GREEN}✓ Step Functions State Machine created${NC}"

# Step 8: Create EventBridge Rule
echo -e "${YELLOW}[8/9] Creating EventBridge Rule...${NC}"

STATE_MACHINE_ARN="arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:StockDataPipelineDirectRDS"

aws events put-rule \
    --name HourlyStockDataFetchDirectRDS \
    --description "Trigger stock data pipeline (direct RDS) every hour" \
    --schedule-expression "cron(0 * * * ? *)" \
    --state ENABLED \
    --region ${AWS_REGION}

aws events put-targets \
    --rule HourlyStockDataFetchDirectRDS \
    --targets "Id"="1","Arn"="${STATE_MACHINE_ARN}","RoleArn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/EventBridgeStepFunctionsRole" \
    --region ${AWS_REGION}

echo -e "${GREEN}✓ EventBridge rule created${NC}"

# Step 9: Test Execution
echo -e "${YELLOW}[9/9] Testing Step Functions execution...${NC}"
read -p "Do you want to test the pipeline now? (y/n): " TEST

if [ "$TEST" == "y" ]; then
    EXECUTION_ARN=$(aws stepfunctions start-execution \
        --state-machine-arn ${STATE_MACHINE_ARN} \
        --name test-execution-$(date +%s) \
        --region ${AWS_REGION} \
        --output text --query 'executionArn')

    echo -e "${BLUE}Test execution started: ${EXECUTION_ARN}${NC}"
    echo -e "${BLUE}Monitor at: https://${AWS_REGION}.console.aws.amazon.com/states/home?region=${AWS_REGION}#/executions/details/${EXECUTION_ARN}${NC}"
fi

# Display Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "ECS Cluster: ${CLUSTER_NAME}"
echo -e "ECR Repository: ${ECR_REPOSITORY}"
echo -e "State Machine: StockDataPipelineDirectRDS"
echo -e "EventBridge Rule: HourlyStockDataFetchDirectRDS"
echo -e "SNS Topic: StockDataPipelineNotifications"
echo ""
echo -e "${BLUE}Architecture:${NC}"
echo -e "  Single-phase pipeline (no EFS)"
echo -e "  Direct write to RDS PostgreSQL"
echo -e "  32% cheaper than EFS+SQLite approach"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "1. Confirm SNS email subscription"
echo -e "2. Monitor CloudWatch Logs: /ecs/stock-data-direct-rds"
echo -e "3. View Step Functions executions in AWS Console"
echo -e "4. Check RDS database: ingest_db schema"
echo ""
echo -e "${GREEN}========================================${NC}"
