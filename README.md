# Placify – Campus Placement Management System

## Quick Start (3 steps)

### 1. Configure your database
```bash
cp .env.example .env
# Edit .env → set MYSQL_PASSWORD and MYSQL_DATABASE
```

### 2. Setup database & seed data
```bash
pip install -r requirements.txt
python setup_db.py
```

### 3. Run the server
```bash
python app.py
```
Open **http://localhost:5000**

---

## Login Credentials
| Role    | Email                  | Password   |
|---------|------------------------|------------|
| Admin   | admin@placify.edu      | Admin@123  |
| Student | (set via admin portal) | Placify@123 |

---

## Project Structure
```
BACKEND/
├── app.py                  # Flask routes (all portals)
├── db.py                   # DB connection pool + helpers
├── config.py               # Environment config
├── setup_db.py             # One-shot DB setup script
├── requirements.txt
├── .env.example
│
├── sql/                    # Database layer
│   ├── schema.sql          # Tables + constraints
│   ├── views.sql           # Analytics views
│   ├── procedures.sql      # Stored procedures (business logic)
│   ├── triggers.sql        # Auto audit logging
│   └── sample_data.sql     # Seed data
│
├── templates/              # Jinja2 HTML templates
│   ├── base.html           # Shared layout
│   ├── auth/login.html     # Login page
│   ├── components/         # Reusable nav partials
│   ├── student/            # Student portal pages
│   └── admin/              # Admin portal pages
│
├── static/
│   ├── css/main.css        # Full design system
│   └── js/main.js          # UI interactions
│
└── uploads/                # Resume uploads (auto-created)
```

---

## DBMS Concepts Demonstrated
| Concept           | Where                                          |
|-------------------|------------------------------------------------|
| Stored Procedures | `sp_apply_for_company`, `sp_accept_offer`      |
| Cursors           | `sp_get_eligible_companies`                    |
| Triggers          | Auto audit log on INSERT/UPDATE/DELETE         |
| Views             | Dashboard stats, analytics, leaderboard        |
| Transactions      | Offer acceptance with ACID compliance          |
| Connection Pool   | `db.py` — MySQLConnectionPool                  |
| Parameterized SQL | All queries use `%s` placeholders              |
| JSON column       | `eligibility_criteria.allowed_departments`     |
