-- =============================================================================
-- PLACIFY - CAMPUS PLACEMENT MANAGEMENT SYSTEM
-- Database Schema (schema.sql)
-- =============================================================================
-- SYLLABUS MAPPING: DDL, Constraints, Normalization (1NF to BCNF)
-- =============================================================================

-- Drop existing database and create fresh
DROP DATABASE IF EXISTS campus_placement;
CREATE DATABASE campus_placement 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE campus_placement;

-- =============================================================================
-- TABLE 1: users (AUTHENTICATION & AUTHORIZATION)
-- =============================================================================
-- NORMALIZATION: 3NF/BCNF - All non-key attributes depend only on user_id
-- SYLLABUS: DDL (CREATE), Constraints (PK, UNIQUE, CHECK, DEFAULT, NOT NULL)
-- =============================================================================

CREATE TABLE users (
    -- PRIMARY KEY constraint
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- UNIQUE constraint - no duplicate emails
    email VARCHAR(100) NOT NULL UNIQUE,
    
    -- NOT NULL constraint
    password_hash VARCHAR(255) NOT NULL,
    
    -- ENUM for role-based access (DCL concept preparation)
    role ENUM('student', 'admin', 'company') NOT NULL DEFAULT 'student',
    
    -- DEFAULT constraint
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    
    -- Foreign key for company role (nullable - only for company users)
    company_id INT NULL,
    
    -- CHECK constraint - email format validation
    CONSTRAINT chk_users_email_format CHECK (email LIKE '%_@_%._%'),
    
    -- INDEX for faster login queries
    INDEX idx_users_email (email),
    INDEX idx_users_role (role)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 2: students (STUDENT PROFILE)
-- =============================================================================
-- NORMALIZATION: 3NF - Separated from users to avoid NULL values for non-students
-- SYLLABUS: 1:1 relationship, Partial dependency elimination
-- =============================================================================

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- FOREIGN KEY to users (1:1 relationship)
    user_id INT NOT NULL UNIQUE,
    
    -- Natural key - UNIQUE constraint
    roll_number VARCHAR(20) NOT NULL UNIQUE,
    
    -- Personal details
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL,
    gender ENUM('male', 'female', 'other') NOT NULL,
    dob DATE NOT NULL,
    
    -- Academic details
    department ENUM('CSE', 'ECE', 'ME', 'CE', 'IT', 'EEE') NOT NULL,
    batch_year INT NOT NULL,
    cgpa DECIMAL(4,2) NOT NULL,
    backlogs INT NOT NULL DEFAULT 0,
    
    -- Placement status (denormalized for performance - explained in normalization doc)
    is_placed BOOLEAN NOT NULL DEFAULT FALSE,
    placement_type ENUM('dream', 'super_dream', 'regular') NULL,
    
    -- Resume path
    resume_path VARCHAR(255) NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CHECK constraints - business rules
    CONSTRAINT chk_students_cgpa CHECK (cgpa BETWEEN 0 AND 10),
    CONSTRAINT chk_students_backlogs CHECK (backlogs >= 0),
    CONSTRAINT chk_students_batch_year CHECK (batch_year >= 2020 AND batch_year <= 2030),
    CONSTRAINT chk_students_phone CHECK (phone REGEXP '^[0-9]{10}$'),
    
    -- FOREIGN KEY constraint with CASCADE delete
    CONSTRAINT fk_students_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- INDEXES for performance
    INDEX idx_students_department (department),
    INDEX idx_students_batch_year (batch_year),
    INDEX idx_students_cgpa (cgpa),
    INDEX idx_students_is_placed (is_placed)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 3: companies (RECRUITMENT DRIVES)
-- =============================================================================
-- NORMALIZATION: 3NF - Each company drive is independent entity
-- =============================================================================

CREATE TABLE companies (
    company_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Company details
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    website VARCHAR(255) NULL,
    industry VARCHAR(100) NULL,
    company_type ENUM('product', 'service', 'startup', 'mnc', 'psu') NOT NULL,
    
    -- Job details
    job_role VARCHAR(100) NOT NULL,
    job_description TEXT NULL,
    job_location VARCHAR(100) NULL,
    ctc_lpa DECIMAL(10,2) NOT NULL,
    
    -- Dream company flag
    is_dream BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Timeline
    visit_date DATE NOT NULL,
    registration_deadline DATETIME NOT NULL,
    
    -- Status tracking
    status ENUM('upcoming', 'ongoing', 'completed', 'cancelled') NOT NULL DEFAULT 'upcoming',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CHECK constraints
    CONSTRAINT chk_companies_ctc CHECK (ctc_lpa > 0),
    CONSTRAINT chk_companies_deadline CHECK (registration_deadline < visit_date),
    CONSTRAINT chk_companies_website CHECK (website IS NULL OR website LIKE 'http%'),
    
    -- INDEXES
    INDEX idx_companies_status (status),
    INDEX idx_companies_visit_date (visit_date),
    INDEX idx_companies_is_dream (is_dream),
    INDEX idx_companies_ctc (ctc_lpa)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 4: eligibility_criteria (1:1 WITH COMPANIES)
-- =============================================================================
-- NORMALIZATION: Separated to avoid NULLs in companies table
-- SYLLABUS: 1:1 relationship implementation
-- =============================================================================

CREATE TABLE eligibility_criteria (
    criteria_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- UNIQUE FOREIGN KEY - enforces 1:1 relationship
    company_id INT NOT NULL UNIQUE,
    
    -- Eligibility rules
    min_cgpa DECIMAL(4,2) NOT NULL DEFAULT 0,
    max_backlogs INT NOT NULL DEFAULT 0,
    allowed_departments JSON NOT NULL COMMENT 'Array: ["CSE", "ECE", "IT"]',
    min_batch_year INT NULL,
    max_batch_year INT NULL,
    
    -- Dream company override rules
    dream_min_ctc DECIMAL(10,2) NULL COMMENT 'Min CTC for dream upgrade eligibility',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CHECK constraints
    CONSTRAINT chk_eligibility_cgpa CHECK (min_cgpa BETWEEN 0 AND 10),
    CONSTRAINT chk_eligibility_backlogs CHECK (max_backlogs >= 0),
    CONSTRAINT chk_eligibility_dream_package CHECK (
        dream_min_ctc IS NULL OR dream_min_ctc > 0
    ),
    
    -- FOREIGN KEY with CASCADE
    CONSTRAINT fk_eligibility_company FOREIGN KEY (company_id) 
        REFERENCES companies(company_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 5: applications (M:N RELATIONSHIP - STUDENTS <-> COMPANIES)
-- =============================================================================
-- NORMALIZATION: Junction table resolving M:N to two 1:N relationships
-- SYLLABUS: Many-to-many relationship, Composite unique constraint
-- =============================================================================

CREATE TABLE applications (
    application_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Foreign keys creating M:N relationship
    student_id INT NOT NULL,
    company_id INT NOT NULL,
    
    -- Application status
    status ENUM('applied', 'in_progress', 'selected', 'rejected', 'withdrawn') 
        NOT NULL DEFAULT 'applied',
    
    -- Timestamps
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Notes/Remarks
    remarks TEXT NULL,
    
    -- COMPOSITE UNIQUE constraint - prevent duplicate applications
    CONSTRAINT uk_applications_student_company UNIQUE (student_id, company_id),
    
    -- FOREIGN KEYS
    CONSTRAINT fk_applications_student FOREIGN KEY (student_id) 
        REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_applications_company FOREIGN KEY (company_id) 
        REFERENCES companies(company_id) ON DELETE CASCADE,
    
    -- INDEXES for queries
    INDEX idx_applications_student (student_id),
    INDEX idx_applications_company (company_id),
    INDEX idx_applications_status (status)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 6: rounds (WEAK ENTITY - DEPENDS ON COMPANY)
-- =============================================================================
-- NORMALIZATION: Weak entity - cannot exist without company
-- SYLLABUS: Weak entity implementation, Composite key simulation
-- =============================================================================

CREATE TABLE rounds (
    round_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Foreign key to owner entity
    company_id INT NOT NULL,
    
    -- Round details
    round_number INT NOT NULL,
    round_type ENUM('aptitude', 'technical', 'coding', 'group_discussion', 'hr', 'other') 
        NOT NULL,
    round_name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    
    -- Schedule
    scheduled_date DATETIME NULL,
    venue VARCHAR(255) NULL,
    duration_minutes INT NULL,
    
    -- Status
    status ENUM('scheduled', 'ongoing', 'completed', 'cancelled') NOT NULL DEFAULT 'scheduled',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CHECK constraint
    CONSTRAINT chk_rounds_number CHECK (round_number > 0),
    
    -- UNIQUE constraint - no duplicate round numbers per company
    CONSTRAINT uk_rounds_company_number UNIQUE (company_id, round_number),
    
    -- FOREIGN KEY
    CONSTRAINT fk_rounds_company FOREIGN KEY (company_id) 
        REFERENCES companies(company_id) ON DELETE CASCADE,
    
    -- INDEXES
    INDEX idx_rounds_company (company_id),
    INDEX idx_rounds_status (status)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 7: round_results (TERNARY RELATIONSHIP - ROUND + APPLICATION)
-- =============================================================================
-- NORMALIZATION: Resolves relationship between rounds and applications
-- =============================================================================

CREATE TABLE round_results (
    result_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Links to round and application
    round_id INT NOT NULL,
    application_id INT NOT NULL,
    
    -- Result details
    status ENUM('pending', 'shortlisted', 'rejected', 'absent') NOT NULL DEFAULT 'pending',
    score DECIMAL(5,2) NULL COMMENT 'Out of 100',
    feedback TEXT NULL,
    attended BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- UNIQUE constraint - one result per round per application
    CONSTRAINT uk_round_results_round_application UNIQUE (round_id, application_id),
    
    -- CHECK constraint
    CONSTRAINT chk_round_results_score CHECK (score IS NULL OR score BETWEEN 0 AND 100),
    
    -- FOREIGN KEYS
    CONSTRAINT fk_round_results_round FOREIGN KEY (round_id) 
        REFERENCES rounds(round_id) ON DELETE CASCADE,
    CONSTRAINT fk_round_results_application FOREIGN KEY (application_id) 
        REFERENCES applications(application_id) ON DELETE CASCADE,
    
    -- INDEXES
    INDEX idx_round_results_round (round_id),
    INDEX idx_round_results_application (application_id),
    INDEX idx_round_results_status (status)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 8: offers (1:1 WITH APPLICATIONS)
-- =============================================================================
-- NORMALIZATION: Separated from applications to avoid NULLs
-- =============================================================================

CREATE TABLE offers (
    offer_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- UNIQUE FK - 1:1 relationship with applications
    application_id INT NOT NULL UNIQUE,
    
    -- Offer details
    offered_ctc DECIMAL(10,2) NOT NULL,
    offered_role VARCHAR(100) NOT NULL,
    job_location VARCHAR(100) NULL,
    joining_date DATE NULL,
    offer_letter_path VARCHAR(255) NULL,
    
    -- Status
    status ENUM('pending', 'accepted', 'declined', 'expired') NOT NULL DEFAULT 'pending',
    acceptance_deadline DATETIME NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP NULL,
    
    -- CHECK constraints
    CONSTRAINT chk_offers_ctc CHECK (offered_ctc > 0),
    CONSTRAINT chk_offers_deadline CHECK (acceptance_deadline > created_at),

    
    -- FOREIGN KEY
    CONSTRAINT fk_offers_application FOREIGN KEY (application_id) 
        REFERENCES applications(application_id) ON DELETE CASCADE,
    
    -- INDEXES
    INDEX idx_offers_status (status),
    INDEX idx_offers_deadline (acceptance_deadline)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 9: skills (MASTER DATA)
-- =============================================================================
-- NORMALIZATION: Separate table to avoid redundancy
-- =============================================================================

CREATE TABLE skills (
    skill_id INT AUTO_INCREMENT PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL UNIQUE,
    category ENUM('programming', 'framework', 'database', 'cloud', 'soft_skill', 'other') 
        NOT NULL,
    description TEXT NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- INDEXES
    INDEX idx_skills_category (category)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 10: student_skills (M:N - STUDENTS <-> SKILLS)
-- =============================================================================
-- NORMALIZATION: Junction table with proficiency attribute
-- SYLLABUS: Many-to-many with relationship attributes
-- =============================================================================

CREATE TABLE student_skills (
    student_skill_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Foreign keys
    student_id INT NOT NULL,
    skill_id INT NOT NULL,
    
    -- Relationship attribute
    proficiency ENUM('beginner', 'intermediate', 'advanced', 'expert') NOT NULL,
    years_of_experience DECIMAL(3,1) NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- UNIQUE constraint
    CONSTRAINT uk_student_skills_student_skill UNIQUE (student_id, skill_id),
    
    -- FOREIGN KEYS
    CONSTRAINT fk_student_skills_student FOREIGN KEY (student_id) 
        REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_student_skills_skill FOREIGN KEY (skill_id) 
        REFERENCES skills(skill_id) ON DELETE CASCADE,
    
    -- INDEXES
    INDEX idx_student_skills_student (student_id),
    INDEX idx_student_skills_skill (skill_id)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 11: audit_logs (SYSTEM LOGGING)
-- =============================================================================
-- SYLLABUS: Audit trail for triggers and procedures
-- =============================================================================

CREATE TABLE audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Action details
    table_name VARCHAR(50) NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id INT NOT NULL,
    
    -- User tracking
    user_id INT NULL,
    user_role VARCHAR(20) NULL,
    
    -- Change details
    old_values JSON NULL,
    new_values JSON NULL,
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- FOREIGN KEY (nullable - for system actions)
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE SET NULL,
    
    -- INDEXES
    INDEX idx_audit_logs_table (table_name),
    INDEX idx_audit_logs_user (user_id),
    INDEX idx_audit_logs_created (created_at)
) ENGINE=InnoDB;

-- =============================================================================
-- TABLE 12: placement_policy (SYSTEM CONFIGURATION)
-- =============================================================================
-- NORMALIZATION: Separates configuration from transactional data
-- =============================================================================

CREATE TABLE placement_policy (
    policy_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Policy details
    policy_name VARCHAR(100) NOT NULL UNIQUE,
    policy_type ENUM('dream_cutoff', 'max_applications', 'offer_rules', 'other') NOT NULL,
    policy_value JSON NOT NULL COMMENT 'Flexible policy configuration',
    
    -- Validity
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- CHECK constraint
    CONSTRAINT chk_policy_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    )
) ENGINE=InnoDB;

-- =============================================================================
-- ADD FOREIGN KEY TO users.company_id (DEFERRED TO AVOID CIRCULAR DEPENDENCY)
-- =============================================================================

ALTER TABLE users 
    ADD CONSTRAINT fk_users_company FOREIGN KEY (company_id) 
    REFERENCES companies(company_id) ON DELETE SET NULL;

-- =============================================================================
-- ADDITIONAL INDEXES FOR QUERY OPTIMIZATION
-- =============================================================================
-- SYLLABUS: INDEX demonstration for performance

-- Composite index for common join pattern
CREATE INDEX idx_applications_student_status ON applications(student_id, status);
CREATE INDEX idx_applications_company_status ON applications(company_id, status);

-- Full-text search indexes (if needed)
-- ALTER TABLE companies ADD FULLTEXT INDEX ft_companies_name (name, description);

-- =============================================================================
-- SCHEMA CREATION COMPLETE
-- =============================================================================
-- Total tables: 12
-- Relationships: 1:1, 1:N, M:N all demonstrated
-- Constraints: PK, FK, UNIQUE, CHECK, DEFAULT, NOT NULL all used
-- Normalization: 3NF/BCNF achieved with explanation in separate document
-- =============================================================================
