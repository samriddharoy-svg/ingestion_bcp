# AWS Deployment Files

This directory contains all the necessary files to deploy the automated stock data pipeline to AWS.

## 📁 Files

| File | Description |
|------|-------------|
| `lambda_fetch_stocks.py` | Lambda function to fetch data from APIs to SQLite |
| `lambda_ingest_rds.py` | Lambda function to ingest SQLite data to RDS |
| `step-functions-state-machine.json` | Step Functions state machine definition |
| `deploy.sh` | Automated deployment script (partial automation) |
| `README.md` | This file |

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   aws configure
   ```

2. **AWS Account with permissions for:**
   - Lambda
   - Step Functions
   - EventBridge
   - EFS
   - Secrets Manager
   - SNS
   - IAM

3. **Project Information:**
   - VPC ID
   - Subnet IDs (2+ for EFS)
   - Security Group ID
   - RDS endpoint and credentials

### Step 1: Update Configuration

Edit `deploy.sh` and update these variables:

```bash
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
VPC_ID="vpc-xxxxxxxx"
SUBNET_IDS="subnet-xxxxxxxx,subnet-yyyyyyyy"
SECURITY_GROUP_ID="sg-xxxxxxxx"
RDS_HOST="your-rds-instance.us-east-1.rds.amazonaws.com"
RDS_DATABASE="ingest_db"
RDS_USERNAME="postgres"
RDS_PASSWORD="your-secure-password"
NOTIFICATION_EMAIL="your-email@example.com"
```

### Step 2: Run Deployment Script

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:
- ✅ Create SNS topic for notifications
- ✅ Create secrets in Secrets Manager
- ✅ Create Lambda layer with dependencies
- ⚠️ Provide instructions for manual steps (EFS, Lambda, Step Functions)

### Step 3: Manual Steps

#### 3.1 Create EFS File System

```bash
# 1. Go to AWS Console → EFS
# 2. Create file system:
#    - Performance mode: General Purpose
#    - Throughput mode: Bursting
#    - VPC: Your VPC
#    - Mount targets: Create in 2+ availability zones
#    - Security group: Allow NFS (port 2049) from Lambda security group

# 3. Create Access Point:
#    - Path: /
#    - POSIX user: 1000:1000
#    - Root directory creation permissions: 755
```

#### 3.2 Upload Files to EFS

```bash
# Launch EC2 instance in same VPC
# Install NFS client
sudo yum install -y nfs-utils  # Amazon Linux
# or
sudo apt-get install -y nfs-common  # Ubuntu

# Mount EFS
sudo mkdir /mnt/efs
sudo mount -t nfs4 -o nfsvers=4.1 fs-xxxxxxxx.efs.us-east-1.amazonaws.com:/ /mnt/efs

# Copy project files
sudo cp -r /path/to/ingestion/* /mnt/efs/
sudo chmod -R 755 /mnt/efs/
```

#### 3.3 Create IAM Roles

**Role 1: LambdaEFSExecutionRole (for FetchStocksData)**

Trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

Permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
        "elasticfilesystem:DescribeMountTargets",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:stock-api-keys-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Role 2: LambdaEFSRDSExecutionRole (for IngestToRDS)**

Same trust policy, permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientRead",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:rds-credentials-*",
        "arn:aws:secretsmanager:*:*:secret:stock-api-keys-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

#### 3.4 Create Lambda Functions

**FetchStocksData:**

```bash
# Create deployment package
cd aws_deployment
zip lambda_fetch_stocks.zip lambda_fetch_stocks.py

# Create Lambda function
aws lambda create-function \
  --function-name FetchStocksData \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/LambdaEFSExecutionRole \
  --handler lambda_fetch_stocks.lambda_handler \
  --timeout 900 \
  --memory-size 2048 \
  --environment Variables="{EFS_MOUNT_PATH=/mnt/efs,DB_PATH=/mnt/efs/portfolio.db}" \
  --file-system-configs Arn=arn:aws:elasticfilesystem:us-east-1:YOUR_ACCOUNT_ID:access-point/fsap-xxxxxxxx,LocalMountPath=/mnt/efs \
  --vpc-config SubnetIds=subnet-xxx,subnet-yyy,SecurityGroupIds=sg-xxxxxxxx \
  --layers arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:layer:stock-data-dependencies:1 \
  --zip-file fileb://lambda_fetch_stocks.zip \
  --region us-east-1
```

**IngestToRDS:**

```bash
# Create deployment package
zip lambda_ingest_rds.zip lambda_ingest_rds.py

# Create Lambda function
aws lambda create-function \
  --function-name IngestToRDS \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/LambdaEFSRDSExecutionRole \
  --handler lambda_ingest_rds.lambda_handler \
  --timeout 900 \
  --memory-size 2048 \
  --environment Variables="{EFS_MOUNT_PATH=/mnt/efs,DB_PATH=/mnt/efs/portfolio.db,RDS_SECRET_NAME=rds-credentials}" \
  --file-system-configs Arn=arn:aws:elasticfilesystem:us-east-1:YOUR_ACCOUNT_ID:access-point/fsap-xxxxxxxx,LocalMountPath=/mnt/efs \
  --vpc-config SubnetIds=subnet-xxx,subnet-yyy,SecurityGroupIds=sg-xxxxxxxx \
  --layers arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:layer:stock-data-dependencies:1 \
  --zip-file fileb://lambda_ingest_rds.zip \
  --region us-east-1
```

#### 3.5 Create Step Functions State Machine

1. Edit `step-functions-state-machine.json`
2. Replace `${AWS_REGION}` with your region (e.g., `us-east-1`)
3. Replace `${AWS_ACCOUNT_ID}` with your account ID

```bash
# Create state machine
aws stepfunctions create-state-machine \
  --name StockDataPipeline \
  --definition file://step-functions-state-machine.json \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/StepFunctionsExecutionRole \
  --region us-east-1
```

**StepFunctionsExecutionRole permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "arn:aws:lambda:*:*:function:FetchStocksData",
        "arn:aws:lambda:*:*:function:IngestToRDS"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:*:*:DataPipelineNotifications"
    }
  ]
}
```

#### 3.6 Create EventBridge Rule

```bash
# Create rule
aws events put-rule \
  --name DailyStockDataFetch \
  --description "Trigger stock data pipeline daily at 9:00 AM UTC" \
  --schedule-expression "cron(0 9 * * ? *)" \
  --state ENABLED \
  --region us-east-1

# Add Step Functions as target
aws events put-targets \
  --rule DailyStockDataFetch \
  --targets "Id"="1","Arn"="arn:aws:states:us-east-1:YOUR_ACCOUNT_ID:stateMachine:StockDataPipeline","RoleArn"="arn:aws:iam::YOUR_ACCOUNT_ID:role/EventBridgeStepFunctionsRole" \
  --region us-east-1
```

**EventBridgeStepFunctionsRole permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "states:StartExecution",
    "Resource": "arn:aws:states:*:*:stateMachine:StockDataPipeline"
  }]
}
```

## 🧪 Testing

### Test Lambda Functions

```bash
# Test FetchStocksData
aws lambda invoke \
  --function-name FetchStocksData \
  --payload '{}' \
  response.json \
  --region us-east-1

# Check response
cat response.json | jq '.'
```

### Test Step Functions

```bash
# Start execution
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:YOUR_ACCOUNT_ID:stateMachine:StockDataPipeline \
  --name test-$(date +%s) \
  --region us-east-1

# Get execution ARN from response, then check status
aws stepfunctions describe-execution \
  --execution-arn arn:aws:states:us-east-1:YOUR_ACCOUNT_ID:execution:StockDataPipeline:test-xxxxx \
  --region us-east-1
```

## 📊 Monitoring

### CloudWatch Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/FetchStocksData --follow --region us-east-1
aws logs tail /aws/lambda/IngestToRDS --follow --region us-east-1

# View Step Functions logs
aws logs tail /aws/states/StockDataPipeline --follow --region us-east-1
```

### CloudWatch Metrics

Monitor these metrics in CloudWatch Console:
- Lambda: Invocations, Duration, Errors
- Step Functions: ExecutionsStarted, ExecutionsSucceeded, ExecutionsFailed
- EFS: ClientConnections, DataReadIOBytes, DataWriteIOBytes

## 💰 Cost Estimation

| Service | Monthly Cost (approx.) |
|---------|------------------------|
| Lambda (2 functions, 30 runs/month) | $5 |
| Step Functions (30 executions) | $0.05 |
| EFS (1 GB storage) | $0.30 |
| Secrets Manager (2 secrets) | $0.80 |
| SNS (60 notifications) | Free |
| CloudWatch Logs (1 GB) | $0.50 |
| **Total** | **~$6.65/month** |

## 🔒 Security Checklist

- ✅ Secrets stored in Secrets Manager (not hardcoded)
- ✅ Lambda functions in private subnet
- ✅ VPC security groups restrict access
- ✅ IAM roles follow least privilege
- ✅ EFS encryption at rest enabled
- ✅ CloudWatch logging enabled

## 📚 Documentation

- [AWS_AUTOMATION_ARCHITECTURE.md](../AWS_AUTOMATION_ARCHITECTURE.md) - Full architecture documentation
- [CONTEXT.md](../CONTEXT.md) - Project context and implementation details
- [QUICKSTART_FETCH.md](../QUICKSTART_FETCH.md) - Local execution guide

## 🆘 Troubleshooting

### Lambda timeout errors
- Increase timeout in Lambda configuration (max 15 minutes)
- Check EFS mount performance mode

### EFS mount failures
- Verify security group allows NFS (port 2049)
- Check Lambda VPC configuration matches EFS mount targets
- Ensure IAM role has EFS permissions

### RDS connection errors
- Verify security group allows PostgreSQL (port 5432)
- Check RDS credentials in Secrets Manager
- Ensure Lambda in same VPC as RDS

### Step Functions failures
- Check CloudWatch Logs for Lambda errors
- Verify IAM role permissions
- Test Lambda functions individually first

## 📝 Change Log

- **2024-12-04**: Initial deployment files created
