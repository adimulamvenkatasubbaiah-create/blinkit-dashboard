"""
setup_data.py — Run setup_database.sql against Snowflake to create tables and load data.

Usage:
    python setup_data.py                          # uses default connection
    python setup_data.py --connection MY_CONN     # uses a named connection
"""

import argparse
import os
import sys
import snowflake.connector


def run_setup(connection_name: str):
    sql_path = os.path.join(os.path.dirname(__file__), "setup_database.sql")
    if not os.path.exists(sql_path):
        print(f"ERROR: {sql_path} not found.")
        sys.exit(1)

    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Split on semicolons, skip empty/comment-only blocks
    statements = [s.strip() for s in sql_content.split(";") if s.strip() and not s.strip().startswith("--")]

    print(f"Connecting to Snowflake (connection: {connection_name})...")
    conn = snowflake.connector.connect(connection_name=connection_name)

    try:
        cur = conn.cursor()
        for i, stmt in enumerate(statements, 1):
            first_line = stmt.split("\n")[0][:80]
            print(f"  [{i}/{len(statements)}] {first_line}...")
            try:
                cur.execute(stmt)
                if cur.rowcount is not None and cur.rowcount > 0:
                    rows = cur.fetchall()
                    if rows and len(rows) <= 10:
                        cols = [desc[0] for desc in cur.description]
                        print(f"           -> {cols}")
                        for row in rows:
                            print(f"              {row}")
                    else:
                        print(f"           -> {cur.rowcount} rows affected")
            except Exception as e:
                print(f"           !! ERROR: {e}")
        print("\nSetup complete.")
    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Bootstrap Blinkit DW tables in Snowflake")
    parser.add_argument("--connection", default="default", help="Snowflake connection name (default: 'default')")
    args = parser.parse_args()
    run_setup(args.connection)
