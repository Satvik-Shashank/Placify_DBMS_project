-- =============================================================================
-- PLACIFY - TRIGGERS
-- File: triggers.sql
-- =============================================================================
-- SYLLABUS MAPPING: Triggers (BEFORE/AFTER, INSERT/UPDATE/DELETE)
-- DEMONSTRATES: Automatic actions, Audit logging, Data consistency
-- =============================================================================

USE campus_placement;

DELIMITER $$

-- =============================================================================
-- TRIGGER 1: trg_users_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT trigger, Data validation
-- PURPOSE: Validate email format before insertion
-- =============================================================================

DROP TRIGGER IF EXISTS trg_users_before_insert$$

CREATE TRIGGER trg_users_before_insert
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    -- Validate email (additional validation beyond CHECK constraint)
    IF NEW.email NOT LIKE '%@%.%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid email format';
    END IF;
    
    -- Convert email to lowercase for consistency
    SET NEW.email = LOWER(NEW.email);
    
    -- Ensure role is valid
    IF NEW.role NOT IN ('student', 'admin', 'company') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid role specified';
    END IF;
END$$

-- =============================================================================
-- TRIGGER 2: trg_users_after_insert (AUDIT LOG)
-- =============================================================================
-- SYLLABUS: AFTER INSERT trigger, Audit trail
-- PURPOSE: Log user creation for security audit
-- =============================================================================

DROP TRIGGER IF EXISTS trg_users_after_insert$$

CREATE TRIGGER trg_users_after_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    -- Insert audit log entry (DML - INSERT in trigger)
    INSERT INTO audit_logs (
        table_name,
        action_type,
        record_id,
        user_id,
        user_role,
        new_values,
        created_at
    ) VALUES (
        'users',
        'INSERT',
        NEW.user_id,
        NEW.user_id,
        NEW.role,
        JSON_OBJECT(
            'email', NEW.email,
            'role', NEW.role,
            'is_active', NEW.is_active
        ),
        NOW()
    );
END$$

-- =============================================================================
-- TRIGGER 3: trg_students_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, Data validation, Business rules
-- =============================================================================

DROP TRIGGER IF EXISTS trg_students_before_insert$$

CREATE TRIGGER trg_students_before_insert
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    -- Validate CGPA range
    IF NEW.cgpa < 0 OR NEW.cgpa > 10 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CGPA must be between 0 and 10';
    END IF;
    
    -- Validate backlogs
    IF NEW.backlogs < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Backlogs cannot be negative';
    END IF;
    
    -- Validate batch year (must be reasonable)
    IF NEW.batch_year < 2020 OR NEW.batch_year > 2030 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid batch year';
    END IF;
    
    -- Validate phone number format
    IF NEW.phone NOT REGEXP '^[0-9]{10}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Phone must be 10 digits';
    END IF;
    
    -- Set email to lowercase
    SET NEW.email = LOWER(NEW.email);
    
    -- Initialize placement status
    SET NEW.is_placed = FALSE;
    SET NEW.placement_type = NULL;
END$$

-- =============================================================================
-- TRIGGER 4: trg_students_after_update (PLACEMENT STATUS SYNC)
-- =============================================================================
-- SYLLABUS: AFTER UPDATE, Conditional logic, Data consistency
-- PURPOSE: Log placement status changes
-- =============================================================================

DROP TRIGGER IF EXISTS trg_students_after_update$$

CREATE TRIGGER trg_students_after_update
AFTER UPDATE ON students
FOR EACH ROW
BEGIN
    -- Log if placement status changed
    IF OLD.is_placed != NEW.is_placed OR OLD.placement_type != NEW.placement_type THEN
        INSERT INTO audit_logs (
            table_name,
            action_type,
            record_id,
            user_id,
            user_role,
            old_values,
            new_values,
            created_at
        ) VALUES (
            'students',
            'UPDATE',
            NEW.student_id,
            NEW.user_id,
            'student',
            JSON_OBJECT(
                'is_placed', OLD.is_placed,
                'placement_type', OLD.placement_type
            ),
            JSON_OBJECT(
                'is_placed', NEW.is_placed,
                'placement_type', NEW.placement_type
            ),
            NOW()
        );
    END IF;
END$$

-- =============================================================================
-- TRIGGER 5: trg_companies_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, Validation, Default values
-- =============================================================================

DROP TRIGGER IF EXISTS trg_companies_before_insert$$

CREATE TRIGGER trg_companies_before_insert
BEFORE INSERT ON companies
FOR EACH ROW
BEGIN
    -- Validate CTC
    IF NEW.ctc_lpa <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CTC must be positive';
    END IF;
    
    -- Validate deadline before visit date
    IF NEW.registration_deadline >= NEW.visit_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Registration deadline must be before visit date';
    END IF;
    
    -- Validate website format if provided
    IF NEW.website IS NOT NULL AND NEW.website NOT LIKE 'http%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Website must start with http:// or https://';
    END IF;
    
    -- Set default status
    IF NEW.status IS NULL THEN
        SET NEW.status = 'upcoming';
    END IF;
END$$

-- =============================================================================
-- TRIGGER 6: trg_applications_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, Duplicate prevention, Concurrency
-- PURPOSE: Prevent duplicate applications (defensive check)
-- =============================================================================

DROP TRIGGER IF EXISTS trg_applications_before_insert$$

CREATE TRIGGER trg_applications_before_insert
BEFORE INSERT ON applications
FOR EACH ROW
BEGIN
    DECLARE v_duplicate_count INT;
    
    -- Check for duplicate (defensive check even with UNIQUE constraint)
    SELECT COUNT(*)
    INTO v_duplicate_count
    FROM applications
    WHERE student_id = NEW.student_id
    AND company_id = NEW.company_id;
    
    IF v_duplicate_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Duplicate application detected';
    END IF;
    
    -- Set default status
    IF NEW.status IS NULL THEN
        SET NEW.status = 'applied';
    END IF;
    
    -- Set applied timestamp
    SET NEW.applied_at = NOW();
END$$

-- =============================================================================
-- TRIGGER 7: trg_applications_after_insert (AUDIT)
-- =============================================================================
-- SYLLABUS: AFTER INSERT, Logging
-- =============================================================================

DROP TRIGGER IF EXISTS trg_applications_after_insert$$

CREATE TRIGGER trg_applications_after_insert
AFTER INSERT ON applications
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (
        table_name,
        action_type,
        record_id,
        user_id,
        user_role,
        new_values,
        created_at
    ) VALUES (
        'applications',
        'INSERT',
        NEW.application_id,
        (SELECT user_id FROM students WHERE student_id = NEW.student_id),
        'student',
        JSON_OBJECT(
            'student_id', NEW.student_id,
            'company_id', NEW.company_id,
            'status', NEW.status
        ),
        NOW()
    );
END$$

-- =============================================================================
-- TRIGGER 8: trg_applications_after_update (STATUS CHANGE LOG)
-- =============================================================================
-- SYLLABUS: AFTER UPDATE, Conditional trigger
-- =============================================================================

DROP TRIGGER IF EXISTS trg_applications_after_update$$

CREATE TRIGGER trg_applications_after_update
AFTER UPDATE ON applications
FOR EACH ROW
BEGIN
    -- Log only if status changed
    IF OLD.status != NEW.status THEN
        INSERT INTO audit_logs (
            table_name,
            action_type,
            record_id,
            user_id,
            user_role,
            old_values,
            new_values,
            created_at
        ) VALUES (
            'applications',
            'UPDATE',
            NEW.application_id,
            (SELECT user_id FROM students WHERE student_id = NEW.student_id),
            'student',
            JSON_OBJECT('status', OLD.status),
            JSON_OBJECT('status', NEW.status),
            NOW()
        );
    END IF;
END$$

-- =============================================================================
-- TRIGGER 9: trg_offers_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, Validation, Business rules
-- =============================================================================

DROP TRIGGER IF EXISTS trg_offers_before_insert$$

CREATE TRIGGER trg_offers_before_insert
BEFORE INSERT ON offers
FOR EACH ROW
BEGIN
    DECLARE v_duplicate_count INT;
    
    -- Validate CTC
    IF NEW.offered_ctc <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offered CTC must be positive';
    END IF;
    
    -- Validate deadline
    IF NEW.acceptance_deadline <= NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acceptance deadline must be in the future';
    END IF;
    
    -- Validate joining date if provided
    IF NEW.joining_date IS NOT NULL AND NEW.joining_date <= CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Joining date must be in the future';
    END IF;
    
    -- Check for duplicate offer (defensive)
    SELECT COUNT(*)
    INTO v_duplicate_count
    FROM offers
    WHERE application_id = NEW.application_id;
    
    IF v_duplicate_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offer already exists for this application';
    END IF;
    
    -- Set default status
    IF NEW.status IS NULL THEN
        SET NEW.status = 'pending';
    END IF;
END$$

-- =============================================================================
-- TRIGGER 10: trg_offers_after_insert (NOTIFICATION TRIGGER)
-- =============================================================================
-- SYLLABUS: AFTER INSERT, Audit logging
-- =============================================================================

DROP TRIGGER IF EXISTS trg_offers_after_insert$$

CREATE TRIGGER trg_offers_after_insert
AFTER INSERT ON offers
FOR EACH ROW
BEGIN
    DECLARE v_student_id INT;
    DECLARE v_user_id INT;
    
    -- Get student info
    SELECT a.student_id, s.user_id
    INTO v_student_id, v_user_id
    FROM applications a
    JOIN students s ON a.student_id = s.student_id
    WHERE a.application_id = NEW.application_id;
    
    -- Log offer creation
    INSERT INTO audit_logs (
        table_name,
        action_type,
        record_id,
        user_id,
        user_role,
        new_values,
        created_at
    ) VALUES (
        'offers',
        'INSERT',
        NEW.offer_id,
        v_user_id,
        'student',
        JSON_OBJECT(
            'application_id', NEW.application_id,
            'offered_ctc', NEW.offered_ctc,
            'offered_role', NEW.offered_role,
            'status', NEW.status
        ),
        NOW()
    );
END$$

-- =============================================================================
-- TRIGGER 11: trg_offers_after_update (OFFER STATUS SYNC)
-- =============================================================================
-- SYLLABUS: AFTER UPDATE, Complex business logic, Multiple table updates
-- PURPOSE: Sync placement status when offer is accepted
-- =============================================================================

DROP TRIGGER IF EXISTS trg_offers_after_update$$

CREATE TRIGGER trg_offers_after_update
AFTER UPDATE ON offers
FOR EACH ROW
BEGIN
    DECLARE v_student_id INT;
    DECLARE v_company_id INT;
    DECLARE v_is_dream BOOLEAN;
    DECLARE v_user_id INT;
    
    -- Only process if status changed to 'accepted'
    IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
        
        -- Get application details
        SELECT a.student_id, a.company_id, s.user_id
        INTO v_student_id, v_company_id, v_user_id
        FROM applications a
        JOIN students s ON a.student_id = s.student_id
        WHERE a.application_id = NEW.application_id;
        
        -- Get company dream status
        SELECT is_dream INTO v_is_dream
        FROM companies
        WHERE company_id = v_company_id;
        
        -- Update student placement status
        -- Note: The main update is done in sp_accept_offer procedure
        -- This trigger is for logging only
        
        -- Log offer acceptance
        INSERT INTO audit_logs (
            table_name,
            action_type,
            record_id,
            user_id,
            user_role,
            old_values,
            new_values,
            created_at
        ) VALUES (
            'offers',
            'UPDATE',
            NEW.offer_id,
            v_user_id,
            'student',
            JSON_OBJECT('status', OLD.status),
            JSON_OBJECT(
                'status', NEW.status,
                'accepted_at', NEW.accepted_at
            ),
            NOW()
        );
    END IF;
END$$

-- =============================================================================
-- TRIGGER 12: trg_round_results_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, Validation
-- =============================================================================

DROP TRIGGER IF EXISTS trg_round_results_before_insert$$

CREATE TRIGGER trg_round_results_before_insert
BEFORE INSERT ON round_results
FOR EACH ROW
BEGIN
    -- Validate score range
    IF NEW.score IS NOT NULL AND (NEW.score < 0 OR NEW.score > 100) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Score must be between 0 and 100';
    END IF;
    
    -- Set default status
    IF NEW.status IS NULL THEN
        SET NEW.status = 'pending';
    END IF;
    
    -- Set attended based on status
    IF NEW.status = 'absent' THEN
        SET NEW.attended = FALSE;
    END IF;
END$$

-- =============================================================================
-- TRIGGER 13: trg_round_results_after_update
-- =============================================================================
-- SYLLABUS: AFTER UPDATE, Cascading updates
-- PURPOSE: Update application status based on round results
-- =============================================================================

DROP TRIGGER IF EXISTS trg_round_results_after_update$$

CREATE TRIGGER trg_round_results_after_update
AFTER UPDATE ON round_results
FOR EACH ROW
BEGIN
    -- If result changed from pending to rejected, update application
    IF OLD.status = 'pending' AND NEW.status = 'rejected' THEN
        UPDATE applications
        SET status = 'rejected', updated_at = NOW()
        WHERE application_id = NEW.application_id;
    END IF;
    
    -- If result changed to shortlisted, update application to in_progress
    IF OLD.status != 'shortlisted' AND NEW.status = 'shortlisted' THEN
        UPDATE applications
        SET status = 'in_progress', updated_at = NOW()
        WHERE application_id = NEW.application_id;
    END IF;
END$$

-- =============================================================================
-- TRIGGER 14: trg_eligibility_criteria_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, JSON validation
-- =============================================================================

DROP TRIGGER IF EXISTS trg_eligibility_criteria_before_insert$$

CREATE TRIGGER trg_eligibility_criteria_before_insert
BEFORE INSERT ON eligibility_criteria
FOR EACH ROW
BEGIN
    -- Validate min_cgpa
    IF NEW.min_cgpa < 0 OR NEW.min_cgpa > 10 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Minimum CGPA must be between 0 and 10';
    END IF;
    
    -- Validate max_backlogs
    IF NEW.max_backlogs < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Maximum backlogs cannot be negative';
    END IF;
    
    -- Validate allowed_departments is valid JSON array
    IF JSON_TYPE(NEW.allowed_departments) != 'ARRAY' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Allowed departments must be a JSON array';
    END IF;
    
    -- Validate dream_min_ctc if provided
    IF NEW.dream_min_ctc IS NOT NULL AND NEW.dream_min_ctc <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Dream minimum CTC must be positive';
    END IF;
END$$

-- =============================================================================
-- TRIGGER 15: trg_audit_logs_before_insert
-- =============================================================================
-- SYLLABUS: BEFORE INSERT, Timestamp automation
-- PURPOSE: Ensure audit logs have proper timestamps
-- =============================================================================

DROP TRIGGER IF EXISTS trg_audit_logs_before_insert$$

CREATE TRIGGER trg_audit_logs_before_insert
BEFORE INSERT ON audit_logs
FOR EACH ROW
BEGIN
    -- Ensure created_at is set
    IF NEW.created_at IS NULL THEN
        SET NEW.created_at = NOW();
    END IF;
END$$

DELIMITER ;

-- =============================================================================
-- TRIGGERS CREATED SUCCESSFULLY
-- =============================================================================
-- Total: 15 triggers demonstrating:
-- - BEFORE INSERT (validation, defaults)
-- - AFTER INSERT (audit logging)
-- - BEFORE UPDATE (validation)
-- - AFTER UPDATE (cascading changes, logging)
-- - Data integrity enforcement
-- - Automatic timestamping
-- - Business rule enforcement
-- - Audit trail creation
-- =============================================================================
