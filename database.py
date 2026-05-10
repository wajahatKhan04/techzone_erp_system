import psycopg2
import psycopg2.extras
import os
from dotenv import load_dotenv

load_dotenv()

def get_connection():
    host = os.getenv('DB_HOST', 'localhost')

    # Neon cloud ke liye SSL zaroori hai
    is_neon = 'neon.tech' in host

    connect_args = {
        'host':     host,
        'port':     os.getenv('DB_PORT', 5432),
        'dbname':   os.getenv('DB_NAME', 'mini_erp_db'),
        'user':     os.getenv('DB_USER', 'postgres'),
        'password': os.getenv('DB_PASSWORD', '')
    }

    if is_neon:
        connect_args['sslmode'] = 'require'

    return psycopg2.connect(**connect_args)

def execute_query(query, params=None, fetch=True):
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute(query, params)
        if fetch:
            result = cur.fetchall()
            cur.close()
            conn.close()
            return [dict(row) for row in result]
        else:
            conn.commit()
            cur.close()
            conn.close()
            return True
    except Exception as e:
        if conn:
            conn.rollback()
            conn.close()
        raise e
