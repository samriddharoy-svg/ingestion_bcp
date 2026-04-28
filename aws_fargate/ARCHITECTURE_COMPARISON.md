# Architecture Comparison: Lambda vs Fargate

## Current Implementation (Lambda-based)

### Architecture
```
EventBridge → Step Functions → Lambda (Fetch) → Lambda (Ingest) → SNS
                                    ↓                    ↓
                                  EFS (SQLite)        EFS + RDS
```

### Pros
- ✅ Simple deployment (no Docker required)
- ✅ Lower cost for infrequent execution
- ✅ Automatic scaling
- ✅ No cold start for Python runtime

### Cons
- ❌ **15-minute execution limit** (can timeout for large datasets)
- ❌ **Limited memory** (max 10 GB)
- ❌ **Limited CPU** (proportional to memory)
- ❌ **Lambda layer size limits** (250 MB unzipped)
- ❌ **Difficult to debug** (can't SSH into Lambda)
- ❌ **VPC cold starts** (when using EFS)
- ❌ **Package deployment complexity** (layers, zips)

### When to Use
- Short-running tasks (<10 minutes)
- Small datasets (<10,000 records)
- Simple dependencies
- Event-driven workloads

---

## New Implementation (Fargate-based)

### Architecture
```
EventBridge → Step Functions → ECS Fargate (Fetch) → ECS Fargate (Ingest) → SNS
                                       ↓                       ↓
                                  EFS (SQLite)            EFS + RDS
```

### Pros
- ✅ **No execution time limits** (can run for hours)
- ✅ **More control over resources** (up to 4 vCPU, 30 GB RAM)
- ✅ **Standard Docker containers** (test locally, deploy anywhere)
- ✅ **Easier debugging** (can exec into running containers)
- ✅ **No package size limits**
- ✅ **Consistent environment** (local = production)
- ✅ **Better for complex dependencies** (compile native libraries)
- ✅ **No VPC cold starts**

### Cons
- ❌ Slightly higher cost for very short tasks
- ❌ Requires Docker knowledge
- ❌ Longer startup time (~30 seconds vs ~5 seconds)
- ❌ More complex infrastructure

### When to Use
- **Long-running tasks** (>10 minutes)
- **Large datasets** (100,000+ records)
- **Complex dependencies** (compiled libraries, native code)
- **Web scraping** (multiple API calls, rate limiting)
- **Need for debugging** (can exec into container)

---

## Side-by-Side Comparison

| Feature | Lambda | Fargate |
|---------|--------|---------|
| **Max Execution Time** | 15 minutes | Unlimited |
| **Max Memory** | 10 GB | 30 GB |
| **Max vCPU** | 6 vCPU | 4 vCPU |
| **Cold Start** | ~1-5 seconds | ~30 seconds |
| **Package Size Limit** | 250 MB (unzipped) | None (Docker image) |
| **Cost (hourly exec)** | ~$6/month | ~$17/month |
| **Cost (daily exec)** | ~$2/month | ~$3/month |
| **Debugging** | CloudWatch Logs only | Logs + exec into container |
| **Local Testing** | SAM CLI, Docker | Native Docker |
| **Deployment** | ZIP/Layer upload | ECR push |
| **VPC Networking** | Cold starts | No cold starts |
| **Scalability** | 1000 concurrent | Task count based |

---

## Cost Analysis

### Scenario 1: Hourly Execution (24x/day, 720x/month)

**Assumption:** Each execution takes 10 minutes (Fetch: 7 min, Ingest: 3 min)

**Lambda:**
```
Fetch Lambda: 720 × 7 min × 2 GB × $0.0000166667/GB-second = $1.40
Ingest Lambda: 720 × 3 min × 2 GB × $0.0000166667/GB-second = $0.60
EFS: $0.30
Secrets Manager: $0.80
Other services: $0.50
Total: ~$3.60/month
```

**Fargate:**
```
Fetch Task: 720 × 7 min × 1 vCPU × $0.04048/vCPU-hour = $3.40
Fetch Task: 720 × 7 min × 2 GB × $0.004445/GB-hour = $0.75
Ingest Task: 720 × 3 min × 1 vCPU × $0.04048/vCPU-hour = $1.45
Ingest Task: 720 × 3 min × 2 GB × $0.004445/GB-hour = $0.32
EFS: $0.30
ECR: $0.05
Secrets Manager: $0.80
Other services: $0.50
Total: ~$7.57/month
```

**Winner:** Lambda ($3.60 vs $7.57) - **53% cheaper**

---

### Scenario 2: Daily Execution (1x/day, 30x/month)

**Lambda:**
```
Total: ~$1.50/month
```

**Fargate:**
```
Total: ~$2.50/month
```

**Winner:** Lambda ($1.50 vs $2.50) - **40% cheaper**

---

### Scenario 3: Market Hours Execution (Every 15 min, Mon-Fri 14:00-21:00 UTC)

**Execution count:** ~120/month (5 days × 7 hours × 4 times/hour × 4 weeks)

**Lambda:**
```
Total: ~$2.00/month
```

**Fargate:**
```
Total: ~$3.50/month
```

**Winner:** Lambda ($2.00 vs $3.50) - **43% cheaper**

---

### Scenario 4: Long-running Tasks (Each execution takes 45 minutes)

**Assumption:** Daily execution, 30x/month

**Lambda:**
```
❌ Cannot run (15-minute limit exceeded)
Workaround: Split into 3 Lambda functions = complex orchestration
Cost: ~$4.50/month
```

**Fargate:**
```
Total: ~$8.00/month
✅ No issues, single task handles everything
```

**Winner:** Fargate (Lambda cannot handle this use case)

---

## Decision Matrix

### Choose Lambda if:
- ✅ Execution time < 10 minutes
- ✅ Simple Python dependencies (yfinance, requests, psycopg2)
- ✅ Cost-sensitive (need cheapest option)
- ✅ Event-driven (triggered by SNS, SQS, DynamoDB streams)
- ✅ Team familiar with Lambda

### Choose Fargate if:
- ✅ Execution time > 10 minutes (or might grow over time)
- ✅ Complex dependencies (native libraries, compiled code)
- ✅ Need for local testing parity
- ✅ Web scraping with unpredictable runtime
- ✅ Need to debug issues frequently
- ✅ Team familiar with Docker
- ✅ Want flexibility to migrate to EKS/ECS later

---

## Recommendation for This Project

### Current State (9 stocks, 10 years historical data)
**Recommendation:** **Lambda** ✅

**Reasons:**
- Execution time: ~7 minutes (fetch) + ~3 minutes (ingest) = **10 minutes total**
- Simple dependencies: yfinance, psycopg2, requests
- Cost savings: 40-53% cheaper than Fargate
- Already implemented and working

### Future State (100+ stocks, real-time streaming)
**Recommendation:** **Fargate** ✅

**Reasons:**
- Execution time will exceed 15 minutes
- May need WebSocket connections (persistent)
- Easier to scale horizontally (parallel tasks)
- Better for debugging complex issues

---

## Migration Path

### Phase 1: Keep Lambda (Current)
```
Use Lambda for daily/hourly batch fetching
- Proven to work
- Cost-effective
- Simple deployment
```

### Phase 2: Add Fargate for Long Tasks
```
Use Fargate for:
- Historical backfills (10+ years)
- Large stock universe (1000+ tickers)
- Real-time streaming
- Complex data transformations
```

### Phase 3: Full Fargate Migration (Optional)
```
Migrate everything to Fargate if:
- Execution times consistently >10 min
- Team prefers Docker workflows
- Need better debugging capabilities
```

---

## Hybrid Architecture (Best of Both Worlds)

```
EventBridge (Daily)
    ├─→ Lambda: Quick fetch (9 stocks, <10 min)
    └─→ RDS Ingestion

EventBridge (Weekly)
    ├─→ Fargate: Full backfill (1000+ stocks, historical)
    └─→ RDS Ingestion

EventBridge (Monthly)
    ├─→ Fargate: Benchmark recalculation (complex, >30 min)
    └─→ RDS Update
```

**Benefits:**
- ✅ Use Lambda for routine, fast tasks (cheap)
- ✅ Use Fargate for heavy lifting (reliable)
- ✅ Optimize cost and reliability

---

## Conclusion

**For your current use case (9 stocks, hourly/daily):**
- **Stay with Lambda** for now (cheaper, simpler)
- **Keep Fargate as backup** for future growth
- **Implement Fargate** when:
  - Adding 100+ stocks
  - Execution time approaches 10 minutes
  - Need for real-time streaming
  - Team wants Docker standardization

**Both implementations are now available:**
- `/aws_deployment/` - Lambda-based (production-ready)
- `/aws_fargate/` - Fargate-based (ready to deploy when needed)

---

**Last Updated:** December 5, 2025
