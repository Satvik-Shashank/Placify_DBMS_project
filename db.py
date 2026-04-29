# =============================================================================
# PLACIFY - DATABASE CONNECTION LAYER (PostgreSQL / Supabase)
# File: db.py
# =============================================================================

import psycopg2
from psycopg2 import pool, extras, Error
from contextlib import contextmanager
from typing import Dict, List, Any, Optional, Tuple
import logging
import re
from config import get_config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

config = get_config()

# =============================================================================
# CONNECTION POOL
# =============================================================================

# Lazy pool — created on first request, not at import time
_connection_pool = None


def _is_pooler_host(host: str) -> bool:
    """
    Returns True if the host is a Supabase connection pooler endpoint.
    Pooler hosts look like: aws-0-ap-south-1.pooler.supabase.com
    Direct DB hosts look like: db.<ref>.supabase.co
    """
    return 'pooler.supabase.com' in host


def _resolve_ipv4(hostname: str) -> str:
    """
    Resolve hostname to an IPv4 address.
    Vercel serverless functions cannot make outbound IPv6 connections,
    but Supabase's direct DB hostname often resolves to IPv6.
    Forcing AF_INET ensures we always get an IPv4 address.

    NOTE: This is a workaround for the direct DB host. The recommended fix
    is to switch to the Supabase connection pooler host (*.pooler.supabase.com)
    which reliably resolves to IPv4 and also supports PgBouncer connection pooling.
    """
    import socket
    try:
        results = socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_STREAM)
        if results:
            ipv4 = results[0][4][0]
            logger.info(f"✓ Resolved {hostname} → {ipv4} (IPv4 forced)")
            return ipv4
    except Exception as e:
        logger.warning(f"IPv4 resolution failed for {hostname}: {e}, using hostname as-is")
    return hostname


def _build_pooler_username(user: str, host: str) -> str:
    """
    Supabase connection pooler requires the username to include the project ref
    as a suffix, e.g. postgres.eggysvjfsxjshkpdppua

    If the user already has a dot (already suffixed), leave it unchanged.
    If using the direct DB host, the plain 'postgres' username is correct.
    """
    if '.' in user:
        # Already in the correct pooler format
        return user

    if _is_pooler_host(host):
        # Extract project ref from pooler host: aws-0-<region>.pooler.supabase.com
        # Project ref must come from the direct DB host pattern: db.<ref>.supabase.co
        # Since we only have the pooler host here, we cannot auto-derive the ref.
        # Log a clear warning so the developer knows what to fix.
        logger.warning(
            "⚠️  You are using the Supabase pooler host but your MYSQL_USER is plain "
            f"'{user}'. The pooler requires the username to be in the format "
            f"'{user}.<project-ref>' (e.g. postgres.eggysvjfsxjshkpdppua). "
            "Set MYSQL_USER=postgres.<your-project-ref> in your .env file."
        )
    return user


def _get_pool():
    global _connection_pool
    if _connection_pool is not None:
        return _connection_pool

    try:
        host     = config.MYSQL_HOST     or 'localhost'
        port     = int(config.MYSQL_PORT or 5432)
        dbname   = config.MYSQL_DATABASE or 'postgres'
        user     = config.MYSQL_USER     or 'postgres'
        password = config.MYSQL_PASSWORD or ''
        pool_size = int(getattr(config, 'MYSQL_POOL_SIZE', 10))

        # ── Supabase pooler vs. direct DB host ──────────────────────────────
        # Direct DB host (db.*.supabase.co): resolves to IPv6 on many platforms.
        #   → Force IPv4 resolution as a workaround.
        # Pooler host (*.pooler.supabase.com): always IPv4, preferred for Flask.
        #   → Use as-is; also requires username in 'postgres.<project-ref>' format.
        if _is_pooler_host(host):
            connect_host = host          # Pooler is always IPv4-safe
        else:
            connect_host = _resolve_ipv4(host)

        # Validate / warn about username format for pooler
        user = _build_pooler_username(user, host)

        # ── Build DSN and create pool ────────────────────────────────────────
        # sslmode=require  → mandatory for Supabase (both direct and pooler)
        # connect_timeout  → fail fast rather than hanging indefinitely
        # application_name → shows up in pg_stat_activity for easier debugging
        base_dsn = (
            f"host={connect_host} port={port} dbname={dbname} "
            f"user={user} password={password} "
            f"connect_timeout=15 application_name=placify"
        )

        try:
            dsn = base_dsn + " sslmode=require"
            _connection_pool = pool.SimpleConnectionPool(
                minconn=1, maxconn=pool_size, dsn=dsn
            )
            logger.info(f"✓ Pool created (SSL): {dbname}@{connect_host}:{port} (size={pool_size})")
        except Exception as ssl_err:
            logger.warning(f"SSL connect failed ({ssl_err}), retrying without SSL…")
            _connection_pool = pool.SimpleConnectionPool(
                minconn=1, maxconn=pool_size, dsn=base_dsn
            )
            logger.info(f"✓ Pool created (no-SSL): {dbname}@{connect_host}:{port} (size={pool_size})")

    except Exception as e:
        logger.error(f"✗ Pool creation failed: {e}")
        _connection_pool = None

    return _connection_pool


def _reset_pool():
    """
    Tear down and recreate the connection pool.
    Call this after a fatal connection error to allow recovery on the next request.
    """
    global _connection_pool
    if _connection_pool is not None:
        try:
            _connection_pool.closeall()
        except Exception:
            pass
        _connection_pool = None
    logger.info("Connection pool reset — will reconnect on next request.")


# =============================================================================
# CONTEXT MANAGERS
# =============================================================================

@contextmanager
def get_connection():
    connection = None
    p = _get_pool()
    try:
        if p is None:
            raise Exception(
                "Database connection pool unavailable. "
                "Check MYSQL_HOST / MYSQL_USER / MYSQL_PASSWORD in your .env file."
            )
        connection = p.getconn()
        yield connection
    except pool.PoolError as pe:
        # Pool exhausted or broken — reset so next request gets a fresh pool
        logger.error(f"Pool error: {pe}")
        _reset_pool()
        raise
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        raise
    finally:
        if connection:
            p = _get_pool()
            if p:
                try:
                    p.putconn(connection)
                except Exception as put_err:
                    logger.warning(f"Could not return connection to pool: {put_err}")


@contextmanager
def get_cursor(dictionary=True, buffered=False):
    with get_connection() as connection:
        cursor_factory = extras.RealDictCursor if dictionary else None
        cursor = connection.cursor(cursor_factory=cursor_factory)
        try:
            yield cursor
            connection.commit()
        except Exception as e:
            try:
                connection.rollback()
            except Exception as rb_err:
                logger.error(f"Rollback failed: {rb_err}")
            logger.error(f"Cursor error, rolled back: {e}")
            raise
        finally:
            cursor.close()


@contextmanager
def transaction():
    with get_connection() as connection:
        old_autocommit = connection.autocommit
        try:
            connection.autocommit = False
            yield connection
            connection.commit()
        except Exception as e:
            try:
                connection.rollback()
            except Exception as rb_err:
                logger.error(f"Transaction rollback failed: {rb_err}")
            logger.error(f"Transaction rolled back: {e}")
            raise
        finally:
            connection.autocommit = old_autocommit


# =============================================================================
# STORED PROCEDURE CALLS (PostgreSQL functions returning TABLE)
# =============================================================================

def call_procedure(proc_name: str, args: Optional[Tuple] = None, fetch_results: bool = True) -> Dict[str, Any]:
    result = {'success': False, 'data': None, 'error': None, 'rowcount': 0}
    try:
        with get_connection() as connection:
            cursor = connection.cursor(cursor_factory=extras.RealDictCursor)
            try:
                placeholders = ', '.join(['%s'] * len(args)) if args else ''
                query = f"SELECT * FROM {proc_name}({placeholders})"
                cursor.execute(query, args or ())

                if fetch_results:
                    rows = cursor.fetchall()
                    result['data'] = [dict(row) for row in rows]

                connection.commit()
                result['success'] = True
                result['rowcount'] = cursor.rowcount
            except Exception as e:
                connection.rollback()
                result['error'] = str(e)
                logger.error(f"Procedure '{proc_name}' failed: {result['error']}")
            finally:
                cursor.close()
    except Exception as outer:
        result['error'] = str(outer)
        logger.error(f"Procedure '{proc_name}' connection error: {outer}")
    return result


def call_procedure_with_out_params(proc_name: str, in_args: Tuple, out_param_count: int) -> Dict[str, Any]:
    """
    Call a PostgreSQL function that returns TABLE(col1, col2...).
    The 'out params' are columns of the returned row.
    """
    result = {'success': False, 'data': None, 'out_params': [], 'error': None}
    try:
        with get_connection() as connection:
            cursor = connection.cursor(cursor_factory=extras.RealDictCursor)
            try:
                placeholders = ', '.join(['%s'] * len(in_args))
                query = f"SELECT * FROM {proc_name}({placeholders})"
                cursor.execute(query, in_args)

                row = cursor.fetchone()
                if row:
                    row_dict = dict(row)
                    result['out_params'] = list(row_dict.values())
                    result['data'] = [row_dict]

                remaining = cursor.fetchall()
                if remaining:
                    base = result['data'] or []
                    result['data'] = base + [dict(r) for r in remaining]

                connection.commit()
                result['success'] = True
            except Exception as e:
                connection.rollback()
                result['error'] = str(e)
                if 'RAISE' in str(e) or 'ERROR' in str(e):
                    result['error'] = str(e).split('\n')[0]
                logger.error(f"Procedure '{proc_name}' failed: {result['error']}")
            finally:
                cursor.close()
    except Exception as outer:
        result['error'] = str(outer)
        logger.error(f"Procedure '{proc_name}' connection error: {outer}")
    return result


# =============================================================================
# PRIMARY KEY MAP
# =============================================================================

_PK_MAP: Dict[str, str] = {
    'users': 'user_id',
    'students': 'student_id',
    'companies': 'company_id',
    'applications': 'application_id',
    'rounds': 'round_id',
    'round_results': 'result_id',
    'offers': 'offer_id',
    'skills': 'skill_id',
    'student_skills': 'student_skill_id',
    'audit_logs': 'log_id',
    'eligibility_criteria': 'criteria_id',
    'placement_policy': 'policy_id',
}


def _pk_for_table(table: str) -> str:
    return _PK_MAP.get(table, table.rstrip('s') + '_id')


# =============================================================================
# QUERY EXECUTION
# =============================================================================

def execute_query(
    query: str,
    params: Optional[Tuple] = None,
    fetch: bool = True,
    fetch_one: bool = False,
) -> Dict[str, Any]:
    result = {'success': False, 'data': None, 'rowcount': 0, 'lastrowid': None, 'error': None}
    try:
        with get_cursor() as cursor:
            try:
                is_insert = query.strip().upper().startswith('INSERT')

                # Auto-append RETURNING <pk> for INSERT statements that don't have it
                if is_insert and 'RETURNING' not in query.upper():
                    query = query.rstrip().rstrip(';')
                    m = re.match(r'INSERT\s+INTO\s+(\w+)', query, re.IGNORECASE)
                    if m:
                        pk = _pk_for_table(m.group(1))
                        query += f" RETURNING {pk}"

                cursor.execute(query, params or ())
                result['rowcount'] = cursor.rowcount

                if fetch or is_insert:
                    if fetch_one:
                        row = cursor.fetchone()
                        result['data'] = dict(row) if row else None
                    else:
                        rows = cursor.fetchall()
                        if rows:
                            result['data'] = [dict(r) for r in rows]
                            if is_insert:
                                result['lastrowid'] = list(dict(rows[0]).values())[0]
                        else:
                            result['data'] = [] if fetch else None

                result['success'] = True
            except Exception as e:
                result['error'] = str(e)
                logger.error(f"Query failed: {result['error']}\nQuery: {query}")
    except Exception as outer:
        result['error'] = str(outer)
        logger.error(f"execute_query connection error: {outer}")
    return result


def execute_many(query: str, params_list: List[Tuple]) -> Dict[str, Any]:
    result = {'success': False, 'rowcount': 0, 'error': None}
    try:
        with get_cursor() as cursor:
            try:
                cursor.executemany(query, params_list)
                result['rowcount'] = cursor.rowcount
                result['success'] = True
            except Exception as e:
                result['error'] = str(e)
                logger.error(f"Batch execution failed: {result['error']}")
    except Exception as outer:
        result['error'] = str(outer)
        logger.error(f"execute_many connection error: {outer}")
    return result


# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

def get_by_id(table: str, id_column: str, id_value: Any) -> Optional[Dict]:
    query = f"SELECT * FROM {table} WHERE {id_column} = %s"
    result = execute_query(query, (id_value,), fetch_one=True)
    return result['data'] if result['success'] else None


def get_all(table: str, where_clause: str = "", params: Tuple = ()) -> List[Dict]:
    query = f"SELECT * FROM {table} {where_clause}"
    result = execute_query(query, params)
    return result['data'] if result['success'] and result['data'] else []


def insert(table: str, data: Dict[str, Any]) -> Optional[int]:
    columns      = ', '.join(data.keys())
    placeholders = ', '.join(['%s'] * len(data))
    query        = f"INSERT INTO {table} ({columns}) VALUES ({placeholders})"
    result       = execute_query(query, tuple(data.values()), fetch=True)
    return result['lastrowid'] if result['success'] else None


def update(table: str, id_column: str, id_value: Any, data: Dict[str, Any]) -> bool:
    set_clause = ', '.join([f"{k} = %s" for k in data.keys()])
    query      = f"UPDATE {table} SET {set_clause} WHERE {id_column} = %s"
    params     = tuple(data.values()) + (id_value,)
    result     = execute_query(query, params, fetch=False)
    return result['success']


def delete(table: str, id_column: str, id_value: Any) -> bool:
    query  = f"DELETE FROM {table} WHERE {id_column} = %s"
    result = execute_query(query, (id_value,), fetch=False)
    return result['success']


# =============================================================================
# CONNECTION TEST
# =============================================================================

def test_connection() -> bool:
    try:
        with get_cursor() as cursor:
            cursor.execute("SELECT 1 AS test, current_database() AS db")
            row = cursor.fetchone()
            if row and dict(row).get('test') == 1:
                logger.info(f"✓ Connection OK: {dict(row).get('db')}")
                return True
    except Exception as e:
        logger.error(f"✗ Connection failed: {e}")
    return False


def get_table_counts() -> Dict[str, int]:
    tables = [
        'users', 'students', 'companies', 'eligibility_criteria',
        'applications', 'rounds', 'round_results', 'offers',
        'skills', 'student_skills', 'audit_logs', 'placement_policy',
    ]
    counts: Dict[str, int] = {}
    for table in tables:
        result = execute_query(f"SELECT COUNT(*) AS count FROM {table}", fetch_one=True)
        counts[table] = result['data']['count'] if result['success'] and result['data'] else 0
    return counts


if __name__ == '__main__':
    print("=" * 60)
    print("DATABASE CONNECTION TEST (PostgreSQL / Supabase)")
    print("=" * 60)
    if test_connection():
        print("\n✓ Connection pool working")
        print("\nTable Row Counts:")
        print("-" * 40)
        for table, count in get_table_counts().items():
            print(f"  {table:30} : {count:5} rows")
    else:
        print("\n✗ Connection failed! Check .env credentials and host format.")
        print("\nCommon fixes:")
        print("  1. MYSQL_HOST should be the pooler: aws-0-<region>.pooler.supabase.com")
        print("  2. MYSQL_PORT should be 6543 (pooler) or 5432 (direct)")
        print("  3. MYSQL_USER should be postgres.<project-ref> when using the pooler")