# ─────────────────────────────────────────────────────────────
# Atlas Configuration — BCP Ingestion Pipeline (POC)
# ⚠ DO NOT COMMIT — this file is in .gitignore
# ─────────────────────────────────────────────────────────────

variable "db_pass" {
  type    = string
  default = "nVH#r0F_6lc!gfU>LJ<u?byQK?7S"
}

env "prod" {
  # ── Connection ───────────────────────────────────────────────
  url = "postgresql://infra_admin:${var.db_pass}@bernailab-dev-postgres.c9gsc4m26hgn.ap-south-1.rds.amazonaws.com:5432/app?sslmode=require"

  # ── Migration location ────────────────────────────────────────
  migration {
    dir = "file://db/atlas-migrations"
  }

  # ── Schema where Atlas stores its revision tracking table ─────
  # Atlas creates 'atlas_schema_revisions' in this schema
  revisions_schema = "ingest_db"
}

env "local" {
  url = "postgresql://infra_admin:${var.db_pass}@bernailab-dev-postgres.c9gsc4m26hgn.ap-south-1.rds.amazonaws.com:5432/app?sslmode=require"

  migration {
    dir = "file://db/atlas-migrations"
  }

  revisions_schema = "ingest_db"
}
