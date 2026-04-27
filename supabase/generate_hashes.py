"""
Generate password hashes for Supabase seed data.
Run this LOCALLY, then paste the output into 05_seed.sql
"""
from werkzeug.security import generate_password_hash

passwords = {
    'admin123': 'admin@placify.com',
    'student123': 'all student accounts',
    'microsoft123': 'microsoft@placify.com',
}

print("=" * 70)
print("PASSWORD HASHES FOR SUPABASE SEED DATA")
print("=" * 70)
print()
for pwd, desc in passwords.items():
    h = generate_password_hash(pwd)
    print(f"Password: {pwd}  ({desc})")
    print(f"Hash:     {h}")
    print()
print("=" * 70)
print("Copy the hashes above into supabase/05_seed.sql")
print("Replace each REPLACE_WITH_HASH_OF_xxx placeholder")
print("=" * 70)
