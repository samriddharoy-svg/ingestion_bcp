# Decision Guide: SQLite+EFS vs Direct RDS

## Your Questions Answered

### Q1: "Will data disappear when container stops?"

**Option A (Current - SQLite + EFS):**
- ❌ **NO** - Data does NOT disappear
- EFS is a **persistent network file system** (like NFS)
- When container writes to `/app/misc/portfolio.db`, it's actually writing to EFS
- EFS survives container restarts
- Next container can read the same SQLite file from EFS

**Option B (Direct RDS):**
- ❌ **NO** - Data does NOT disappear
- Data is written directly to RDS PostgreSQL
- RDS is fully persistent
- No intermediate storage needed

**Answer:** Both options preserve data. The question is which architecture you prefer.

---

### Q2: "What files are required in Docker?"

**Required Files:**
```
/app/
├── config.py                  # ✅ REQUIRED - API keys, RDS config, ticker mappings
├── utils.py                   # ✅ REQUIRED - DB connections, batch insert functions
├── run_fetch_all.py           # ✅ REQUIRED - Master orchestrator
├── fetch_loaders/             # ✅ REQUIRED - All fetch scripts
│   ├── fetch_stocks.py
│   ├── fetch_price_data.py
│   ├── fetch_live_prices.py
│   ├── fetch_benchmarks.py
│   ├── fetch_mappings.py
│   ├── fetch_fundamentals.py
│   ├── fetch_earnings.py
│   ├── fetch_news.py
│   └── fetch_forex.py
```

**NOT Required:**
- ❌ `.env` - Use AWS Secrets Manager instead
- ❌ SQLite database file - Created at runtime (Option A) or not needed (Option B)
- ❌ Ingestion scripts (`01_portfolio/`, `02_prices/`, etc.) - Only if using Option A

**Current Dockerfile already handles this:**
```dockerfile
COPY . /app/   # Copies all necessary files
```

---

## Architecture Comparison

### Option A: SQLite + EFS (Current Implementation)

```
┌─────────────────────────────────────────────────┐
│  Phase 1: Fetch Container                       │
│  ├─ Mounts EFS at /app/misc                     │
│  ├─ Fetches from APIs                           │
│  ├─ Writes to SQLite on EFS                     │
│  └─ Container dies → Data on EFS ✅             │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  Phase 2: Ingest Container                      │
│  ├─ Mounts same EFS                             │
│  ├─ Reads SQLite from EFS                       │
│  ├─ Writes to RDS PostgreSQL                    │
│  └─ Container dies → Data in RDS ✅             │
└─────────────────────────────────────────────────┘
```

**Infrastructure:**
- ECS Cluster
- 2 Task Definitions (Fetch + Ingest)
- EFS File System
- Step Functions (2 phases)
- EventBridge

**Pros:**
- ✅ No code changes needed
- ✅ Matches current architecture
- ✅ Can test fetch independently
- ✅ Intermediate storage for debugging

**Cons:**
- ❌ Need to set up EFS
- ❌ 2 containers run (longer execution)
- ❌ Slightly more complex

**Cost:** ~$11/month (hourly execution)

---

### Option B: Direct RDS Write

```
┌─────────────────────────────────────────────────┐
│  Fetch Container                                 │
│  ├─ Fetches from APIs                           │
│  ├─ Writes DIRECTLY to RDS PostgreSQL           │
│  └─ Container dies → Data in RDS ✅             │
└─────────────────────────────────────────────────┘
```

**Infrastructure:**
- ECS Cluster
- 1 Task Definition (Fetch only)
- NO EFS needed
- Step Functions (1 phase)
- EventBridge

**Pros:**
- ✅ Simpler infrastructure (no EFS)
- ✅ 32% cheaper ($7.50 vs $11/month)
- ✅ Faster execution (single container)
- ✅ Direct write to production database

**Cons:**
- ❌ Requires modifying 9 fetch scripts
- ❌ Local testing requires PostgreSQL
- ❌ Can't separate fetch/ingest phases

**Cost:** ~$7.50/month (hourly execution)

---

## Decision Matrix

| Criteria | Option A (SQLite+EFS) | Option B (Direct RDS) |
|----------|----------------------|---------------------|
| **Code Changes** | None ✅ | Modify 9 files ❌ |
| **Infrastructure Complexity** | Higher (EFS setup) ❌ | Lower (no EFS) ✅ |
| **Cost** | $11/month ❌ | $7.50/month ✅ |
| **Execution Time** | Longer (2 containers) ❌ | Faster (1 container) ✅ |
| **Local Testing** | SQLite (simple) ✅ | Needs Postgres ❌ |
| **Debugging** | Can inspect SQLite ✅ | Direct to RDS ❌ |
| **Separation of Concerns** | Fetch/Ingest separate ✅ | Combined ❌ |

---

## My Recommendation

### For Your Use Case (9 stocks, hourly/daily):

**Choose Option B (Direct RDS)** ✅

**Reasons:**
1. **Simpler infrastructure** - No EFS to manage
2. **32% cost savings** - $3.50/month saved
3. **Faster execution** - Single container run
4. **You're already using Docker** - PostgreSQL testing is easy with Docker Compose
5. **One-time code change** - Modify 9 files once, deploy forever

**Implementation effort:**
- ~2 hours to modify fetch scripts
- Test locally with Docker Compose + Postgres
- Deploy simplified task definition

---

## Implementation Path

### If Choosing Option A (Keep Current)

```bash
# 1. Create EFS file system
aws efs create-file-system --encrypted

# 2. Create EFS mount targets in VPC subnets
aws efs create-mount-target \
  --file-system-id fs-XXXXX \
  --subnet-id subnet-XXXXX \
  --security-groups sg-XXXXX

# 3. Deploy as-is (no code changes)
cd aws_fargate
./deploy-all.sh
```

**Total time:** ~30 minutes (infrastructure setup only)

---

### If Choosing Option B (Direct RDS)

```bash
# 1. Modify files (I can generate these for you)
- config.py (add RDS from env vars)
- utils.py (add rds_batch_insert function)
- All 9 fetch scripts (replace sqlite_batch_insert)

# 2. Test locally
docker-compose -f docker-compose-rds.yml up

# 3. Deploy simplified infrastructure
cd aws_fargate
./deploy-all-direct-rds.sh
```

**Total time:** ~2 hours (code changes + testing + deploy)

---

## Next Steps

### Option 1: Keep Current Architecture (SQLite + EFS)

**Action:** Deploy as-is

```bash
cd /Users/samriddha/Downloads/ingestion/aws_fargate
./deploy-all.sh
```

**What you need to provide:**
- EFS File System ID
- EFS Access Point ID
- VPC Subnet IDs
- Security Group ID

---

### Option 2: Switch to Direct RDS

**Action:** I'll generate modified files for you

**What I'll create:**
1. Modified `config.py` (read RDS from env)
2. Modified `utils.py` (add `rds_batch_insert()`)
3. Modified all 9 fetch scripts
4. Updated `docker-compose.yml` (with Postgres)
5. Updated ECS task definition (no EFS)
6. Updated Step Functions (single phase)
7. Deployment script

**What you need to provide:**
- RDS endpoint
- RDS credentials
- VPC Subnet IDs
- Security Group ID

---

## Final Recommendation

**Go with Option B (Direct RDS)** unless you have a specific reason to keep SQLite intermediate storage.

**Benefits you'll get:**
- ✅ Simpler deployment
- ✅ Lower monthly cost
- ✅ Faster execution
- ✅ One less thing to manage (no EFS)

**Would you like me to generate all the modified files for Option B?**

Just say:
- **"Generate Option B files"** - I'll modify all files for direct RDS write
- **"Keep Option A"** - Deploy as-is with SQLite + EFS

---

**Your call!** 🚀
