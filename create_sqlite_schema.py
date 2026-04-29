#!/usr/bin/env python3
# create_sqlite_schema.py
import sqlite3
from pathlib import Path
from config import SQLITE_DB_PATH

SQL = Path(__file__).parent.joinpath("create_all_tables_sqlite.sql").read_text()

db_path = Path(SQLITE_DB_PATH)
db_path.parent.mkdir(parents=True, exist_ok=True)

def main():
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.executescript(SQL)
    conn.commit()
    cur.close()
    conn.close()
    print("SQLite schema created at:", db_path.resolve())

if __name__ == "__main__":
    main()
