# Quick Command Reference

Copy-paste these commands during deployment. Update values in CAPS.

---

## 📦 Part 5: Upload Files to EFS

### On Your Mac (Local Terminal)

```bash
# Navigate to project directory
cd /Users/samriddha/Downloads/ingestion

# Create compressed archive
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

# Upload to EC2 (replace values)
scp -i ~/Downloads/efs-helper-key.pem \
  ingestion.tar.gz \
  ec2-user@YOUR-EC2-PUBLIC-IP:~/
```

### On EC2 Instance (Browser Terminal or SSH)

```bash
# Install EFS utilities
sudo yum install -y amazon-efs-utils

# Create mount directory
sudo mkdir -p /mnt/efs

# Mount EFS (replace YOUR-EFS-ID)
sudo mount -t efs -o tls fs-YOUR-EFS-ID:/ /mnt/efs

# Verify mount
df -h /mnt/efs

# Extract files to EFS
cd /mnt/efs
sudo tar -xzf ~/ingestion.tar.gz

# Set permissions
sudo chmod -R 755 /mnt/efs/

# Verify files
ls -la /mnt/efs/
```

---

## 🔧 Part 7: Create Lambda Layer

### On Your Mac

```bash
# Navigate to deployment directory
cd /Users/samriddha/Downloads/ingestion/aws_deployment

# Create layer directory
mkdir -p lambda-layer/python

# Install Python dependencies
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

# Verify ZIP
ls -lh stock-data-layer.zip
```

---

## 🚀 Part 8: Package Lambda Functions

### On Your Mac

```bash
cd /Users/samriddha/Downloads/ingestion/aws_deployment

# Package all Lambda functions
zip lambda_fetch_single_stock.zip lambda_fetch_single_stock.py
zip lambda_aggregate_results.zip lambda_aggregate_results.py
zip lambda_ingest_rds.zip lambda_ingest_rds.py

# Verify all ZIPs created
ls -lh *.zip
```

---

## 🔍 Part 11: Test Commands

### Test Lambda Function (AWS CLI)

```bash
# Test FetchSingleStockData
aws lambda invoke \
  --function-name FetchSingleStockData \
  --payload '{"ticker":"0853.HK","name":"MICROPORT"}' \
  response.json \
  --region us-east-1

# View response
cat response.json | python3 -m json.tool
```

### Start Step Functions Execution

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:YOUR-ACCOUNT-ID:stateMachine:StockDataPipeline \
  --name manual-test-$(date +%s) \
  --region us-east-1
```

---

## 📊 Monitoring Commands

### View CloudWatch Logs

```bash
# List log streams for a function
aws logs describe-log-streams \
  --log-group-name /aws/lambda/FetchSingleStockData \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --region us-east-1

# Tail logs (follow mode)
aws logs tail /aws/lambda/FetchSingleStockData --follow --region us-east-1
```

### Check Step Functions Execution

```bash
# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:us-east-1:YOUR-ACCOUNT-ID:stateMachine:StockDataPipeline \
  --max-results 5 \
  --region us-east-1

# Get execution details (replace EXECUTION-ARN)
aws stepfunctions describe-execution \
  --execution-arn YOUR-EXECUTION-ARN \
  --region us-east-1
```

---

## 🗄️ Database Commands

### Check SQLite Database (on EC2 with EFS mounted)

```bash
# Connect to database
sqlite3 /mnt/efs/portfolio.db

# Show tables
.tables

# Count stocks
SELECT COUNT(*) FROM stocks;

# Count prices
SELECT COUNT(*) FROM stocks_price_data;

# Show recent prices
SELECT
  s.ticker,
  s.company_name,
  COUNT(p.market_data_id) as price_count,
  MAX(p.captured_at) as latest_date
FROM stocks s
LEFT JOIN stocks_price_data p ON s.stock_id = p.stock_id
GROUP BY s.stock_id
ORDER BY price_count DESC;

# Exit
.quit
```

### Check RDS PostgreSQL

```bash
# Connect to RDS (replace with your endpoint and password)
psql -h your-rds-endpoint.us-east-1.rds.amazonaws.com \
     -U postgres \
     -d ingest_db

# Once connected:
\dt                                    # List tables
SELECT COUNT(*) FROM stocks;           # Count stocks
SELECT COUNT(*) FROM stocks_price_data;  # Count prices
\q                                     # Quit
```

---

## 🔄 Update Commands

### Update Lambda Function Code

```bash
# Create new ZIP
zip lambda_fetch_single_stock.zip lambda_fetch_single_stock.py

# Upload to Lambda
aws lambda update-function-code \
  --function-name FetchSingleStockData \
  --zip-file fileb://lambda_fetch_single_stock.zip \
  --region us-east-1
```

### Update Step Functions State Machine

```bash
# After editing step-functions-parallel.json
aws stepfunctions update-state-machine \
  --state-machine-arn arn:aws:states:us-east-1:YOUR-ACCOUNT-ID:stateMachine:StockDataPipeline \
  --definition file://step-functions-parallel.json \
  --region us-east-1
```

---

## 🧹 Cleanup Commands (if you want to delete everything)

**⚠️ WARNING: These commands will DELETE resources!**

```bash
# Delete Step Functions state machine
aws stepfunctions delete-state-machine \
  --state-machine-arn arn:aws:states:us-east-1:YOUR-ACCOUNT-ID:stateMachine:StockDataPipeline \
  --region us-east-1

# Delete Lambda functions
aws lambda delete-function --function-name FetchSingleStockData --region us-east-1
aws lambda delete-function --function-name AggregateStockResults --region us-east-1
aws lambda delete-function --function-name IngestToRDS --region us-east-1

# Delete Lambda layer
aws lambda delete-layer-version \
  --layer-name stock-data-dependencies \
  --version-number 1 \
  --region us-east-1

# Delete EventBridge rule
aws events remove-targets --rule DailyStockDataFetch --ids "1" --region us-east-1
aws events delete-rule --name DailyStockDataFetch --region us-east-1

# Delete SNS topic
aws sns delete-topic \
  --topic-arn arn:aws:sns:us-east-1:YOUR-ACCOUNT-ID:DataPipelineNotifications \
  --region us-east-1

# Delete secrets
aws secretsmanager delete-secret --secret-id stock-api-keys --region us-east-1
aws secretsmanager delete-secret --secret-id rds-credentials --region us-east-1

# EFS and IAM roles must be deleted from AWS Console
```

---

## 📋 Useful AWS CLI Queries

### Get Your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

### Get Your Current Region

```bash
aws configure get region
```

### List All Lambda Functions

```bash
aws lambda list-functions --query 'Functions[].FunctionName' --region us-east-1
```

### List All Step Functions

```bash
aws stepfunctions list-state-machines --query 'stateMachines[].name' --region us-east-1
```

### Get Lambda Function Configuration

```bash
aws lambda get-function-configuration \
  --function-name FetchSingleStockData \
  --region us-east-1
```

---

## 🔐 AWS CLI Configuration

### Configure AWS CLI (if not already done)

```bash
aws configure
# AWS Access Key ID: YOUR-ACCESS-KEY
# AWS Secret Access Key: YOUR-SECRET-KEY
# Default region name: us-east-1
# Default output format: json
```

### Set Region for Current Session

```bash
export AWS_DEFAULT_REGION=us-east-1
```

---

## 💡 Pro Tips

### JSON Formatting

```bash
# Pretty print JSON output
aws stepfunctions describe-execution \
  --execution-arn YOUR-ARN \
  --region us-east-1 | python3 -m json.tool
```

### Watch Step Functions Execution

```bash
# Get status every 10 seconds
watch -n 10 "aws stepfunctions describe-execution \
  --execution-arn YOUR-EXECUTION-ARN \
  --region us-east-1 | grep -A1 status"
```

### Count CloudWatch Log Events

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/FetchSingleStockData \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --region us-east-1 | jq '.events | length'
```

---

## 📝 Notes

- Replace `YOUR-ACCOUNT-ID`, `YOUR-EFS-ID`, `YOUR-EC2-PUBLIC-IP` with actual values
- All commands assume `us-east-1` region - change if using different region
- AWS CLI must be installed and configured
- Some commands require `jq` for JSON parsing (install with `brew install jq` on Mac)

---

## 🆘 Emergency Stop

### Stop EventBridge Rule (prevent automatic runs)

```bash
aws events disable-rule --name DailyStockDataFetch --region us-east-1
```

### Re-enable Later

```bash
aws events enable-rule --name DailyStockDataFetch --region us-east-1
```
