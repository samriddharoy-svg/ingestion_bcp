# AWS Deployment Checklist

Print this and check off items as you complete them!

---

## 📋 Pre-Deployment Info to Gather

Write these down before starting:

| Item | Your Value |
|------|------------|
| AWS Account ID | _________________ |
| AWS Region | us-east-1 |
| Your Email | _________________ |
| RDS Endpoint | _________________ |
| RDS Username | _________________ |
| RDS Password | _________________ |
| RDS Database | ingest_db |

---

## ✅ Deployment Steps

### Part 1: AWS Console Setup (5 min)
- [ ] Logged into AWS Console
- [ ] Navigated to correct region (top right dropdown)

### Part 2: SNS Topic (10 min)
- [ ] Created SNS topic: `DataPipelineNotifications`
- [ ] SNS Topic ARN saved: `_______________________________`
- [ ] Email subscription created
- [ ] Email confirmed (checked inbox)
- [ ] Subscription status shows "Confirmed"

### Part 3: Secrets Manager (15 min)
- [ ] Created secret: `stock-api-keys`
- [ ] Created secret: `rds-credentials`
- [ ] Both secrets show in Secrets Manager list

### Part 4: EFS File System (20 min)
- [ ] Created EFS: `StockDataEFS`
- [ ] EFS status is "Available"
- [ ] VPC ID noted: `_______________________________`
- [ ] Created access point: `stock-data-access-point`
- [ ] Access point ARN saved: `_______________________________`

### Part 5: Upload Files to EFS (30 min)
- [ ] Launched EC2 instance: `EFS-Upload-Helper`
- [ ] Downloaded key pair file: `efs-helper-key.pem`
- [ ] Connected to EC2 instance
- [ ] Installed amazon-efs-utils
- [ ] Mounted EFS to /mnt/efs
- [ ] Created tar.gz of project files
- [ ] Uploaded files to EC2
- [ ] Extracted files to EFS
- [ ] Verified files with `ls -la /mnt/efs/`
- [ ] Terminated EC2 instance (important!)

### Part 6: IAM Roles (20 min)
- [ ] Created role: `LambdaStockDataExecutionRole`
- [ ] Attached policy: `AWSLambdaVPCAccessExecutionRole`
- [ ] Created inline policy: `StockDataCustomPolicy`
- [ ] Created role: `StepFunctionsStockPipelineRole`
- [ ] Created inline policy: `StepFunctionsInvokePolicy`
- [ ] Created role: `EventBridgeStepFunctionsRole`
- [ ] Created inline policy: `EventBridgeStartExecution`

### Part 7: Lambda Layer (15 min)
- [ ] Created lambda-layer directory
- [ ] Installed Python dependencies
- [ ] Created stock-data-layer.zip
- [ ] Uploaded layer to AWS
- [ ] Layer ARN saved: `_______________________________`

### Part 8: Lambda Functions (40 min)

**Function 1: FetchSingleStockData**
- [ ] Created function
- [ ] Uploaded lambda_fetch_single_stock.zip
- [ ] Set memory: 1024 MB
- [ ] Set timeout: 5 minutes
- [ ] Added environment variables (EFS_MOUNT_PATH, DB_PATH)
- [ ] Configured VPC (same as EFS)
- [ ] Added layer: stock-data-dependencies
- [ ] Added EFS file system
- [ ] Tested successfully

**Function 2: AggregateStockResults**
- [ ] Created function
- [ ] Uploaded lambda_aggregate_results.zip
- [ ] Set memory: 512 MB
- [ ] Set timeout: 1 minute
- [ ] Added layer: stock-data-dependencies
- [ ] Tested successfully

**Function 3: IngestToRDS**
- [ ] Created function
- [ ] Uploaded lambda_ingest_rds.zip
- [ ] Set memory: 2048 MB
- [ ] Set timeout: 15 minutes
- [ ] Added environment variables (EFS_MOUNT_PATH, DB_PATH, RDS_SECRET_NAME)
- [ ] Configured VPC
- [ ] Added layer: stock-data-dependencies
- [ ] Added EFS file system

### Part 9: Step Functions (15 min)
- [ ] Edited step-functions-parallel.json (replaced ${AWS_REGION} and ${AWS_ACCOUNT_ID})
- [ ] Created state machine: `StockDataPipeline`
- [ ] Used role: `StepFunctionsStockPipelineRole`
- [ ] Verified workflow diagram appears
- [ ] State machine ARN saved: `_______________________________`

### Part 10: EventBridge Schedule (10 min)
- [ ] Created rule: `DailyStockDataFetch`
- [ ] Set cron expression: `0 9 * * ? *`
- [ ] Set target: StockDataPipeline
- [ ] Used role: EventBridgeStepFunctionsRole
- [ ] Rule status shows "Enabled"

### Part 11: Testing (20 min)
- [ ] Tested Lambda: FetchSingleStockData
- [ ] Tested Lambda: AggregateStockResults
- [ ] Started Step Functions execution
- [ ] Execution completed successfully
- [ ] Received email notification
- [ ] Checked CloudWatch Logs
- [ ] Verified data in SQLite database

---

## 🎉 Post-Deployment

- [ ] Set up billing alert ($10 budget)
- [ ] Bookmarked Step Functions state machine URL
- [ ] Bookmarked CloudWatch Logs
- [ ] Documented all ARNs in safe location
- [ ] Scheduled follow-up check in 24 hours

---

## 📝 Important ARNs & IDs

Save these for future reference:

```
AWS Account ID: _________________________________

SNS Topic ARN:
arn:aws:sns:us-east-1:____________:DataPipelineNotifications

EFS Access Point ARN:
arn:aws:elasticfilesystem:us-east-1:____________:access-point/fsap-____________

Lambda Layer ARN:
arn:aws:lambda:us-east-1:____________:layer:stock-data-dependencies:1

Step Functions ARN:
arn:aws:states:us-east-1:____________:stateMachine:StockDataPipeline

Lambda Function ARNs:
- FetchSingleStockData: arn:aws:lambda:us-east-1:____________:function:FetchSingleStockData
- AggregateStockResults: arn:aws:lambda:us-east-1:____________:function:AggregateStockResults
- IngestToRDS: arn:aws:lambda:us-east-1:____________:function:IngestToRDS
```

---

## ⏱️ Time Estimate

- **Total time:** 2-3 hours
- **Can pause and resume:** Yes, at any checkpoint
- **Best done in:** One session to avoid forgetting details

---

## 🆘 If Something Goes Wrong

1. **Check CloudWatch Logs first** - most errors show here
2. **Verify VPC/Security groups** - most common issue
3. **Confirm IAM roles** - permission errors are second most common
4. **Re-read relevant section** in BEGINNER_DEPLOYMENT_GUIDE.md
5. **Test Lambda functions individually** before testing full pipeline

---

## 📅 Next Scheduled Run

The pipeline will run automatically at **9:00 AM UTC daily**.

**Your local time:** ___________ (convert from UTC)

**First expected run:** Tomorrow at 9:00 AM UTC

---

## ✅ Deployment Complete!

Date completed: _______________

Deployed by: _______________

**You did it!** 🎉 The pipeline is now running automatically.
