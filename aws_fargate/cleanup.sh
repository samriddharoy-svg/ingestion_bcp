#!/bin/bash
# Cleanup script to remove all AWS resources created by this pipeline
# WARNING: This will delete all resources - use with caution!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
CLUSTER_NAME="stock-data-cluster"
ECR_REPOSITORY="stock-data-ingestion"

echo -e "${RED}========================================${NC}"
echo -e "${RED}WARNING: Resource Cleanup${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}This will DELETE the following resources:${NC}"
echo "  - ECS Cluster: ${CLUSTER_NAME}"
echo "  - ECS Task Definitions"
echo "  - ECR Repository: ${ECR_REPOSITORY}"
echo "  - Step Functions State Machine: StockDataPipelineFargate"
echo "  - EventBridge Rule: HourlyStockDataFetch"
echo "  - SNS Topic: StockDataPipelineNotifications"
echo "  - CloudWatch Log Groups"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Delete EventBridge rule
echo -e "${YELLOW}[1/8] Removing EventBridge rule...${NC}"
aws events remove-targets --rule HourlyStockDataFetch --ids 1 --region ${AWS_REGION} || true
aws events delete-rule --name HourlyStockDataFetch --region ${AWS_REGION} || true
echo -e "${GREEN}✓ EventBridge rule removed${NC}"

# Delete Step Functions State Machine
echo -e "${YELLOW}[2/8] Deleting Step Functions State Machine...${NC}"
STATE_MACHINE_ARN="arn:aws:states:${AWS_REGION}:${AWS_ACCOUNT_ID}:stateMachine:StockDataPipelineFargate"
aws stepfunctions delete-state-machine --state-machine-arn ${STATE_MACHINE_ARN} --region ${AWS_REGION} || true
echo -e "${GREEN}✓ State Machine deleted${NC}"

# Delete SNS Topic
echo -e "${YELLOW}[3/8] Deleting SNS Topic...${NC}"
SNS_TOPIC_ARN="arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:StockDataPipelineNotifications"
aws sns delete-topic --topic-arn ${SNS_TOPIC_ARN} --region ${AWS_REGION} || true
echo -e "${GREEN}✓ SNS Topic deleted${NC}"

# Stop all running tasks
echo -e "${YELLOW}[4/8] Stopping running ECS tasks...${NC}"
TASKS=$(aws ecs list-tasks --cluster ${CLUSTER_NAME} --region ${AWS_REGION} --output text --query 'taskArns[]')
for TASK in $TASKS; do
    aws ecs stop-task --cluster ${CLUSTER_NAME} --task ${TASK} --region ${AWS_REGION} || true
done
echo -e "${GREEN}✓ Tasks stopped${NC}"

# Delete ECS Cluster
echo -e "${YELLOW}[5/8] Deleting ECS Cluster...${NC}"
aws ecs delete-cluster --cluster ${CLUSTER_NAME} --region ${AWS_REGION} || true
echo -e "${GREEN}✓ ECS Cluster deleted${NC}"

# Deregister Task Definitions
echo -e "${YELLOW}[6/8] Deregistering Task Definitions...${NC}"
FETCH_TASKS=$(aws ecs list-task-definitions --family-prefix stock-data-fetch-task --region ${AWS_REGION} --output text --query 'taskDefinitionArns[]')
for TASK_DEF in $FETCH_TASKS; do
    aws ecs deregister-task-definition --task-definition ${TASK_DEF} --region ${AWS_REGION} || true
done

INGEST_TASKS=$(aws ecs list-task-definitions --family-prefix stock-data-ingest-task --region ${AWS_REGION} --output text --query 'taskDefinitionArns[]')
for TASK_DEF in $INGEST_TASKS; do
    aws ecs deregister-task-definition --task-definition ${TASK_DEF} --region ${AWS_REGION} || true
done
echo -e "${GREEN}✓ Task Definitions deregistered${NC}"

# Delete ECR Repository
echo -e "${YELLOW}[7/8] Deleting ECR Repository...${NC}"
aws ecr delete-repository --repository-name ${ECR_REPOSITORY} --force --region ${AWS_REGION} || true
echo -e "${GREEN}✓ ECR Repository deleted${NC}"

# Delete CloudWatch Log Groups
echo -e "${YELLOW}[8/8] Deleting CloudWatch Log Groups...${NC}"
aws logs delete-log-group --log-group-name /ecs/stock-data-fetch --region ${AWS_REGION} || true
aws logs delete-log-group --log-group-name /ecs/stock-data-ingest --region ${AWS_REGION} || true
echo -e "${GREEN}✓ Log Groups deleted${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Note: IAM roles and EFS file system were not deleted for safety${NC}"
echo -e "${YELLOW}Please delete them manually if needed${NC}"
