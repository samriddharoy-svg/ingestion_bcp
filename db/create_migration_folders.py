"""
Auto-creates db/migrations/<schema>/<table>/ folders
from the existing db/schema.sql file.

Usage:
    python3 db/create_migration_folders.py
"""

import re
from pathlib import Path

SCHEMA_SQL   = Path(__file__).parent / "schema.sql"
MIGRATIONS   = Path(__file__).parent / "migrations"

# Schemas to include (skip internal/backup schemas)
INCLUDE_SCHEMAS = {"ingest_db", "transform_db", "semantic_db", "indexing_state"}

# Skip backup/partition tables (contain these substrings)
SKIP_PATTERNS = ["_bkp_", "_p0", "_p1", "_p2", "_p3", "_p4",
                 "_p5", "_p6", "_p7", "_p8", "_p9"]


def parse_tables(sql_path):
    tables = []
    pattern = re.compile(r"CREATE TABLE (\w+)\.(\w+)\s*\(")
    for match in pattern.finditer(sql_path.read_text()):
        schema, table = match.group(1), match.group(2)
        tables.append((schema, table))
    return tables


def should_skip(table_name):
    return any(p in table_name for p in SKIP_PATTERNS)


def create_folders(tables):
    created, skipped = [], []
    for schema, table in tables:
        if schema not in INCLUDE_SCHEMAS:
            continue
        if should_skip(table):
            skipped.append(f"{schema}.{table}")
            continue
        folder = MIGRATIONS / schema / table
        folder.mkdir(parents=True, exist_ok=True)
        # Add a .gitkeep so empty folders are tracked by git
        gitkeep = folder / ".gitkeep"
        if not gitkeep.exists():
            gitkeep.touch()
        created.append(str(folder.relative_to(MIGRATIONS.parent.parent)))

    return created, skipped


def main():
    print(f"\nParsing: {SCHEMA_SQL}")
    tables = parse_tables(SCHEMA_SQL)
    print(f"Found {len(tables)} tables\n")

    created, skipped = create_folders(tables)

    print(f"Created {len(created)} folders:")
    for f in sorted(created):
        print(f"  + {f}")

    if skipped:
        print(f"\nSkipped {len(skipped)} backup/partition tables:")
        for s in sorted(skipped):
            print(f"  - {s}")

    print(f"\nDone. Place migration files like:")
    print(f"  db/migrations/ingest_db/company_growth_history/V004.20260530120000__add_col.sql")


if __name__ == "__main__":
    main()
