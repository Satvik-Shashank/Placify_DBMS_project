<div align="center">

<img src="static/assets/logo.png" alt="Placify Logo" width="180"/>

# Placify — Campus Placement Management Portal

**A production-deployed, full-stack DBMS project demonstrating advanced SQL concepts through a real-world campus placement portal.**

[![Live Demo](https://img.shields.io/badge/Live%20Demo-Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://placify-campus-placement-management.vercel.app/login)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-3.0-000000?style=for-the-badge&logo=flask&logoColor=white)](https://flask.palletsprojects.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supabase-4479A1?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)

[🌐 Live Site](https://placify-campus-placement-management.vercel.app/login) · [✨ Features](#-features) · [🏗 Architecture](#-architecture) · [📐 DBMS Concepts](#-dbms-concepts-demonstrated) · [⚡ Quick Start](#-quick-start)

</div>

---

## 🌐 Live Deployment

> **The application is live and publicly accessible:**
>
> **[https://placify-campus-placement-management.vercel.app/login](https://placify-campus-placement-management.vercel.app/login)**

| Service | Provider | Purpose |
|---------|----------|---------|
| **Hosting** | Vercel (Serverless) | Flask app runtime (Python 3.11) |
| **Database** | Supabase (PostgreSQL) | Cloud-hosted relational database |
| **Static Assets** | Vercel CDN | CSS, JS, images |

---

## Overview

Placify is a **comprehensive campus placement management system** built as a DBMS course project. It models the entire campus recruitment lifecycle — from student registration and company drive management to multi-round interviews, offer processing, and analytics — while demonstrating **20+ advanced SQL/DBMS concepts** in a production-grade web application.

The system features **three distinct portals** (Student, Company/HR, and Admin), each with role-based access control, real-time analytics dashboards, and ACID-compliant transaction processing.

---

## ✨ Features

### 🎓 Student Portal
| Feature | Description |
|---------|-------------|
| **Dashboard** | Personalized stats — applications, selections, offers, best package |
| **Company Browser** | View eligible companies with CGPA/backlog-based filtering |
| **Application Tracker** | Real-time status updates across all applications |
| **Round Progress** | Score tracking across aptitude, coding, technical, and HR rounds |
| **Offer Management** | Accept/decline offers with ACID-compliant transaction processing |
| **Profile & Skills** | Academic profile, resume upload, and verified skill management |

### 🏢 Company / HR Portal
| Feature | Description |
|---------|-------------|
| **Recruiter Dashboard** | At-a-glance hiring funnel — applicants, shortlisted, selected, offers |
| **Drive Management** | Configure job descriptions, CTC, deadlines, and eligibility criteria |
| **Applicant Pipeline** | Filterable candidate view with profile drill-down |
| **Interview Rounds** | Schedule and manage multi-round interview processes |
| **Results & Shortlisting** | Score-based candidate progression with round-level analytics |
| **Offer Release** | Digital offer letter issuance with acceptance deadline tracking |
| **Hiring Analytics** | Funnel visualization, selection ratios, and package statistics |
| **Communications** | Automated notification system for interviews and offers |

### 🛡 Admin Portal
| Feature | Description |
|---------|-------------|
| **Global Dashboard** | Institution-wide placement statistics and KPIs |
| **Student Management** | View, edit, and manage all registered students |
| **Company Management** | Register companies, set eligibility, manage drives |
| **Analytics Suite** | Department-wise stats, batch comparison, leaderboard |
| **Audit Trail** | Trigger-based logging of all database mutations |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          PLACIFY SYSTEM                             │
├──────────────────┬───────────────────┬──────────────────────────────┤
│    FRONTEND      │    BACKEND API    │         DATABASE             │
│                  │                   │                              │
│  Jinja2          │  Flask 3.0        │  Supabase (PostgreSQL 15)    │
│  Templates       │  Python 3.11      │                              │
│                  │                   │  ┌────────────────────────┐  │
│  ┌───────────┐   │  ┌─────────────┐  │  │  Tables      (11)      │  │
│  │  Student  │◄──┤  │   app.py    │──┼─►│  Views        (8)      │  │
│  │  Portal   │   │  │ (1200+ LOC) │  │  │  Functions    (4)      │  │
│  ├───────────┤   │  ├─────────────┤  │  │  Triggers     (6)      │  │
│  │  Company  │◄──┤  │    db.py    │──┼─►│  Procedures   (5)      │  │
│  │  Portal   │   │  │ (Pool Mgmt) │  │  │  Constraints  (FK/CH)  │  │
│  ├───────────┤   │  ├─────────────┤  │  └────────────────────────┘  │
│  │   Admin   │◄──┤  │  config.py  │  │                              │
│  │  Portal   │   │  └─────────────┘  │  psycopg2 Connection Pool    │
│  └───────────┘   │                   │  Parameterized Queries       │
│                  │  Role-Based Auth  │  ACID Transactions           │
│  Chart.js        │  Session Mgmt     │  Audit Logging               │
│  Inter Font      │  CSRF Protection  │  Stored Programs             │
└──────────────────┴───────────────────┴──────────────────────────────┘

    Deployed on Vercel (Serverless)   ←→   Supabase (Cloud PostgreSQL)
```

---

## 📐 DBMS Concepts Demonstrated

> This project was designed to comprehensively cover the DBMS syllabus. Each concept is implemented in a production context, not as an isolated example.

### Core Database Design
| Concept | Implementation | File |
|---------|---------------|------|
| **ER Modeling → Relational Schema** | 11 normalized tables with proper relationships | [`supabase/01_schema.sql`](supabase/01_schema.sql) |
| **Normalization (3NF)** | Decomposed tables: `students`, `skills`, `student_skills` | [`supabase/01_schema.sql`](supabase/01_schema.sql) |
| **Foreign Keys & Referential Integrity** | `ON DELETE CASCADE`, `ON UPDATE CASCADE` constraints | [`supabase/01_schema.sql`](supabase/01_schema.sql) |
| **CHECK Constraints** | CGPA range, status enums, batch year validation | [`supabase/01_schema.sql`](supabase/01_schema.sql) |
| **UNIQUE & Composite Keys** | `(student_id, company_id)` in applications | [`supabase/01_schema.sql`](supabase/01_schema.sql) |

### Stored Programs
| Concept | Implementation | File |
|---------|---------------|------|
| **Stored Procedures** | `sp_apply_for_company`, `sp_create_offer`, `sp_accept_offer` | [`supabase/02_functions.sql`](supabase/02_functions.sql) |
| **Stored Functions** | `fn_get_student_highest_package`, `fn_get_placement_rank` | [`supabase/02_functions.sql`](supabase/02_functions.sql) |
| **Exception Handling** | `EXCEPTION WHEN` blocks for constraint violations | [`supabase/02_functions.sql`](supabase/02_functions.sql) |
| **OUT Parameters** | Functions returning status codes and messages | [`supabase/02_functions.sql`](supabase/02_functions.sql) |

### Views & Aggregation
| Concept | Implementation | File |
|---------|---------------|------|
| **Complex Views** | 8 analytics views with multi-table JOINs | [`supabase/03_views.sql`](supabase/03_views.sql) |
| **Aggregate Functions** | `COUNT`, `AVG`, `MAX`, `MIN`, `SUM` across dashboards | [`supabase/03_views.sql`](supabase/03_views.sql) |
| **GROUP BY + HAVING** | Department-wise stats with minimum thresholds | [`supabase/03_views.sql`](supabase/03_views.sql) |
| **Subqueries** | Correlated subqueries in rank functions | [`supabase/02_functions.sql`](supabase/02_functions.sql) |
| **CASE Expressions** | Dynamic status categorization in views | [`supabase/03_views.sql`](supabase/03_views.sql) |

### Triggers & Transactions
| Concept | Implementation | File |
|---------|---------------|------|
| **AFTER INSERT Triggers** | Auto audit logging on `applications`, `offers` | [`supabase/04_triggers.sql`](supabase/04_triggers.sql) |
| **AFTER UPDATE Triggers** | Track status changes with diff logging | [`supabase/04_triggers.sql`](supabase/04_triggers.sql) |
| **BEFORE INSERT Triggers** | Duplicate application prevention | [`supabase/04_triggers.sql`](supabase/04_triggers.sql) |
| **ACID Transactions** | Offer acceptance with atomic status updates | [`supabase/02_functions.sql`](supabase/02_functions.sql) |

### Advanced Patterns
| Concept | Implementation | File |
|---------|---------------|------|
| **Connection Pooling** | psycopg2 lazy pool with serverless-safe init | [`db.py`](db.py) |
| **Parameterized Queries** | All queries use `%s` placeholders (SQL injection prevention) | [`db.py`](db.py) |
| **Audit Trail** | Complete mutation history via trigger → `audit_logs` table | [`supabase/04_triggers.sql`](supabase/04_triggers.sql) |

---

## ⚡ Quick Start

### Prerequisites

- **Python** 3.11+
- **pip**
- A [Supabase](https://supabase.com) project (or local PostgreSQL)

### 1. Clone the repository

```bash
git clone https://github.com/Satvik-Shashank/Placify_Campus-placement-management-portal_FINAL.git
cd Placify_Campus-placement-management-portal_FINAL
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your Supabase credentials:

```env
MYSQL_HOST=db.<your-project-ref>.supabase.co
MYSQL_PORT=5432
MYSQL_USER=postgres
MYSQL_PASSWORD=your_supabase_db_password
MYSQL_DATABASE=postgres
SECRET_KEY=your_secret_key_here
FLASK_ENV=development
```

### 4. Set up the database

Run the SQL scripts in order in the **Supabase SQL Editor** (or any PostgreSQL client):

```
supabase/01_schema.sql      ← Tables, constraints, indexes
supabase/02_functions.sql   ← Stored functions & procedures
supabase/03_views.sql       ← Analytics views
supabase/04_triggers.sql    ← Audit triggers
supabase/05_seed.sql        ← Sample data
```

> **Note:** Before running `05_seed.sql`, generate password hashes with:
> ```bash
> python supabase/generate_hashes.py
> ```

### 5. Run the application

```bash
python app.py
```

Open **[http://localhost:5000](http://localhost:5000)** in your browser.

---

## 🔑 Demo Credentials

| Portal | Email | Password | Description |
|--------|-------|----------|-------------|
| **Admin** | `admin@placify.edu` | `Admin@123` | Full system access |
| **Company** | `microsoft@placify.com` | `microsoft123` | HR recruiter view |
| **Student** | `student@placify.com` | `student123` | Placed student with offers |

---

## 📁 Project Structure

```
Placify/
│
├── app.py                      # Flask routes — all 3 portals (1200+ lines)
├── db.py                       # PostgreSQL connection pool + query helpers
├── config.py                   # Environment configuration loader
├── requirements.txt            # Python dependencies
├── vercel.json                 # Vercel deployment config (Python 3.11 + static)
├── .env.example                # Environment template
├── LICENSE                     # MIT License
│
├── supabase/                   # PostgreSQL/Supabase SQL scripts
│   ├── 01_schema.sql           # Tables, constraints, indexes
│   ├── 02_functions.sql        # Stored functions & procedures
│   ├── 03_views.sql            # 8 analytics views
│   ├── 04_triggers.sql         # 6 audit triggers
│   ├── 05_seed.sql             # Sample data
│   └── generate_hashes.py      # Password hash generator for seeding
│
├── templates/                  # Jinja2 HTML templates
│   ├── base.html               # Shared layout (sidebar + topbar)
│   ├── auth/
│   │   └── login.html
│   ├── components/             # Reusable sidebar partials
│   ├── student/                # Student portal (6 pages)
│   ├── company/                # Company portal (9 pages)
│   └── admin/                  # Admin portal pages
│
└── static/
    ├── css/main.css            # Design system (950+ lines)
    ├── js/main.js              # UI interactions & sidebar logic
    └── assets/                 # Logo, favicon, images
```

---

## 🛠 Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Backend** | Flask 3.0, Python 3.11 | API routing, session management, template rendering |
| **Database** | PostgreSQL 15 (Supabase) | Relational data, stored programs, triggers, views |
| **ORM/Driver** | psycopg2-binary 2.9.10 | PostgreSQL adapter with connection pooling |
| **Frontend** | Jinja2, HTML5, CSS3 | Server-side templating with responsive design |
| **Styling** | Custom CSS Design System | Inter font, 950+ lines of utilities |
| **Charts** | Chart.js | Hiring funnel and analytics visualizations |
| **Auth** | Werkzeug + Flask Sessions | Password hashing (pbkdf2:sha256), role-based access |
| **Hosting** | Vercel (Serverless) | Auto-deployed from GitHub `main` branch |
| **DB Cloud** | Supabase | Managed PostgreSQL with connection pooling |

---

## 🗄 Database Schema

```
┌──────────┐     ┌──────────────┐     ┌───────────────┐
│  users   │────►│   students   │────►│ student_skills│
│          │     │              │     │               │
│ user_id  │     │ student_id   │     │ skill_id ────►│──► skills
│ email    │     │ name, cgpa   │     │ proficiency   │
│ role     │     │ department   │     └───────────────┘
└──────────┘     │ is_placed    │
                 └──────┬───────┘
                        │
                 ┌──────▼───────┐     ┌──────────────┐
                 │ applications │────►│    offers    │
                 │              │     │              │
                 │ company_id ──│──►  │ offered_ctc  │
                 │ status       │     │ status       │
                 └──────┬───────┘     └──────────────┘
                        │
                 ┌──────▼───────┐
                 │    rounds    │────► round_results
                 │ round_type   │
                 │ scheduled_at │
                 └──────────────┘

                 ┌──────────────┐     ┌──────────────────────┐
                 │  companies   │────►│ eligibility_criteria  │
                 │ name, ctc    │     │ min_cgpa, max_backlogs│
                 │ is_dream     │     │ allowed_departments   │
                 └──────────────┘     └──────────────────────┘

                 ┌──────────────┐
                 │  audit_logs  │  ◄── Populated by triggers
                 └──────────────┘
```

---

## 👤 Contributors

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/Satvik-Shashank">
        <img src="https://github.com/Satvik-Shashank.png" width="80px;" alt="Satvik"/>
        <br />
        <sub><b>Satvik Shashank</b></sub>
      </a>
    </td>
  </tr>
</table>

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with Flask · PostgreSQL · Supabase · Vercel**

[![Live Demo](https://img.shields.io/badge/Try%20It%20Live-placify--campus--placement--management.vercel.app-000000?style=for-the-badge&logo=vercel)](https://placify-campus-placement-management.vercel.app/login)

</div>
