# =============================================================================
# PLACIFY - DATABASE CONNECTION LAYER
# File: db.py
# =============================================================================
# SYLLABUS MAPPING: Database Connectivity, Transaction Management, 
#                   Connection Pooling, Error Handling
# =============================================================================

import mysql.connector
from mysql.connector import pooling, Error
from contextlib import contextmanager
from typing import Dict, List, Any, Optional, Tuple
import logging
from config import get_config

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get configuration
config = get_config()

# =============================================================================
# CONNECTION POOL INITIALIZATION
# =============================================================================
# SYLLABUS: Connection pooling for efficient database connections
# Benefits: Reuses connections, reduces overhead, improves performance

try:
    connection_pool = pooling.MySQLConnectionPool(
        pool_name=config.MYSQL_POOL_NAME,
        pool_size=config.MYSQL_POOL_SIZE,
        pool_reset_session=True,  # Reset session variables between uses
        host=config.MYSQL_HOST,
        port=config.MYSQL_PORT,
        user=config.MYSQL_USER,
        password=config.MYSQL_PASSWORD,
        database=config.MYSQL_DATABASE,
        autocommit=False,  # Manual transaction control
        charset='utf8mb4',
        collation='utf8mb4_unicode_ci',
        # Connection timeout settings
        connect_timeout=10,
        # Raise on warnings
        raise_on_warnings=False
    )
    logger.info(f"✓ Database pool created: {config.MYSQL_DATABASE} ({config.MYSQL_POOL_SIZE} connections)")
except Error as e:
    logger.error(f"✗ Error creating connection pool: {e}")
    connection_pool = None


# =============================================================================
# CONTEXT MANAGERS FOR SAFE RESOURCE MANAGEMENT
# =============================================================================
# SYLLABUS: Context managers for automatic cleanup, RAII pattern

@contextmanager
def get_connection():
    """
    Context manager for database connections.
    Automatically returns connection to pool after use.
    
    Usage:
        with get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM students")
    
    SYLLABUS MAPPING: Connection management, Resource cleanup
    """
    connection = None
    try:
        if connection_pool is None:
            raise Error("Connection pool not initialized")
        
        connection = connection_pool.get_connection()
        yield connection
        
    except Error as e:
        logger.error(f"Database connection error: {e}")
        raise
    finally:
        if connection and connection.is_connected():
            connection.close()


@contextmanager
def get_cursor(dictionary=True, buffered=False):
    """
    Context manager for database cursors with automatic cleanup.
    
    Args:
        dictionary: If True, returns results as dictionaries (default: True)
        buffered: If True, fetches all results immediately (default: False)
    
    Usage:
        with get_cursor() as cursor:
            cursor.execute("SELECT * FROM students")
            results = cursor.fetchall()
    
    SYLLABUS MAPPING: Cursor management, Dictionary cursor for easy access
    """
    with get_connection() as connection:
        cursor = connection.cursor(dictionary=dictionary, buffered=buffered)
        try:
            yield cursor
            connection.commit()  # Auto-commit on success
        except Error as e:
            connection.rollback()  # Auto-rollback on error
            logger.error(f"Cursor error, rolled back: {e}")
            raise
        finally:
            cursor.close()


# =============================================================================
# TRANSACTION MANAGEMENT HELPERS
# =============================================================================
# SYLLABUS: TCL (Transaction Control Language) - START, COMMIT, ROLLBACK

@contextmanager
def transaction():
    """
    Explicit transaction context manager.
    Provides manual control over transactions with automatic rollback on errors.
    
    Usage:
        with transaction() as conn:
            cursor = conn.cursor()
            cursor.execute("INSERT INTO students ...")
            cursor.execute("UPDATE applications ...")
            # Auto-commits on success, rolls back on exception
    
    SYLLABUS MAPPING: TCL - START TRANSACTION, COMMIT, ROLLBACK
    """
    with get_connection() as connection:
        try:
            # Disable autocommit for explicit transaction control
            connection.autocommit = False
            
            # START TRANSACTION (implicit with autocommit=False)
            yield connection
            
            # COMMIT transaction
            connection.commit()
            logger.debug("Transaction committed successfully")
            
        except Exception as e:
            # ROLLBACK on any error
            connection.rollback()
            logger.error(f"Transaction rolled back due to error: {e}")
            raise
        finally:
            # Restore autocommit
            connection.autocommit = True


# =============================================================================
# STORED PROCEDURE EXECUTION
# =============================================================================
# SYLLABUS: Calling stored procedures, handling OUT parameters

def call_procedure(
    proc_name: str,
    args: Optional[Tuple] = None,
    fetch_results: bool = True
) -> Dict[str, Any]:
    """
    Call a stored procedure and return results.
    
    Args:
        proc_name: Name of the stored procedure
        args: Tuple of input arguments (optional)
        fetch_results: Whether to fetch result sets (default: True)
    
    Returns:
        dict: {
            'success': bool,
            'data': list or list of lists (for multiple result sets),
            'error': str (if failed)
        }
    
    Example:
        result = call_procedure('sp_apply_for_company', args=(student_id, company_id))
        if result['success']:
            application_id = result['data'][0]['application_id']
    
    SYLLABUS MAPPING: Stored procedure calls, Result set handling
    """
    result = {
        'success': False,
        'data': None,
        'error': None,
        'rowcount': 0
    }
    
    with get_connection() as connection:
        cursor = connection.cursor(dictionary=True)
        try:
            # Call the stored procedure
            cursor.callproc(proc_name, args or ())
            
            if fetch_results:
                # Fetch all result sets
                result_sets = []
                for result_set in cursor.stored_results():
                    result_sets.append(result_set.fetchall())
                
                # If only one result set, return it directly; otherwise return list
                if len(result_sets) == 1:
                    result['data'] = result_sets[0]
                elif len(result_sets) > 1:
                    result['data'] = result_sets
                else:
                    result['data'] = []
            
            connection.commit()
            result['success'] = True
            result['rowcount'] = cursor.rowcount
            
        except Error as e:
            connection.rollback()
            result['error'] = str(e)
            
            # Extract custom error message from SIGNAL SQLSTATE
            if hasattr(e, 'msg'):
                result['error'] = e.msg
            
            logger.error(f"Procedure '{proc_name}' failed: {result['error']}")
            
        finally:
            cursor.close()
    
    return result


def call_procedure_with_out_params(
    proc_name: str,
    in_args: Tuple,
    out_param_count: int
) -> Dict[str, Any]:
    """
    Call stored procedure with OUT parameters.
    
    Args:
        proc_name: Name of the stored procedure
        in_args: Tuple of input arguments
        out_param_count: Number of OUT parameters
    
    Returns:
        dict: {
            'success': bool,
            'data': list (result sets),
            'out_params': list (OUT parameter values),
            'error': str
        }
    
    Example:
        result = call_procedure_with_out_params(
            'sp_apply_for_company',
            in_args=(student_id, company_id),
            out_param_count=2
        )
        application_id = result['out_params'][0]
        message = result['out_params'][1]
    """
    result = {
        'success': False,
        'data': None,
        'out_params': [],
        'error': None
    }
    
    with get_connection() as connection:
        cursor = connection.cursor(dictionary=True)
        try:
            # Build argument list: IN args + OUT placeholders
            all_args = list(in_args) + [None] * out_param_count
            
            # Call procedure
            cursor.callproc(proc_name, all_args)
            
            # Fetch result sets
            result_sets = []
            for result_set in cursor.stored_results():
                result_sets.append(result_set.fetchall())
            result['data'] = result_sets[0] if len(result_sets) == 1 else result_sets
            
            # Fetch OUT parameters
            # MySQL stores OUT params as @_procname_arg_N
            out_params_select = ', '.join([
                f"@_{proc_name}_arg_{len(in_args) + i}"
                for i in range(out_param_count)
            ])
            
            cursor.execute(f"SELECT {out_params_select}")
            out_row = cursor.fetchone()
            
            if out_row:
                result['out_params'] = list(out_row.values())
            
            connection.commit()
            result['success'] = True
            
        except Error as e:
            connection.rollback()
            result['error'] = str(e)
            if hasattr(e, 'msg'):
                result['error'] = e.msg
            logger.error(f"Procedure '{proc_name}' with OUT params failed: {result['error']}")
        finally:
            cursor.close()
    
    return result


# =============================================================================
# QUERY EXECUTION HELPERS
# =============================================================================
# SYLLABUS: DML operations (SELECT, INSERT, UPDATE, DELETE)

def execute_query(
    query: str,
    params: Optional[Tuple] = None,
    fetch: bool = True,
    fetch_one: bool = False
) -> Dict[str, Any]:
    """
    Execute a raw SQL query (for views, simple selects, DML operations).
    
    Args:
        query: SQL query string
        params: Query parameters as tuple (for safe parameter substitution)
        fetch: If True, fetch and return results (default: True)
        fetch_one: If True, fetch only one row (default: False)
    
    Returns:
        dict: {
            'success': bool,
            'data': list of dicts or single dict (if fetch_one=True),
            'rowcount': int,
            'lastrowid': int (for INSERT operations),
            'error': str
        }
    
    Example:
        # SELECT
        result = execute_query("SELECT * FROM students WHERE department = %s", ('CSE',))
        students = result['data']
        
        # INSERT
        result = execute_query(
            "INSERT INTO students (name, email) VALUES (%s, %s)",
            ('John Doe', 'john@example.com'),
            fetch=False
        )
        new_id = result['lastrowid']
    
    SYLLABUS MAPPING: DML - SELECT, INSERT, UPDATE, DELETE
    """
    result = {
        'success': False,
        'data': None,
        'rowcount': 0,
        'lastrowid': None,
        'error': None
    }
    
    with get_cursor() as cursor:
        try:
            cursor.execute(query, params or ())
            
            result['rowcount'] = cursor.rowcount
            result['lastrowid'] = cursor.lastrowid
            
            if fetch:
                if fetch_one:
                    result['data'] = cursor.fetchone()
                else:
                    result['data'] = cursor.fetchall()
            
            result['success'] = True
            
        except Error as e:
            result['error'] = str(e)
            logger.error(f"Query execution failed: {result['error']}")
    
    return result


def execute_many(
    query: str,
    params_list: List[Tuple]
) -> Dict[str, Any]:
    """
    Execute a query multiple times with different parameters (bulk insert/update).
    
    Args:
        query: SQL query string with placeholders
        params_list: List of parameter tuples
    
    Returns:
        dict: {'success': bool, 'rowcount': int, 'error': str}
    
    Example:
        result = execute_many(
            "INSERT INTO student_skills (student_id, skill_id) VALUES (%s, %s)",
            [(1, 1), (1, 2), (1, 3)]
        )
    
    SYLLABUS MAPPING: Batch DML operations
    """
    result = {
        'success': False,
        'rowcount': 0,
        'error': None
    }
    
    with get_cursor() as cursor:
        try:
            cursor.executemany(query, params_list)
            result['rowcount'] = cursor.rowcount
            result['success'] = True
        except Error as e:
            result['error'] = str(e)
            logger.error(f"Batch execution failed: {result['error']}")
    
    return result


# =============================================================================
# CONVENIENCE FUNCTIONS FOR COMMON OPERATIONS
# =============================================================================

def get_by_id(table: str, id_column: str, id_value: Any) -> Optional[Dict]:
    """
    Get a single record by ID.
    
    Example:
        student = get_by_id('students', 'student_id', 5)
    """
    query = f"SELECT * FROM {table} WHERE {id_column} = %s"
    result = execute_query(query, (id_value,), fetch_one=True)
    return result['data'] if result['success'] else None


def get_all(table: str, where_clause: str = "", params: Tuple = ()) -> List[Dict]:
    """
    Get all records from a table with optional filtering.
    
    Example:
        cse_students = get_all('students', 'WHERE department = %s', ('CSE',))
    """
    query = f"SELECT * FROM {table} {where_clause}"
    result = execute_query(query, params)
    return result['data'] if result['success'] else []


def insert(table: str, data: Dict[str, Any]) -> Optional[int]:
    """
    Insert a record and return the new ID.
    
    Example:
        new_id = insert('students', {
            'name': 'John Doe',
            'email': 'john@example.com',
            'department': 'CSE'
        })
    """
    columns = ', '.join(data.keys())
    placeholders = ', '.join(['%s'] * len(data))
    query = f"INSERT INTO {table} ({columns}) VALUES ({placeholders})"
    
    result = execute_query(query, tuple(data.values()), fetch=False)
    return result['lastrowid'] if result['success'] else None


def update(table: str, id_column: str, id_value: Any, data: Dict[str, Any]) -> bool:
    """
    Update a record by ID.
    
    Example:
        success = update('students', 'student_id', 5, {'cgpa': 9.5})
    """
    set_clause = ', '.join([f"{k} = %s" for k in data.keys()])
    query = f"UPDATE {table} SET {set_clause} WHERE {id_column} = %s"
    
    params = tuple(data.values()) + (id_value,)
    result = execute_query(query, params, fetch=False)
    return result['success']


def delete(table: str, id_column: str, id_value: Any) -> bool:
    """
    Delete a record by ID.
    
    Example:
        success = delete('students', 'student_id', 5)
    """
    query = f"DELETE FROM {table} WHERE {id_column} = %s"
    result = execute_query(query, (id_value,), fetch=False)
    return result['success']


# =============================================================================
# CONNECTION TESTING
# =============================================================================

def test_connection() -> bool:
    """Test database connection."""
    try:
        with get_cursor() as cursor:
            cursor.execute("SELECT 1 AS test, DATABASE() AS db")
            result = cursor.fetchone()
            if result and result.get('test') == 1:
                logger.info(f"✓ Database connection successful! Connected to: {result.get('db')}")
                return True
    except Exception as e:
        logger.error(f"✗ Connection test failed: {e}")
    return False


def get_table_counts() -> Dict[str, int]:
    """Get row counts for all tables (useful for verification)."""
    tables = [
        'users', 'students', 'companies', 'eligibility_criteria',
        'applications', 'rounds', 'round_results', 'offers',
        'skills', 'student_skills', 'audit_logs', 'placement_policy'
    ]
    
    counts = {}
    for table in tables:
        result = execute_query(f"SELECT COUNT(*) as count FROM {table}", fetch_one=True)
        counts[table] = result['data']['count'] if result['success'] else 0
    
    return counts


# =============================================================================
# MODULE TEST
# =============================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("DATABASE CONNECTION TEST")
    print("=" * 60)
    
    # Test connection
    if test_connection():
        print("\n✓ Connection pool working correctly")
        
        # Show table counts
        print("\nTable Row Counts:")
        print("-" * 40)
        counts = get_table_counts()
        for table, count in counts.items():
            print(f"  {table:25} : {count:5} rows")
        
        print("\n" + "=" * 60)
        print("All tests passed! Database layer ready for use.")
        print("=" * 60)
    else:
        print("\n✗ Connection test failed!")
        print("Check your database credentials in config.py")
