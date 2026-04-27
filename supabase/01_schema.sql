-- =============================================================================
-- PLACIFY — SUPABASE/POSTGRESQL SCHEMA
-- Run this FIRST in Supabase SQL Editor
-- =============================================================================

-- Custom ENUM types (PostgreSQL uses CREATE TYPE instead of inline ENUM)
CREATE TYPE user_role AS ENUM ('student', 'admin', 'company');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE department_type AS ENUM ('CSE', 'ECE', 'ME', 'CE', 'IT', 'EEE');
CREATE TYPE company_type AS ENUM ('product', 'service', 'startup', 'mnc', 'psu');
CREATE TYPE company_status AS ENUM ('upcoming', 'ongoing', 'completed', 'cancelled');
CREATE TYPE application_status AS ENUM ('applied', 'in_progress', 'selected', 'rejected', 'withdrawn');
CREATE TYPE round_type AS ENUM ('aptitude', 'technical', 'coding', 'group_discussion', 'hr', 'other');
CREATE TYPE round_status AS ENUM ('scheduled', 'ongoing', 'completed', 'cancelled');
CREATE TYPE result_status AS ENUM ('pending', 'shortlisted', 'rejected', 'absent');
CREATE TYPE offer_status AS ENUM ('pending', 'accepted', 'declined', 'expired');
CREATE TYPE skill_category AS ENUM ('programming', 'framework', 'database', 'cloud', 'soft_skill', 'other');
CREATE TYPE proficiency_level AS ENUM ('beginner', 'intermediate', 'advanced', 'expert');
CREATE TYPE placement_type AS ENUM ('dream', 'super_dream', 'regular');
CREATE TYPE audit_action AS ENUM ('INSERT', 'UPDATE', 'DELETE');
CREATE TYPE policy_type AS ENUM ('dream_cutoff', 'max_applications', 'offer_rules', 'other');

-- TABLE 1: users
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'student',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    company_id INT NULL,
    CONSTRAINT chk_users_email_format CHECK (email LIKE '%_@_%._%')
);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- TABLE 2: students
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    roll_number VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL,
    gender gender_type NOT NULL,
    dob DATE NOT NULL,
    department department_type NOT NULL,
    batch_year INT NOT NULL,
    cgpa DECIMAL(4,2) NOT NULL,
    backlogs INT NOT NULL DEFAULT 0,
    is_placed BOOLEAN NOT NULL DEFAULT FALSE,
    placement_type placement_type NULL,
    resume_path VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_students_cgpa CHECK (cgpa BETWEEN 0 AND 10),
    CONSTRAINT chk_students_backlogs CHECK (backlogs >= 0),
    CONSTRAINT chk_students_batch_year CHECK (batch_year >= 2020 AND batch_year <= 2030),
    CONSTRAINT chk_students_phone CHECK (phone ~ '^[0-9]{10}$'),
    CONSTRAINT fk_students_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
CREATE INDEX idx_students_department ON students(department);
CREATE INDEX idx_students_batch_year ON students(batch_year);
CREATE INDEX idx_students_cgpa ON students(cgpa);
CREATE INDEX idx_students_is_placed ON students(is_placed);

-- TABLE 3: companies
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    website VARCHAR(255) NULL,
    industry VARCHAR(100) NULL,
    company_type company_type NOT NULL,
    job_role VARCHAR(100) NOT NULL,
    job_description TEXT NULL,
    job_location VARCHAR(100) NULL,
    ctc_lpa DECIMAL(10,2) NOT NULL,
    is_dream BOOLEAN NOT NULL DEFAULT FALSE,
    visit_date DATE NOT NULL,
    registration_deadline TIMESTAMP NOT NULL,
    status company_status NOT NULL DEFAULT 'upcoming',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_companies_ctc CHECK (ctc_lpa > 0),
    CONSTRAINT chk_companies_website CHECK (website IS NULL OR website LIKE 'http%')
);
CREATE INDEX idx_companies_status ON companies(status);
CREATE INDEX idx_companies_visit_date ON companies(visit_date);
CREATE INDEX idx_companies_is_dream ON companies(is_dream);
CREATE INDEX idx_companies_ctc ON companies(ctc_lpa);

-- TABLE 4: eligibility_criteria
CREATE TABLE eligibility_criteria (
    criteria_id SERIAL PRIMARY KEY,
    company_id INT NOT NULL UNIQUE,
    min_cgpa DECIMAL(4,2) NOT NULL DEFAULT 0,
    max_backlogs INT NOT NULL DEFAULT 0,
    allowed_departments JSONB NOT NULL DEFAULT '["CSE","ECE","IT","ME","CE","EEE"]',
    min_batch_year INT NULL,
    max_batch_year INT NULL,
    dream_min_ctc DECIMAL(10,2) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_eligibility_cgpa CHECK (min_cgpa BETWEEN 0 AND 10),
    CONSTRAINT chk_eligibility_backlogs CHECK (max_backlogs >= 0),
    CONSTRAINT fk_eligibility_company FOREIGN KEY (company_id) REFERENCES companies(company_id) ON DELETE CASCADE
);

-- TABLE 5: applications
CREATE TABLE applications (
    application_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL,
    company_id INT NOT NULL,
    status application_status NOT NULL DEFAULT 'applied',
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT NULL,
    CONSTRAINT uk_applications_student_company UNIQUE (student_id, company_id),
    CONSTRAINT fk_applications_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_applications_company FOREIGN KEY (company_id) REFERENCES companies(company_id) ON DELETE CASCADE
);
CREATE INDEX idx_applications_student ON applications(student_id);
CREATE INDEX idx_applications_company ON applications(company_id);
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_student_status ON applications(student_id, status);
CREATE INDEX idx_applications_company_status ON applications(company_id, status);

-- TABLE 6: rounds
CREATE TABLE rounds (
    round_id SERIAL PRIMARY KEY,
    company_id INT NOT NULL,
    round_number INT NOT NULL,
    round_type round_type NOT NULL,
    round_name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    scheduled_date TIMESTAMP NULL,
    venue VARCHAR(255) NULL,
    duration_minutes INT NULL,
    status round_status NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rounds_number CHECK (round_number > 0),
    CONSTRAINT uk_rounds_company_number UNIQUE (company_id, round_number),
    CONSTRAINT fk_rounds_company FOREIGN KEY (company_id) REFERENCES companies(company_id) ON DELETE CASCADE
);
CREATE INDEX idx_rounds_company ON rounds(company_id);
CREATE INDEX idx_rounds_status ON rounds(status);

-- TABLE 7: round_results
CREATE TABLE round_results (
    result_id SERIAL PRIMARY KEY,
    round_id INT NOT NULL,
    application_id INT NOT NULL,
    status result_status NOT NULL DEFAULT 'pending',
    score DECIMAL(5,2) NULL,
    feedback TEXT NULL,
    attended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_round_results UNIQUE (round_id, application_id),
    CONSTRAINT chk_round_results_score CHECK (score IS NULL OR score BETWEEN 0 AND 100),
    CONSTRAINT fk_round_results_round FOREIGN KEY (round_id) REFERENCES rounds(round_id) ON DELETE CASCADE,
    CONSTRAINT fk_round_results_application FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE
);
CREATE INDEX idx_round_results_round ON round_results(round_id);
CREATE INDEX idx_round_results_application ON round_results(application_id);
CREATE INDEX idx_round_results_status ON round_results(status);

-- TABLE 8: offers
CREATE TABLE offers (
    offer_id SERIAL PRIMARY KEY,
    application_id INT NOT NULL UNIQUE,
    offered_ctc DECIMAL(10,2) NOT NULL,
    offered_role VARCHAR(100) NOT NULL,
    job_location VARCHAR(100) NULL,
    joining_date DATE NULL,
    offer_letter_path VARCHAR(255) NULL,
    status offer_status NOT NULL DEFAULT 'pending',
    acceptance_deadline TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP NULL,
    CONSTRAINT chk_offers_ctc CHECK (offered_ctc > 0),
    CONSTRAINT fk_offers_application FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE
);
CREATE INDEX idx_offers_status ON offers(status);
CREATE INDEX idx_offers_deadline ON offers(acceptance_deadline);

-- TABLE 9: skills
CREATE TABLE skills (
    skill_id SERIAL PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL UNIQUE,
    category skill_category NOT NULL,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_skills_category ON skills(category);

-- TABLE 10: student_skills
CREATE TABLE student_skills (
    student_skill_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL,
    skill_id INT NOT NULL,
    proficiency proficiency_level NOT NULL,
    years_of_experience DECIMAL(3,1) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_student_skills UNIQUE (student_id, skill_id),
    CONSTRAINT fk_student_skills_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_student_skills_skill FOREIGN KEY (skill_id) REFERENCES skills(skill_id) ON DELETE CASCADE
);
CREATE INDEX idx_student_skills_student ON student_skills(student_id);
CREATE INDEX idx_student_skills_skill ON student_skills(skill_id);

-- TABLE 11: audit_logs
CREATE TABLE audit_logs (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    action_type audit_action NOT NULL,
    record_id INT NOT NULL,
    user_id INT NULL,
    user_role VARCHAR(20) NULL,
    old_values JSONB NULL,
    new_values JSONB NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);

-- TABLE 12: placement_policy
CREATE TABLE placement_policy (
    policy_id SERIAL PRIMARY KEY,
    policy_name VARCHAR(100) NOT NULL UNIQUE,
    policy_type policy_type NOT NULL,
    policy_value JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_policy_dates CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- Deferred FK: users.company_id -> companies
ALTER TABLE users ADD CONSTRAINT fk_users_company
    FOREIGN KEY (company_id) REFERENCES companies(company_id) ON DELETE SET NULL;

-- auto-update updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER trg_students_updated BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_companies_updated BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_eligibility_updated BEFORE UPDATE ON eligibility_criteria FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_applications_updated BEFORE UPDATE ON applications FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_rounds_updated BEFORE UPDATE ON rounds FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_round_results_updated BEFORE UPDATE ON round_results FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_offers_updated BEFORE UPDATE ON offers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_student_skills_updated BEFORE UPDATE ON student_skills FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_policy_updated BEFORE UPDATE ON placement_policy FOR EACH ROW EXECUTE FUNCTION update_updated_at();
