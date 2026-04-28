# My AWS Configuration Details

**Fill this out BEFORE starting deployment!**
**Keep this file safe - it contains sensitive information**

---

## 🔐 RDS PostgreSQL Database Details

**Where to find:** Your AWS RDS Console → Databases → Click your database

| Setting | Your Value | Example |
|---------|------------|---------|
| **RDS Endpoint** | _________________________________ | `mydb.c1a2b3c4d5e6.us-east-1.rds.amazonaws.com` |
| **Port** | `5432` (default) | `5432` |
| **Database Name** | _________________________________ | `ingest_db` |
| **Master Username** | _________________________________ | `postgres` |
| **Master Password** | _________________________________ | (your secure password) |

**Important:**
- Don't include `http://` or port number in endpoint
- Just copy the endpoint URL from RDS console
- Example: `stock-db.c9a8b7c6d5e4.us-east-1.rds.amazonaws.com`

---

## 🔑 API Keys

### FMP (Financial Modeling Prep) API Key

| Setting | Your Value |
|---------|------------|
| **FMP API Key** | `iyeAw4PFbtHWXtRCJ8mv6fAJ11RmNPoO` |

**Where to find:** https://financialmodelingprep.com/developer/docs → Your API Key

**Current tier:** Free tier (only `stable/*` endpoints available)

### Tiingo API Key (Optional - not working for international stocks)

| Setting | Your Value |
|---------|------------|
| **Tiingo API Key** | `37ee80c8063abdd83d1bd91311ac3a36cf86e658` |

**Where to find:** https://www.tiingo.com/account/api

**Note:** Tiingo doesn't support international stocks, so this is optional.

---

## 📧 Notification Settings

| Setting | Your Value | Example |
|---------|------------|---------|
| **Your Email** | _________________________________ | `yourname@company.com` |

**This email will receive:**
- Daily pipeline success/failure notifications
- AWS billing alerts
- SNS subscription confirmation (must confirm!)

---

## 🌍 AWS Account Information

**Where to find:** AWS Console → Click your name (top right)

| Setting | Your Value | Example |
|---------|------------|---------|
| **AWS Account ID** | _________________________________ | `123456789012` (12 digits) |
| **AWS Region** | `us-east-1` (recommended) | `us-east-1` |
| **VPC ID** | _________________________________ | `vpc-0a1b2c3d4e5f6g7h8` |

**Finding VPC ID:**
1. Go to AWS Console → VPC
2. Click "Your VPCs" in left sidebar
3. Copy the VPC ID (usually the default VPC)
4. Example: `vpc-0abc123def456`

---

## 📋 Secrets Manager Configuration

**You'll create these during deployment - this is what you'll paste:**

### Secret 1: stock-api-keys

```json
{
  "FMP_API_KEY": "iyeAw4PFbtHWXtRCJ8mv6fAJ11RmNPoO",
  "TIINGO_API_KEY": "37ee80c8063abdd83d1bd91311ac3a36cf86e658"
}
```

**Action needed:** Update the values above with your actual keys, then copy-paste during Step 3.2

### Secret 2: rds-credentials

```json
{
  "host": "YOUR-RDS-ENDPOINT-HERE.us-east-1.rds.amazonaws.com",
  "port": 5432,
  "username": "postgres",
  "password": "YOUR-PASSWORD-HERE",
  "database": "ingest_db"
}
```

**Action needed:**
1. Replace `YOUR-RDS-ENDPOINT-HERE` with your actual RDS endpoint (from top of this file)
2. Replace `YOUR-PASSWORD-HERE` with your actual RDS password
3. Update `username` if different
4. Update `database` if different
5. Copy-paste during Step 3.3

---

## 🔗 Important ARNs (Fill in during deployment)

**Copy these as you create resources - you'll need them later!**

| Resource | ARN | Created in Part |
|----------|-----|----------------|
| **SNS Topic** | _____________________________________________ | Part 2 |
| **EFS File System** | _____________________________________________ | Part 4 |
| **EFS Access Point** | _____________________________________________ | Part 4 |
| **Lambda Layer** | _____________________________________________ | Part 7 |
| **Lambda: FetchSingleStockData** | _____________________________________________ | Part 8 |
| **Lambda: AggregateStockResults** | _____________________________________________ | Part 8 |
| **Lambda: IngestToRDS** | _____________________________________________ | Part 8 |
| **Step Functions State Machine** | _____________________________________________ | Part 9 |

---

## 📝 Pre-Deployment Verification

Before starting deployment, check:

- [ ] RDS database is **running** (status: Available)
- [ ] RDS is accessible from **within VPC** (not public)
- [ ] You can connect to RDS using the credentials above
- [ ] FMP API key is **valid** (test at https://financialmodelingprep.com/stable/quote-short?symbol=0853.HK&apikey=YOUR_KEY)
- [ ] Your email is **active** and you can receive emails
- [ ] You have **admin access** to AWS account
- [ ] You have **2-3 hours** of free time

---

## 🧪 Test Your Credentials

### Test RDS Connection (from your Mac)

```bash
# Install psql if not already installed (Mac)
brew install postgresql

# Test connection (replace with your values)
psql -h YOUR-RDS-ENDPOINT \
     -U postgres \
     -d ingest_db \
     -c "SELECT version();"

# Enter password when prompted
# You should see PostgreSQL version info
```

### Test FMP API Key

```bash
# Test with curl (replace YOUR-KEY)
curl "https://financialmodelingprep.com/stable/quote-short?symbol=0853.HK&apikey=iyeAw4PFbtHWXtRCJ8mv6fAJ11RmNPoO"

# You should see JSON data with stock price
# If you see 403 error, your key is invalid
```

### Test AWS CLI

```bash
# Check if AWS CLI is configured
aws sts get-caller-identity

# You should see:
# - Account ID
# - User ARN
# - UserId

# If error, run: aws configure
```

---

## 🔒 Security Reminders

- ⚠️ **NEVER commit this file to git**
- ⚠️ **NEVER share your API keys publicly**
- ⚠️ **NEVER share your RDS password**
- ⚠️ Keep this file in a secure location
- ⚠️ Add to .gitignore if in git repository

---

## 📅 Deployment Tracking

| Milestone | Date Completed | Notes |
|-----------|---------------|-------|
| Configuration filled out | _____________ | |
| RDS tested successfully | _____________ | |
| API keys tested | _____________ | |
| AWS deployment started | _____________ | |
| SNS Topic created | _____________ | |
| Secrets stored | _____________ | |
| EFS created | _____________ | |
| Files uploaded to EFS | _____________ | |
| IAM Roles created | _____________ | |
| Lambda Functions created | _____________ | |
| Step Functions created | _____________ | |
| EventBridge scheduled | _____________ | |
| First test successful | _____________ | |
| **Deployment complete** | _____________ | ✅ |

---

## 🎯 Next Steps

Once you've filled this out:

1. ✅ Save this file securely
2. ✅ Test your RDS connection (see above)
3. ✅ Test your FMP API key (see above)
4. ✅ Open **[START_HERE.md](START_HERE.md)**
5. ✅ Begin deployment following **[BEGINNER_DEPLOYMENT_GUIDE.md](BEGINNER_DEPLOYMENT_GUIDE.md)**

---

## 📞 Quick Reference During Deployment

When the guide asks for:

| What | Where to find it |
|------|-----------------|
| **RDS Endpoint** | Top of this file → RDS PostgreSQL Database Details |
| **RDS Password** | Top of this file → RDS PostgreSQL Database Details |
| **FMP API Key** | Top of this file → API Keys section |
| **Your Email** | Top of this file → Notification Settings |
| **Secret JSON** | Middle of this file → Secrets Manager Configuration |
| **Account ID** | Top of this file → AWS Account Information |
| **VPC ID** | Top of this file → AWS Account Information |

---

**Filled out by:** _______________________

**Date:** _______________________

**Ready for deployment:** [ ] Yes  [ ] No

---

**🔐 Keep this file safe and secure!**
