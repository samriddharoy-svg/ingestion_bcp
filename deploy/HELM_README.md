# bcp-ingestion-pipeline — Helm chart

Replaces the `EventBridge → Step Functions → ECS RunTask` pattern with native
Kubernetes CronJobs running off a single `base`-stage container image.

```
deploy/helm/bcp-ingestion-pipeline/
├── Chart.yaml
├── values.yaml               # 3 CronJobs by default (hourly / daily / market-hours)
└── templates/
    ├── _helpers.tpl
    ├── serviceaccount.yaml
    ├── configmap.yaml
    ├── secret-store.yaml
    ├── external-secret.yaml
    ├── cronjob.yaml          # iterates over .Values.cronJobs
    ├── job.yaml              # iterates over .Values.jobs (one-shots, e.g. backfills)
    └── NOTES.txt
```

## Schedule mapping

The chart ships with the same three rules currently configured in EventBridge:

| EventBridge rule | Cron | State | CronJob name |
| --- | --- | --- | --- |
| `HourlyStockDataFetch` | `0 * * * *` | ENABLED | `hourly` |
| `DailyStockDataFetchAfterMarket` | `0 21 * * *` | ENABLED | `daily-after-market` |
| `MarketHoursStockDataFetch` | `*/15 14-21 * * 1-5` | DISABLED | `market-hours-15m` (suspend: true) |

Each CronJob runs `python run_fetch_all.py` against the BCP RDS Postgres,
matching today's ECS task overrides.

## Env-var routing

| Source ECS | Destination |
| --- | --- |
| 2 plain env (`PYTHONUNBUFFERED`, `USE_RDS_DIRECT`) | ConfigMap |
| 5 DB credentials (`RDS_HOST/PORT/USER/PASSWORD/DATABASE`) | ExternalSecret → `bcp-ingestion-pipeline/db-credentials` JSON |
| 2 API keys (`FMP_API_KEY`, `TIINGO_API_KEY`) | ExternalSecret → `bcp-ingestion-pipeline/api-keys` JSON |

Pod IRSA assumes a source-account secrets-reader role for cross-account secret reads — no static AWS keys.

## Adding more schedules

Append to the `cronJobs:` list in `values.yaml`. Each entry can override
`image`, `command`, `args`, `env`, `resources`, `schedule`, `suspend`, and the
backoff/timeout/concurrency knobs. Example for a backfill that fires once per
month:

```yaml
cronJobs:
  - name: monthly-fundamentals-refresh
    schedule: "0 4 1 * *"
    command: ["python", "fetch_loaders/refresh_stocks_fundamentals_mviews.py"]
    activeDeadlineSeconds: 7200
    resources:
      requests:
        cpu: 1500m
        memory: 4Gi
```

For one-shot backfill runs use the `jobs:` list (renders `Job` resources, not
`CronJob`).

## CI

`.github/workflows/bcp-ingestion-pipeline.yml` runs on push to the
`bcp-ingestion-pipeline` branch. It builds `--target base` (single image
shared across all CronJobs), pushes to source ECR, polls for ECR replication
into the target account, then `helm upgrade --install --atomic`.

Required GitHub repo Variables: `SOURCE_ACCOUNT_ID`, `SOURCE_REGION`,
`TARGET_ACCOUNT_ID`, `TARGET_REGION`, `TARGET_CLUSTER_NAME`, `ECR_REPOSITORY`,
`HELM_RELEASE_NAME`, `HELM_NAMESPACE`.
