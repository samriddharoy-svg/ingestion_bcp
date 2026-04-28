# Complete AWS Deployment Guide for Beginners

**Target Audience:** Complete AWS beginners with AWS account access
**Time Required:** 2-3 hours
**Cost:** ~$6.65/month after deployment

---

## 📋 Prerequisites Checklist

Before starting, make sure you have:

- [ ] AWS account with admin access
- [ ] AWS Console login credentials (email + password)
- [ ] Project files on your computer (`/Users/samriddha/Downloads/ingestion/`)
- [ ] RDS PostgreSQL database already created (endpoint URL)
- [ ] 2-3 hours of uninterrupted time

---

## 🎯 What We're Building

```
EventBridge (Daily 9 AM)
    ↓
Step Functions (processes 9 stocks in parallel)
    ↓
Lambda Functions (fetch data from APIs)
    ↓
EFS (shared storage for SQLite database)
    ↓
Lambda Functions (ingest to RDS)
    ↓
RDS PostgreSQL (your final data)
    ↓
SNS (email notifications)
```

---

## 🚀 Part 1: AWS Console Setup (15 minutes)

### Step 1.1: Log into AWS Console

1. Go to: https://aws.amazon.com/console/
2. Click **"Sign In to the Console"**
3. Enter your email and password
4. You should see the AWS Console homepage

**What you'll see:** Black navigation bar at top, search box in center

---

## 📦 Part 2: Create SNS Topic for Notifications (10 minutes)

SNS will send you email notifications when the pipeline runs.

### Step 2.1: Navigate to SNS

1. In the AWS Console, click the **search box** at the top
2. Type: `SNS`
3. Click **"Simple Notification Service"**

### Step 2.2: Create Topic

1. In the left sidebar, click **"Topics"**
2. Click orange **"Create topic"** button
3. Fill in:
   - **Type:** Standard (selected by default)
   - **Name:** `DataPipelineNotifications`
   - **Display name:** `Stock Data Pipeline`
4. Scroll down, click **"Create topic"**

**Copy this ARN!** You'll see something like:
```
arn:aws:sns:us-east-1:123456789012:DataPipelineNotifications
```
Save this in a notepad - you'll need it later.

### Step 2.3: Subscribe Your Email

1. Click **"Create subscription"** button
2. Fill in:
   - **Protocol:** Email
   - **Endpoint:** your-email@example.com (use your real email)
3. Click **"Create subscription"**
4. Check your email inbox
5. Click the **"Confirm subscription"** link in the email

**Verification:** Refresh the SNS subscriptions page - Status should show "Confirmed"

---

## 🔐 Part 3: Store Secrets in Secrets Manager (15 minutes)

### Step 3.1: Navigate to Secrets Manager

1. Click the search box at top
2. Type: `Secrets Manager`
3. Click **"Secrets Manager"**

### Step 3.2: Create API Keys Secret

1. Click **"Store a new secret"** button
2. Select **"Other type of secret"**
3. Under "Key/value pairs", click **"Plaintext"** tab
4. Delete everything and paste this (update with your actual keys):

```json
{
  "FMP_API_KEY": "iyeAw4PFbtHWXtRCJ8mv6fAJ11RmNPoO",
  "TIINGO_API_KEY": "37ee80c8063abdd83d1bd91311ac3a36cf86e658"
}
```

5. Click **"Next"**
6. Secret name: `stock-api-keys`
7. Description: `API keys for stock data fetching`
8. Click **"Next"** → **"Next"** → **"Store"**

### Step 3.3: Create RDS Credentials Secret

1. Click **"Store a new secret"** again
2. Select **"Other type of secret"**
3. Click **"Plaintext"** tab
4. Paste this (update with your actual RDS info):

```json
{
  "host": "your-rds-instance.us-east-1.rds.amazonaws.com",
  "port": 5432,
  "username": "postgres",
  "password": "your-password-here",
  "database": "ingest_db"
}
```

5. Click **"Next"**
6. Secret name: `rds-credentials`
7. Description: `RDS PostgreSQL credentials`
8. Click **"Next"** → **"Next"** → **"Store"**

**Verification:** You should see 2 secrets listed:
- `stock-api-keys`
- `rds-credentials`

---

## 🗂️ Part 4: Create EFS File System (20 minutes)

EFS is shared storage where your SQLite database will live.

### Step 4.1: Navigate to EFS

1. Search for: `EFS`
2. Click **"Elastic File System"**

### Step 4.2: Create File System

1. Click **"Create file system"** button
2. Click **"Customize"** (not the quick create)

**Page 1 - File system settings:**
- **Name:** `StockDataEFS`
- **Storage class:** Standard (default)
- **Automatic backups:** Enable (recommended)
- **Lifecycle management:** None
- **Performance mode:** General Purpose
- **Throughput mode:** Bursting
- **Encryption:** Enable encryption at rest (checked)

Click **"Next"**

**Page 2 - Network access:**
- **Virtual Private Cloud (VPC):** Select your default VPC
- **Mount targets:** Keep all availability zones checked
- **Security groups:** Keep default

**IMPORTANT:** Note down the VPC ID (looks like `vpc-0abc123def456`)

Click **"Next"**

**Page 3 - Optional settings:**
- Leave everything as default

Click **"Next"** → **"Create"**

**Wait 2-3 minutes** for the file system to become "Available"

### Step 4.3: Create Access Point

1. Click on your newly created file system name
2. Click **"Access points"** tab
3. Click **"Create access point"** button
4. Fill in:
   - **Name:** `stock-data-access-point`
   - **Root directory path:** `/mnt/efs`
   - **POSIX user:**
     - User ID: `1000`
     - Group ID: `1000`
   - **Root directory creation permissions:**
     - Owner user ID: `1000`
     - Owner group ID: `1000`
     - Permissions: `755`
5. Click **"Create access point"**

**Copy this ARN!** You'll see something like:
```
arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-0123456789abcdef
```
Save this - you'll need it for Lambda.

---

## 📤 Part 5: Upload Files to EFS (30 minutes)

We need to upload your Python scripts to EFS. We'll use an EC2 instance temporarily.

### Step 5.1: Launch EC2 Instance

1. Search for: `EC2`
2. Click **"EC2"**
3. Click **"Launch instance"** button

**Configure:**
- **Name:** `EFS-Upload-Helper` (temporary instance)
- **Application and OS Images:** Amazon Linux 2023 (default)
- **Instance type:** t2.micro (Free tier eligible)
- **Key pair:**
  - Click **"Create new key pair"**
  - Name: `efs-helper-key`
  - Type: RSA
  - Format: .pem
  - Click **"Create key pair"** (file downloads automatically)
  - **Save this file!** Move it to a safe location
- **Network settings:**
  - VPC: Same VPC as your EFS
  - Auto-assign public IP: Enable
  - Firewall: Create new security group
    - Security group name: `efs-helper-sg`
    - Allow SSH from: My IP (default)
- **Storage:** 8 GB (default)

Click **"Launch instance"**

Wait 2 minutes for it to be "Running"

### Step 5.2: Connect to EC2 and Mount EFS

**Option A: Using EC2 Instance Connect (easiest - no terminal needed)**

1. In EC2 dashboard, select your instance
2. Click **"Connect"** button at top
3. Click **"EC2 Instance Connect"** tab
4. Click **"Connect"** button

You'll see a terminal in your browser!

**Option B: Using SSH (for Mac/Linux users)**

```bash
# Make key file secure
chmod 400 ~/Downloads/efs-helper-key.pem

# Connect (replace with your instance's Public IPv4 address)
ssh -i ~/Downloads/efs-helper-key.pem ec2-user@ec2-XX-XX-XX-XX.compute-1.amazonaws.com
```

### Step 5.3: Install NFS Client

In the EC2 terminal, run:

```bash
sudo yum install -y amazon-efs-utils
```

### Step 5.4: Mount EFS

```bash
# Create mount directory
sudo mkdir -p /mnt/efs

# Mount EFS (replace fs-XXXXX with your EFS file system ID)
# Find your file system ID in EFS console - looks like: fs-0a1b2c3d4e5f6g7h8
sudo mount -t efs -o tls fs-XXXXXXXXX:/ /mnt/efs

# Verify mount
df -h /mnt/efs
```

**You should see:** Something like `/mnt/efs` mounted

### Step 5.5: Upload Your Files

**On your local Mac**, open Terminal and run:

```bash
# Compress your project files
cd /Users/samriddha/Downloads/ingestion
tar -czf ingestion.tar.gz \
  config.py \
  utils.py \
  fetch_loaders/ \
  01_portfolio/ \
  02_prices/ \
  03_forex/ \
  04_news_events/ \
  run_all.py \
  misc/portfolio.db

# Copy to EC2 (replace with your EC2 public IP and key path)
scp -i ~/Downloads/efs-helper-key.pem \
  ingestion.tar.gz \
  ec2-user@ec2-XX-XX-XX-XX.compute-1.amazonaws.com:~/
```

**Back in EC2 terminal:**

```bash
# Extract to EFS
cd /mnt/efs
sudo tar -xzf ~/ingestion.tar.gz
sudo chmod -R 755 /mnt/efs/

# Verify files
ls -la /mnt/efs/
```

**You should see:** All your Python files and directories

### Step 5.6: Terminate EC2 Instance

**Important:** Don't forget this step to avoid charges!

1. Go back to EC2 dashboard
2. Select your `EFS-Upload-Helper` instance
3. Click **"Instance state"** → **"Terminate instance"**
4. Click **"Terminate"**

---

## 🔧 Part 6: Create IAM Roles (20 minutes)

Lambda functions need permission to access EFS, Secrets Manager, and RDS.

### Step 6.1: Navigate to IAM

1. Search for: `IAM`
2. Click **"IAM"**
3. Click **"Roles"** in left sidebar

### Step 6.2: Create Lambda Execution Role

1. Click **"Create role"** button
2. **Trusted entity type:** AWS service
3. **Use case:** Lambda
4. Click **"Next"**
5. **Add permissions:** Search and select these policies (use the search box):
   - `AWSLambdaVPCAccessExecutionRole`
   - Click **"Next"**
6. **Role name:** `LambdaStockDataExecutionRole`
7. Click **"Create role"**

### Step 6.3: Attach Additional Permissions

1. Click on the role you just created: `LambdaStockDataExecutionRole`
2. Click **"Add permissions"** → **"Create inline policy"**
3. Click **"JSON"** tab
4. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
        "elasticfilesystem:ClientRead",
        "elasticfilesystem:DescribeMountTargets"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:stock-api-keys-*",
        "arn:aws:secretsmanager:*:*:secret:rds-credentials-*"
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

5. Click **"Review policy"**
6. **Name:** `StockDataCustomPolicy`
7. Click **"Create policy"**

### Step 6.4: Create Step Functions Execution Role

1. Go back to IAM → Roles
2. Click **"Create role"**
3. **Trusted entity type:** AWS service
4. **Use case:** Step Functions (scroll down to find it)
5. Click **"Next"**
6. Click **"Next"** (no policies needed yet)
7. **Role name:** `StepFunctionsStockPipelineRole`
8. Click **"Create role"**

9. Click on the role: `StepFunctionsStockPipelineRole`
10. **Add permissions** → **"Create inline policy"**
11. Paste this:

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
        "arn:aws:lambda:*:*:function:FetchSingleStockData",
        "arn:aws:lambda:*:*:function:AggregateStockResults",
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

12. **Name:** `StepFunctionsInvokePolicy`
13. Click **"Create policy"**

### Step 6.5: Create EventBridge Role

1. Create role → AWS service → EventBridge
2. **Use case:** EventBridge
3. **Next** → **Next**
4. **Role name:** `EventBridgeStepFunctionsRole`
5. Create role
6. Add inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "states:StartExecution",
      "Resource": "arn:aws:states:*:*:stateMachine:StockDataPipeline"
    }
  ]
}
```

7. **Name:** `EventBridgeStartExecution`
8. Create policy

---

## 🔨 Part 7: Create Lambda Layer (15 minutes)

Lambda layer contains Python dependencies (yfinance, psycopg2, etc.).

### Step 7.1: Prepare Layer ZIP File

**On your Mac**, open Terminal:

```bash
cd /Users/samriddha/Downloads/ingestion/aws_deployment

# Create layer directory
mkdir -p lambda-layer/python

# Install dependencies
pip3 install \
  yfinance \
  psycopg2-binary \
  requests \
  python-dotenv \
  -t lambda-layer/python/ \
  --upgrade

# Create ZIP file
cd lambda-layer
zip -r ../stock-data-layer.zip python/
cd ..

# Verify ZIP was created
ls -lh stock-data-layer.zip
```

**You should see:** A file around 30-50 MB

### Step 7.2: Upload Layer to AWS

1. Search for: `Lambda`
2. Click **"Lambda"**
3. In left sidebar, click **"Layers"**
4. Click **"Create layer"** button
5. Fill in:
   - **Name:** `stock-data-dependencies`
   - **Description:** `Python dependencies for stock data pipeline`
   - **Upload:** Click "Upload a .zip file"
   - Click **"Upload"** and select `stock-data-layer.zip`
   - **Compatible runtimes:** Select `Python 3.11`
6. Click **"Create"**

**Copy the Layer ARN!** Looks like:
```
arn:aws:lambda:us-east-1:123456789012:layer:stock-data-dependencies:1
```

---

## 🚀 Part 8: Create Lambda Functions (40 minutes)

We need to create 3 Lambda functions.

### Step 8.1: Prepare Deployment Packages

**On your Mac Terminal:**

```bash
cd /Users/samriddha/Downloads/ingestion/aws_deployment

# Package Lambda 1
zip lambda_fetch_single_stock.zip lambda_fetch_single_stock.py

# Package Lambda 2
zip lambda_aggregate_results.zip lambda_aggregate_results.py

# Package Lambda 3
zip lambda_ingest_rds.zip lambda_ingest_rds.py

# Verify
ls -lh *.zip
```

### Step 8.2: Create Lambda Function 1: FetchSingleStockData

1. In Lambda console, click **"Create function"**
2. Select **"Author from scratch"**
3. Fill in:
   - **Function name:** `FetchSingleStockData`
   - **Runtime:** Python 3.11
   - **Architecture:** x86_64
   - **Permissions:** Use an existing role → `LambdaStockDataExecutionRole`
4. Click **"Create function"**

**Configure function:**

1. Scroll down to **"Code source"**
2. Click **"Upload from"** → **.zip file**
3. Click **"Upload"** and select `lambda_fetch_single_stock.zip`
4. Click **"Save"**

5. Click **"Configuration"** tab
6. Click **"General configuration"** → **"Edit"**
   - **Memory:** 1024 MB
   - **Timeout:** 5 minutes 0 seconds
   - Click **"Save"**

7. Click **"Environment variables"** → **"Edit"**
   - Add variable:
     - Key: `EFS_MOUNT_PATH`
     - Value: `/mnt/efs`
   - Click **"Add environment variable"**
     - Key: `DB_PATH`
     - Value: `/mnt/efs/portfolio.db`
   - Click **"Save"**

8. Click **"VPC"** → **"Edit"**
   - **VPC:** Select the same VPC as your EFS
   - **Subnets:** Select 2+ subnets
   - **Security groups:** Select default security group
   - Click **"Save"**

9. Scroll down to **"Layers"** → **"Add a layer"**
   - Select **"Custom layers"**
   - Choose: `stock-data-dependencies`
   - Version: 1
   - Click **"Add"**

10. Click **"File system"** → **"Add file system"**
    - **EFS file system:** Select `StockDataEFS`
    - **Access point:** Select `stock-data-access-point`
    - **Local mount path:** `/mnt/efs`
    - Click **"Save"**

### Step 8.3: Create Lambda Function 2: AggregateStockResults

Repeat the same steps but with these differences:
- **Function name:** `AggregateStockResults`
- **ZIP file:** `lambda_aggregate_results.zip`
- **Memory:** 512 MB
- **Timeout:** 1 minute 0 seconds
- **No EFS needed** (don't add file system)
- **No environment variables needed**
- **Still add the layer:** `stock-data-dependencies`

### Step 8.4: Create Lambda Function 3: IngestToRDS

Repeat with these settings:
- **Function name:** `IngestToRDS`
- **ZIP file:** `lambda_ingest_rds.zip`
- **Memory:** 2048 MB
- **Timeout:** 15 minutes 0 seconds
- **Environment variables:**
  - `EFS_MOUNT_PATH`: `/mnt/efs`
  - `DB_PATH`: `/mnt/efs/portfolio.db`
  - `RDS_SECRET_NAME`: `rds-credentials`
- **Add EFS** (same as Function 1)
- **Add layer:** `stock-data-dependencies`
- **VPC:** Same as EFS

---

## 🔄 Part 9: Create Step Functions State Machine (15 minutes)

### Step 9.1: Update State Machine Definition

**On your Mac:**

1. Open: `/Users/samriddha/Downloads/ingestion/aws_deployment/step-functions-parallel.json`
2. Find and replace:
   - Replace `${AWS_REGION}` with your region (e.g., `us-east-1`)
   - Replace `${AWS_ACCOUNT_ID}` with your AWS account ID

**To find your account ID:**
- In AWS Console, click your name at top right
- Account ID is shown (12-digit number)

**Save the file after editing**

### Step 9.2: Create State Machine

1. Search for: `Step Functions`
2. Click **"Step Functions"**
3. Click **"Create state machine"**
4. Select **"Write your workflow in code"**
5. **Type:** Standard
6. **Definition:**
   - Open your edited `step-functions-parallel.json`
   - Copy ALL the content
   - Paste into the Definition box
7. Click **"Next"**
8. **Name:** `StockDataPipeline`
9. **Permissions:** Choose an existing role → `StepFunctionsStockPipelineRole`
10. Click **"Create state machine"**

**You should see:** A visual workflow diagram!

**Copy the ARN!** Looks like:
```
arn:aws:states:us-east-1:123456789012:stateMachine:StockDataPipeline
```

---

## ⏰ Part 10: Create EventBridge Schedule (10 minutes)

### Step 10.1: Create Rule

1. Search for: `EventBridge`
2. Click **"Amazon EventBridge"**
3. In left sidebar, click **"Rules"**
4. Click **"Create rule"** button
5. Fill in:
   - **Name:** `DailyStockDataFetch`
   - **Description:** `Trigger stock data pipeline daily at 9:00 AM UTC`
   - **Event bus:** default
   - **Rule type:** Schedule
6. Click **"Next"**

### Step 10.2: Configure Schedule

1. **Schedule pattern:** Cron-based schedule
2. **Cron expression:** `0 9 * * ? *`
   - This means: Every day at 9:00 AM UTC
3. Click **"Next"**

### Step 10.3: Select Target

1. **Target types:** AWS service
2. **Select a target:** Step Functions state machine
3. **State machine:** `StockDataPipeline`
4. **Execution role:** Use existing role → `EventBridgeStepFunctionsRole`
5. Click **"Next"** → **"Next"** → **"Create rule"**

**Verification:** Rule shows "Enabled" status

---

## ✅ Part 11: Test the Pipeline (20 minutes)

### Step 11.1: Manual Test of Lambda Functions

**Test Lambda 1:**

1. Go to Lambda → Functions → `FetchSingleStockData`
2. Click **"Test"** tab
3. **Event name:** `test-event`
4. **Event JSON:**
```json
{
  "ticker": "0853.HK",
  "name": "MICROPORT"
}
```
5. Click **"Save"**
6. Click **"Test"**

**Wait 30-60 seconds**

**Expected result:** Green box with "Execution result: succeeded"

**Test Lambda 2:**

1. Go to `AggregateStockResults`
2. Test with this event:
```json
{
  "stockResults": [
    {
      "fetchResult": {
        "status": "SUCCESS",
        "ticker": "0853.HK",
        "name": "MICROPORT",
        "stocks_count": 1,
        "prices_count": 2463
      }
    }
  ]
}
```

### Step 11.2: Test Step Functions

1. Go to Step Functions → State machines → `StockDataPipeline`
2. Click **"Start execution"**
3. **Name:** `test-run-1`
4. **Input:** (leave as `{}`)
5. Click **"Start execution"**

**Watch the execution:**
- You'll see each step light up as it executes
- Green = success
- Red = failure

**This will take 5-10 minutes** to process all 9 stocks

### Step 11.3: Check Results

**Check SNS Email:**
- You should receive an email with subject: "Stock Data Pipeline - SUCCESS"

**Check CloudWatch Logs:**
1. Search for: `CloudWatch`
2. Click **"Logs"** → **"Log groups"**
3. Click: `/aws/lambda/FetchSingleStockData`
4. Click the latest log stream
5. You should see logs from each stock being processed

**Check EFS Database:**
- Your SQLite database at `/mnt/efs/portfolio.db` should now have data!

---

## 🐛 Troubleshooting

### Problem: Lambda times out

**Solution:**
- Increase timeout in Lambda Configuration → General configuration
- Check VPC/Security group allows outbound internet access

### Problem: Can't connect to RDS

**Solution:**
- Check RDS security group allows inbound from Lambda security group (port 5432)
- Verify RDS credentials in Secrets Manager are correct

### Problem: EFS mount fails

**Solution:**
- Check Lambda and EFS are in same VPC
- Verify security group allows NFS (port 2049)

### Problem: "Permission denied" errors

**Solution:**
- Check IAM role has all required permissions
- Verify role is attached to Lambda function

### Problem: No email received

**Solution:**
- Check SNS subscription is "Confirmed"
- Check spam folder
- Verify SNS topic ARN is correct in Step Functions definition

---

## 📊 Monitoring

### View Execution History

1. Go to Step Functions → `StockDataPipeline`
2. Click **"Executions"** tab
3. See all past runs with status

### View Lambda Logs

1. CloudWatch → Log groups
2. Search for your function name
3. Click latest log stream

### View Metrics

1. CloudWatch → Dashboards
2. Create custom dashboard
3. Add widgets for:
   - Lambda invocations
   - Lambda errors
   - Step Functions executions

---

## 💰 Cost Monitoring

### Set Up Billing Alerts

1. Search for: `Billing`
2. Click **"Budgets"**
3. Click **"Create budget"**
4. **Budget type:** Cost budget
5. **Budget amount:** $10/month
6. **Alert threshold:** 80% ($8)
7. **Email:** your-email@example.com
8. Create budget

Now you'll get an email if costs exceed $8/month!

---

## 🎉 Success Checklist

After deployment, verify:

- [ ] SNS topic created and email confirmed
- [ ] 2 secrets stored in Secrets Manager
- [ ] EFS file system created with access point
- [ ] Project files uploaded to EFS
- [ ] 3 IAM roles created
- [ ] Lambda layer created and deployed
- [ ] 3 Lambda functions created and configured
- [ ] Step Functions state machine created
- [ ] EventBridge rule created and enabled
- [ ] Manual test execution succeeded
- [ ] Received test email notification
- [ ] Data appears in SQLite database
- [ ] Data appears in RDS PostgreSQL

---

## 📅 What Happens Next?

**Automatic Daily Execution:**
- Every day at 9:00 AM UTC, EventBridge triggers the pipeline
- Step Functions processes all 9 stocks in parallel
- Data is fetched from Yahoo Finance and FMP
- SQLite database is updated on EFS
- Data is ingested into your RDS database
- You receive an email notification with results

**You don't need to do anything!** It runs automatically.

---

## 🔄 How to Update

### Update Python Code

1. Launch EC2 instance (same as Part 5)
2. Mount EFS
3. Upload new files
4. Terminate EC2

### Update Lambda Code

1. Go to Lambda function
2. Upload new .zip file
3. Click Save

### Change Schedule

1. Go to EventBridge → Rules → `DailyStockDataFetch`
2. Edit cron expression
3. Save

---

## ❓ Need Help?

**Common Issues:**
- VPC/Security group problems → Check Part 4-8 configurations
- Permission errors → Check IAM roles in Part 6
- Lambda timeouts → Increase timeout in Lambda settings

**Check logs:**
1. CloudWatch Logs shows detailed error messages
2. Step Functions execution history shows which step failed

---

## 📚 Next Steps

1. **Monitor first few runs** to ensure everything works
2. **Set up CloudWatch dashboards** for better visibility
3. **Create additional alerts** for failures
4. **Document your AWS account IDs** and ARNs for future reference

---

**Congratulations!** 🎉 You've deployed a production-grade automated data pipeline on AWS!

**Time to complete:** 2-3 hours
**Monthly cost:** ~$6.65
**Maintenance required:** Minimal - just monitor email notifications
