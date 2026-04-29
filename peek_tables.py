from db import get_pg_conn

def peek():
    conn = get_pg_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_schema='ingest_db';
    """)
    print("\n📘 Available tables in ingest_db:")
    for row in cur.fetchall():
        print(" -", row[1])

    cur.execute("SELECT COUNT(*) FROM ingest_db.stocks;")
    print("\nTotal records in stocks table:", cur.fetchone()[0])

    cur.execute("SELECT * FROM ingest_db.stocks LIMIT 5;")
    print("\nSample records from stocks table:")
    for row in cur.fetchall():
        print(row)

    cur.close()
    conn.close()

if __name__ == "__main__":
    peek()
