# db.py
import psycopg2
from config import AWS_RDS

def get_pg_conn():
    return psycopg2.connect(
        host=AWS_RDS['host'],
        port=AWS_RDS['port'],
        dbname=AWS_RDS['database'],
        user=AWS_RDS['user'],
        password=AWS_RDS['password'],
        sslmode=AWS_RDS.get('sslmode', 'require'),
    )
