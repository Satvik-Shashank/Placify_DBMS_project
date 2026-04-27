from db import get_connection

try:
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT email, password_hash FROM users")
        rows = cursor.fetchall()
        for row in rows:
            print(f"User: {row[0]} | Hash: {row[1]}")
except Exception as e:
    print(f"Error: {e}")
