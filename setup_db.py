"""
setup_db.py – Placify DB bootstrap
Properly handles DELIMITER blocks for stored procedures, functions & triggers.

Usage:
  1. Copy .env.example to .env and fill in MYSQL_PASSWORD
  2. python setup_db.py
"""

import os
import sys
import re
import mysql.connector
from mysql.connector import Error
from werkzeug.security import generate_password_hash
from dotenv import load_dotenv

load_dotenv()

# ─── DB Connection settings (reads MYSQL_* or DB_* from .env) ─────────────────
DB = dict(
    host     = os.getenv('MYSQL_HOST')     or os.getenv('DB_HOST',     'localhost'),
    port     = int(os.getenv('MYSQL_PORT') or os.getenv('DB_PORT',     3306)),
    user     = os.getenv('MYSQL_USER')     or os.getenv('DB_USER',     'root'),
    password = os.getenv('MYSQL_PASSWORD') or os.getenv('DB_PASSWORD', ''),
    database = os.getenv('MYSQL_DATABASE') or os.getenv('DB_NAME',     'campus_placement'),
    autocommit = True,
    consume_results = True,
)

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
SQL_DIR  = os.path.join(ROOT_DIR, 'sql')

# Execution order matters — schema first, then functions (used by views/procs)
SQL_FILES = [
    'schema.sql',
    'functions.sql',
    'views.sql',
    'procedures.sql',
    'triggers.sql',
    os.path.join('sql', 'sample_data.sql'),   # always in sql/
]

# Error codes that are safe to ignore (already exists, etc.)
SAFE_ERRNO = {
    1050,  # Table already exists
    1060,  # Duplicate column
    1061,  # Duplicate key name
    1304,  # Procedure already exists
    1305,  # Function does not exist (DROP IF — safe)
    1306,  # Can't drop — used in FK
    1360,  # Trigger already exists
    1359,  # Trigger does not exist (DROP IF EXISTS — safe)
    1006,  # Can't create database
    1007,  # Database already exists
    1062,  # Duplicate entry
    1146,  # Table doesn't exist (in DROP IF EXISTS)
    1091,  # Can't drop field/key — check (IF EXISTS)
    3527,  # View already exists
}

# ─── DELIMITER-aware SQL parser ────────────────────────────────────────────────

def parse_sql_file(path: str):
    """
    Parse a SQL file and split into individual statements.
    Correctly handles DELIMITER changes used by stored procedures & triggers.
    """
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    statements = []
    delimiter  = ';'
    buffer     = []

    for line in content.splitlines():
        stripped = line.strip()

        # Skip pure comment lines
        if stripped.startswith('--') or stripped.startswith('#'):
            continue

        # Handle DELIMITER switch
        m = re.match(r'DELIMITER\s+(\S+)', stripped, re.IGNORECASE)
        if m:
            # Flush any buffered content
            accumulated = ' '.join(buffer).strip()
            if accumulated:
                statements.append(accumulated)
            buffer = []
            delimiter = m.group(1)
            continue

        buffer.append(line)

        # Check if the accumulated buffer ends with the current delimiter
        accumulated = '\n'.join(buffer).strip()
        if accumulated.endswith(delimiter):
            stmt = accumulated[: -len(delimiter)].strip()
            if stmt and not stmt.startswith('--'):
                statements.append(stmt)
            buffer = []

    # Flush remaining
    remaining = '\n'.join(buffer).strip()
    if remaining and not remaining.startswith('--'):
        # Try to split by semicolon as fallback
        for s in remaining.split(';'):
            s = s.strip()
            if s:
                statements.append(s)

    return [s for s in statements if s and len(s) > 3]


# ─── File runner ───────────────────────────────────────────────────────────────

def run_sql_file(conn, path: str):
    fname = os.path.basename(path)
    print(f"  -> {fname:<30}", end=' ', flush=True)
    stmts = parse_sql_file(path)
    ok = err = skipped = 0
    cursor = conn.cursor()
    for stmt in stmts:
        try:
            cursor.execute(stmt)
            # consume any result sets to avoid "unread result" errors
            try:
                while cursor.nextset():
                    pass
            except Exception:
                pass
            ok += 1
        except Error as e:
            if e.errno in SAFE_ERRNO:
                skipped += 1
            else:
                err += 1
                print(f"\n      [WARN] ({e.errno}) {str(e)[:120]}")
    cursor.close()
    status = f"[OK] {ok} done"
    if skipped: status += f"  {skipped} skipped"
    if err:     status += f"  [WARN] {err} errors"
    print(status)


# ─── Admin creator ─────────────────────────────────────────────────────────────

def create_admin(conn):
    print("  -> Creating admin user ...", end=' ')
    cursor = conn.cursor()
    ph = generate_password_hash('Admin@123')
    try:
        cursor.execute(
            "INSERT INTO users (email, password_hash, role) VALUES (%s, %s, 'admin')",
            ('admin@placify.edu', ph)
        )
        print("[OK] admin@placify.edu / Admin@123")
    except Error as e:
        if e.errno == 1062:
            print("(already exists - skipped)")
        else:
            print(f"Error: {e}")
    cursor.close()


def create_demo_student(conn):
    """Create a demo student account for testing."""
    print("  -> Creating demo student ...", end=' ')
    cursor = conn.cursor()
    ph = generate_password_hash('Student@123')
    try:
        cursor.execute(
            "INSERT INTO users (email, password_hash, role) VALUES (%s, %s, 'student')",
            ('student@placify.edu', ph)
        )
        uid = cursor.lastrowid
        cursor.execute(
            """INSERT INTO students
               (user_id, roll_number, name, email, phone, gender, dob,
                department, batch_year, cgpa, backlogs)
               VALUES (%s,'DEMO2025','Demo Student','student@placify.edu',
                       '9999999999','male','2004-01-01','CSE',2025,8.5,0)""",
            (uid,)
        )
        print("[OK] student@placify.edu / Student@123")
    except Error as e:
        if e.errno == 1062:
            print("(already exists - skipped)")
        else:
            print(f"Error: {e}")
    cursor.close()


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    print()
    print("==============================================")
    print("     Placify -- Database Setup Script         ")
    print("==============================================")
    print()

    # Connect
    conn_params = {**DB}
    db_name = conn_params.pop('database')
    # Connect without specifying DB first so we can CREATE DATABASE if needed
    try:
        conn = mysql.connector.connect(**conn_params)
        cur = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        cur.execute(f"USE `{db_name}`")
        cur.close()
        print(f"[OK] Connected  ->  {DB['host']}:{DB['port']}  |  DB: {db_name}\n")
    except Error as e:
        print(f"[FAIL] Cannot connect to MySQL: {e}")
        print()
        print("  Fix: Edit .env -> set MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD")
        sys.exit(1)

    # Run SQL files
    print("Running SQL files:")
    for fname in SQL_FILES:
        # Resolve path: try root first, then sql/ subdir
        candidates = [
            os.path.join(ROOT_DIR, fname),
            os.path.join(SQL_DIR, os.path.basename(fname)),
        ]
        found = next((p for p in candidates if os.path.exists(p)), None)
        if found:
            run_sql_file(conn, found)
        else:
            print(f"  -> {os.path.basename(fname):<30} [not found - skipped]")

    # Seed accounts
    print("\nCreating default accounts:")
    create_admin(conn)
    create_demo_student(conn)

    conn.close()

    print()
    print("================================================")
    print("  Setup complete!")
    print()
    print("  Start server :  python app.py")
    print("  Open browser :  http://localhost:5000")
    print()
    print("  Admin login  :  admin@placify.edu   / Admin@123")
    print("  Student login:  student@placify.edu / Student@123")
    print("================================================")
    print()


if __name__ == '__main__':
    main()
